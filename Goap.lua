local deepcopy = require('pl.tablex').deepcopy

local Goap = {}

-- Basic mismatch count between a state and goal mask
local function mismatch_count(state_1, state_2)
    local _score = 0
    for key, _ in pairs(state_2) do
        local _value = state_2[key]
        if _value ~= -1 then
            if state_1[key] ~= _value then
                _score = _score + 1
            end
        end
    end
    return _score
end

-- Public
function Goap.distance_to_state(state_1, state_2)
    return mismatch_count(state_1, state_2)
end

-- -1 means "don't care" in conditions
function Goap.conditions_are_met(state_1, state_2)
    for k,v in pairs(state_2) do
        if v ~= -1 then
            if state_1[k] ~= v then
                return false
            end
        end
    end
    return true
end

-- Canonical state key: sorted keys joined as key=value; booleans as 1/0
function Goap.state_key(state)
    local keys = {}
    for k in pairs(state) do table.insert(keys, k) end
    table.sort(keys, function(a,b) return a < b end)
    local parts = {}
    for _,k in ipairs(keys) do
        local v = state[k]
        local vs
        if type(v) == "boolean" then
            vs = v and "1" or "0"
        else
            vs = tostring(v)
        end
        table.insert(parts, tostring(k).."="..vs)
    end
    return table.concat(parts, ";")
end

local function create_node(path,state,name)
    path.node_id = path.node_id + 1
    local n = {state = state, f =  0, g =  0, h =  0, p_id =  nil, id =  path.node_id, name = name or ""}
    path.nodes[path.node_id] = n
    return deepcopy(n)
end

-- Heuristic strategies
local function compute_max_fixes_per_action(actions, reactions, goal_mask)
    local max_fix = 1
    for aname, _ in pairs(actions) do
        local r = reactions[aname]
        if r then
            local fixes = 0
            for k, goal_val in pairs(goal_mask) do
                if goal_val ~= -1 then
                    local rv = r[k]
                    if rv ~= nil and rv == goal_val then
                        fixes = fixes + 1
                    end
                end
            end
            if fixes > max_fix then max_fix = fixes end
        end
    end
    return max_fix
end

local function min_weight(weight_table)
    local minw = nil
    for _, w in pairs(weight_table) do
        if minw == nil or w < minw then
            minw = w
        end
    end
    return minw or 1
end

local function heuristic_value(strategy, node_state, goal_mask, ctx)
    if strategy == "zero" then
        return 0
    elseif strategy == "mismatch" or strategy == nil then
        return mismatch_count(node_state, goal_mask)
    elseif strategy == "domain_aware" then
        local mismatches = mismatch_count(node_state, goal_mask)
        if mismatches == 0 then return 0 end
        local max_fixes = ctx.max_fixes_per_action or 1
        local actions_required = math.ceil(mismatches / math.max(1, max_fixes))
        return actions_required
    else
        return 0
    end
end

local function reverse(t)
    local tmp = {}
    local len = #t
    for i=1,len do
        local key = #t
        tmp[i] = table.remove(t,key)
    end
    return tmp
end

local function successor_is_noop(current_state, reaction)
    for key, rv in pairs(reaction) do
        if current_state[key] ~= rv then
            return false
        end
    end
    return true
end

-- Build successor state by applying reaction to a copy of state
local function apply_reaction(state, reaction)
    local succ_state = deepcopy(state)
    for key, value in pairs(reaction) do
        succ_state[key] = value
    end
    return succ_state
end

-- ============================================================
-- Open list as a binary heap with decrease-key via index map.
-- Order by (f, g, name) ascending for deterministic behavior.
-- ============================================================

local function node_less(a, b)
    if a.f ~= b.f then
        return a.f < b.f
    end
    if a.g ~= b.g then
        return a.g < b.g
    end
    local n1 = tostring(a.name or "")
    local n2 = tostring(b.name or "")
    return n1 < n2
end

