Below is a drop-in refactor of Goap.lua that removes the goto and splits neighbor expansion into clear helper functions. The behavior is unchanged from your current version (with hashing, heuristics, and no-op skipping), but the code is cleaner and easier to follow.

What changed
- Introduced helper functions:
  - apply_reaction(state, reaction)
  - should_skip_successor(node, succ_state_key, tentative_g, path)
  - upsert_open_node(action_name, succ_state, g, parent_id, path)
  - expand_action(node, action_name, path)
  - expand_neighbors(node, path)
- Rewrote walk_path to call expand_neighbors and removed goto.

Replace only the walk and expansion parts in Goap.lua with this version (I include the whole Goap.lua for convenience).

File: /Goap.lua
--------------------------------
local deepcopy = require('pl.tablex').deepcopy

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

-- Backward compatible exposed function
function distance_to_state(state_1, state_2)
    return mismatch_count(state_1, state_2)
end

-- -1 means "don't care" in conditions
function conditions_are_met(state_1, state_2)
    for k,v in pairs(state_2) do
        if v ~= -1 then
            if state_1[k] ~= v then
                return false
            end
        end
    end
    return true
end

-- Canonical state key: sorted keys joined as key=value;value true/false
function state_key(state)
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

function create_node(path,state,name)
    path["node_id"] = path["node_id"] + 1
    local n = {state = state, f =  0, g =  0, h =  0, p_id =  nil, id =  path['node_id'], name = name or ""}
    path["nodes"][ path["node_id"] ] = n
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
        -- For varied weights, you may multiply by ctx.min_weight for admissibility:
        -- return actions_required * (ctx.min_weight or 1)
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
    -- Reactions have been validated to not contain -1
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

local function lowest_f_in_open(olist)
    local best_key, best_node, best_f = nil, nil, math.huge
    for sk, node in pairs(olist) do
        if node.f < best_f then
            best_f = node.f
            best_key = sk
            best_node = node
        end
    end
    return best_key, best_node
end

-- Returns true if we should skip pushing/updating this successor.
-- Skips when closed has a better or equal g for the same state.
local function should_skip_successor(node, succ_state_key, tentative_g, path)
    local closed_node = path.clist[succ_state_key]
    if closed_node and tentative_g >= closed_node.g then
        return true
    end
    return false
end

-- Insert or update an entry in open for succ_state. Returns the open node (new or updated).
local function upsert_open_node(action_name, succ_state, g, parent_id, path)
    local succ_sk = state_key(succ_state)
    local open_node = path.olist[succ_sk]
    local nn = open_node or { id = nil }

    if not nn.id then
        path.node_id = path.node_id + 1
        nn.id = path.node_id
    end

    nn.name = action_name
    nn.state = succ_state
    nn.g = g
    nn.h = heuristic_value(path.heuristic_strategy, succ_state, path.goal, path.heuristic_ctx)
    nn.f = nn.g + nn.h
    nn.p_id = parent_id

    path.nodes[nn.id] = nn
    path.olist[succ_sk] = nn

    return nn
end

-- Expand one action from a node; updates open/closed as needed.
local function expand_action(node, action_name, path)
    local cond_node = path.action_nodes[action_name]
    if not cond_node then return end
    if not conditions_are_met(node.state, cond_node.state) then return end

    local reaction = path.reactions[action_name]
    if not reaction then return end

    if successor_is_noop(node.state, reaction) then return end

    local succ_state = apply_reaction(node.state, reaction)
    local succ_sk = state_key(succ_state)
    local weight = path.weight_table[action_name] or 1
    local tentative_g = node.g + weight

    if should_skip_successor(node, succ_sk, tentative_g, path) then
        return
    end

    local open_node = path.olist[succ_sk]
    if not open_node or tentative_g < open_node.g then
        upsert_open_node(action_name, succ_state, tentative_g, node.id, path)
    end
end

-- Expand all applicable actions from node
local function expand_neighbors(node, path)
    for action_name, _ in pairs(path.action_nodes) do
        expand_action(node, action_name, path)
    end
end

-- A* using state-keyed open/closed maps
function astar(start_state, goal_state, actions, reactions, weight_table, heuristic_strategy, heuristic_params)
    local _path = {
        nodes =  {},
        node_id =  0,
        goal = goal_state,
        actions =  actions,
        reactions =  reactions,
        weight_table =  weight_table,
        action_nodes = {},
        olist =  {}, -- open: state_key -> node
        clist =  {}, -- closed: state_key -> node
        heuristic_strategy = heuristic_strategy or "mismatch",
        heuristic_ctx = {}
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
    _start_node['g'] = 0
    _start_node['h'] = heuristic_value(_path.heuristic_strategy, _start_node.state, goal_state, _path.heuristic_ctx)
    _start_node['f'] = _start_node['g'] + _start_node['h']

    local sk_start = state_key(_start_node.state)
    _path.olist[sk_start] = deepcopy(_start_node)

    -- Cache action condition nodes for applicability checks
    for k,v in pairs(actions) do
        _path['action_nodes'][k] = create_node(_path, deepcopy(v), k)
    end

    return walk_path(_path)
end

function walk_path(path)
    while true do
        if next(path.olist) == nil then
            return {}
        end

        -- Extract node with lowest f from open
        local sk, node = lowest_f_in_open(path.olist)
        if not sk then return {} end
        path.olist[sk] = nil

        -- Goal test
        if conditions_are_met(node.state, path.goal) then
            local _path = {}
            while node.p_id do
                table.insert(_path, node)
                node = path.nodes[node.p_id]
            end
            return reverse(_path)
        end

        -- Move to closed
        path.clist[sk] = node

        -- Expand neighbors without goto
        expand_neighbors(node, path)
    end
end

Notes
- The logic for skipping/reopening is now encapsulated in should_skip_successor and upsert_open_node.
- expand_action cleanly handles applicability, no-op detection, tentative_g computation, and open/closed decisions.
- No gotos are used.