local OpenHeap = {}
OpenHeap.__index = OpenHeap

function OpenHeap.new()
    return setmetatable({ data = {}, pos = {} }, OpenHeap)
end

local function heap_swap(h, i, j)
    local di, dj = h.data[i], h.data[j]
    h.data[i], h.data[j] = dj, di
    if di then h.pos[di._sk] = j end
    if dj then h.pos[dj._sk] = i end
end

local function heap_up(h, i)
    while i > 1 do
        local p = math.floor(i / 2)
        if node_less(h.data[i], h.data[p]) then
            heap_swap(h, i, p)
            i = p
        else
            break
        end
    end
end

local function heap_down(h, i)
    local n = #h.data
    while true do
        local l = 2 * i
        local r = l + 1
        local smallest = i
        if l <= n and node_less(h.data[l], h.data[smallest]) then
            smallest = l
        end
        if r <= n and node_less(h.data[r], h.data[smallest]) then
            smallest = r
        end
        if smallest ~= i then
            heap_swap(h, i, smallest)
            i = smallest
        else
            break
        end
    end
end

function OpenHeap:push(node)
    local i = #self.data + 1
    self.data[i] = node
    self.pos[node._sk] = i
    heap_up(self, i)
end

function OpenHeap:pop_min()
    local n = #self.data
    if n == 0 then return nil end
    local min = self.data[1]
    local last = self.data[n]
    self.data[n] = nil
    self.pos[min._sk] = nil
    if n > 1 then
        self.data[1] = last
        self.pos[last._sk] = 1
        heap_down(self, 1)
    end
    return min
end

function OpenHeap:update(node)
    local i = self.pos[node._sk]
    if not i then return end
    heap_up(self, i)
    heap_down(self, i)
end

function OpenHeap:get(sk)
    local idx = self.pos[sk]
    if idx then return self.data[idx] end
    return nil
end

function OpenHeap:empty()
    return #self.data == 0
end

-- Skips when closed has a better or equal g for the same state.
local function should_skip_successor(succ_state_key, tentative_g, path)
    local closed_node = path.clist[succ_state_key]
    if closed_node and tentative_g >= closed_node.g then
        return true
    end
    return false
end

-- Insert or update an entry in open for succ_state. Returns the open node (new or updated).
local function upsert_open_node(action_name, succ_state, g, parent_id, path)
    local succ_sk = Goap.state_key(succ_state)
    local open_node = path.open:get(succ_sk)
    if not open_node then
        path.node_id = path.node_id + 1
        local nn = {
            id = path.node_id,
            name = tostring(action_name or ""),
            state = succ_state,
            _sk = succ_sk,
            g = g,
            h = heuristic_value(path.heuristic_strategy, succ_state, path.goal, path.heuristic_ctx),
            f = 0,
            p_id = parent_id
        }
        nn.f = nn.g + nn.h
        path.nodes[nn.id] = nn
        path.open:push(nn)
        return nn
    else
        if g < open_node.g then
            open_node.g = g
            open_node.p_id = parent_id
            open_node.h = heuristic_value(path.heuristic_strategy, open_node.state, path.goal, path.heuristic_ctx)
            open_node.f = open_node.g + open_node.h
            path.nodes[open_node.id] = open_node
            path.open:update(open_node)
        end
        return open_node
    end
end

-- Expand one action from a node; updates open/closed as needed.
local function expand_action(node, action_name, path)
    local cond_node = path.action_nodes[action_name]
    if not cond_node then return end
    if not Goap.conditions_are_met(node.state, cond_node.state) then return end

    local reaction = path.reactions[action_name]
    if not reaction then return end
    if successor_is_noop(node.state, reaction) then return end

    local succ_state = apply_reaction(node.state, reaction)
    local succ_sk = Goap.state_key(succ_state)
    local weight = path.weight_table[action_name] or 1
    local tentative_g = node.g + weight

    if should_skip_successor(succ_sk, tentative_g, path) then
        return
    end

    local existing_open = path.open:get(succ_sk)
    if not existing_open or tentative_g < existing_open.g then
        upsert_open_node(action_name, succ_state, tentative_g, node.id, path)
    end
end

-- Expand all applicable actions from node in deterministic order
local function expand_neighbors(node, path)
    for _, action_name in ipairs(path.sorted_action_names or {}) do
        expand_action(node, action_name, path)
    end
end

-- Public
-- Added optional 'options' table with fields:
-- options.max_expansions (integer), options.time_budget_ms (number)
function Goap.astar(start_state, goal_state, actions, reactions, weight_table, heuristic_strategy, heuristic_params, options)
    -- 1. Early exit if start already meets goal
    if Goap.conditions_are_met(start_state, goal_state) then
        return {}
    end

    options = options or {}
    local max_expansions = options.max_expansions
    local time_budget_ms = options.time_budget_ms
    local start_clock = time_budget_ms and os.clock() or nil
    local function time_exceeded()
        if not time_budget_ms then return false end
        local elapsed_s = os.clock() - start_clock
        return (elapsed_s * 1000.0) >= time_budget_ms
    end

    local _path = {
        nodes =  {},
        node_id =  0,
        goal = goal_state,
        actions =  actions,
        reactions =  reactions,
        weight_table =  weight_table,
        action_nodes = {},
        open = OpenHeap.new(), -- heap-based open list
        clist =  {}, -- closed: state_key -> node
        heuristic_strategy = heuristic_strategy or "mismatch",
        heuristic_ctx = {},
        sorted_action_names = {},
        expansions = 0
    }

    -- Precompute heuristic context if needed
    if _path.heuristic_strategy == "domain_aware" then
        _path.heuristic_ctx.max_fixes_per_action = compute_max_fixes_per_action(actions, reactions, goal_state)
        _path.heuristic_ctx.min_weight = min_weight(weight_table)
    end
    if heuristic_params and type(heuristic_params) == "table" then
        for k,v in pairs(heuristic_params) do
            _path.heuristic_ctx[k] = v
        end
    end

    local _start_node = create_node(_path, deepcopy(start_state), 'start')
    _start_node.g = 0
    _start_node.h = heuristic_value(_path.heuristic_strategy, _start_node.state, goal_state, _path.heuristic_ctx)
    _start_node.f = _start_node.g + _start_node.h
    _start_node._sk = Goap.state_key(_start_node.state)
    _path.open:push(_start_node)

    -- Cache action condition nodes for applicability checks
    for k,v in pairs(actions) do
        _path.action_nodes[k] = create_node(_path, deepcopy(v), k)
    end

    -- Deterministic action order: sorted action names
    _path.sorted_action_names = {}
    for name, _ in pairs(_path.action_nodes) do
        table.insert(_path.sorted_action_names, name)
    end
    table.sort(_path.sorted_action_names, function(a,b) return a < b end)

    -- Walk
    while true do
        if _path.open:empty() then
            return {}
        end

        -- Limits: time and expansions
        if time_exceeded() then
            return {}
        end
        if max_expansions and _path.expansions >= max_expansions then
            return {}
        end

        -- Extract node with lowest f from open (deterministic tie-break)
        local node = _path.open:pop_min()
        if not node then return {} end
        local sk = node._sk

        -- One expansion counted when we pop and process this node
        _path.expansions = _path.expansions + 1

        -- Goal test
        if Goap.conditions_are_met(node.state, _path.goal) then
            local ret_path = {}
            while node.p_id do
                table.insert(ret_path, node)
                node = _path.nodes[node.p_id]
            end
            return reverse(ret_path)
        end

        -- Move to closed
        _path.clist[sk] = node

        -- Expand neighbors in deterministic order
        expand_neighbors(node, _path)
    end
end

-- Export helpers if you want them for tests
Goap._helpers = {
    mismatch_count = mismatch_count
}

return Goap
