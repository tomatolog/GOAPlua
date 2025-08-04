Below are focused, minimal changes to make planning deterministic:

Goals implemented
- Iterate actions in a deterministic, sorted order.
- Choose the open node deterministically with tie-breaking by (f, g, name).
- Ensure names are always strings to make tie-break stable.

Patch

File: Goap.lua
- Add a cached, sorted action name array on path.
- Replace action iteration with a sorted loop.
- Update lowest_f_in_open to break ties by (f, g, name).
- Ensure node names are strings when created/updated.

Replace or update the indicated parts:

1) Build and store sorted action names when initializing the path:

In Goap.astar, after creating action_nodes:
```lua
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
```

2) Deterministic lowest-f selection with tie-breaking (f, g, name):

Replace lowest_f_in_open with:
```lua
local function lowest_f_in_open(olist)
    local best_key, best_node
    for sk, node in pairs(olist) do
        if not best_node then
            best_key, best_node = sk, node
        else
            if node.f < best_node.f then
                best_key, best_node = sk, node
            elseif node.f == best_node.f then
                -- tie-break by g (prefer lower g), then by name (lexicographically)
                if node.g < best_node.g then
                    best_key, best_node = sk, node
                elseif node.g == best_node.g then
                    local n1 = tostring(node.name or "")
                    local n2 = tostring(best_node.name or "")
                    if n1 < n2 then
                        best_key, best_node = sk, node
                    end
                end
            end
        end
    end
    return best_key, best_node
end
```

3) Use sorted action iteration in neighbor expansion:

Replace expand_neighbors with:
```lua
local function expand_neighbors(node, path)
    for _, action_name in ipairs(path.sorted_action_names or {}) do
        expand_action(node, action_name, path)
    end
end
```

4) Ensure node names are strings consistently (helps deterministic tie-break):

In create_node (already sets name or ""), keep as is.

In upsert_open_node, ensure name string:
```lua
    nn.name = tostring(action_name or "")
```

In astar when creating the start node, set a stable start name:
```lua
    local _start_node = create_node(_path, deepcopy(start_state), 'start')
```
(You already do this; it’s stable.)

Full snippets to paste

a) Replace lowest_f_in_open:
```lua
local function lowest_f_in_open(olist)
    local best_key, best_node
    for sk, node in pairs(olist) do
        if not best_node then
            best_key, best_node = sk, node
        else
            if node.f < best_node.f then
                best_key, best_node = sk, node
            elseif node.f == best_node.f then
                if node.g < best_node.g then
                    best_key, best_node = sk, node
                elseif node.g == best_node.g then
                    local n1 = tostring(node.name or "")
                    local n2 = tostring(best_node.name or "")
                    if n1 < n2 then
                        best_key, best_node = sk, node
                    end
                end
            end
        end
    end
    return best_key, best_node
end
```

b) Replace expand_neighbors:
```lua
local function expand_neighbors(node, path)
    for _, action_name in ipairs(path.sorted_action_names or {}) do
        expand_action(node, action_name, path)
    end
end
```

c) In Goap.astar, after you fill _path.action_nodes, insert:
```lua
    _path.sorted_action_names = {}
    for name, _ in pairs(_path.action_nodes) do
        table.insert(_path.sorted_action_names, name)
    end
    table.sort(_path.sorted_action_names, function(a,b) return a < b end)
```

d) In upsert_open_node, set a string name:
```lua
    nn.name = tostring(action_name or "")
```

Why this satisfies the spec
- Action iteration is strictly over a sorted array `_path.sorted_action_names`.
- Node selection is deterministic with tie-breaking across f, then g, then name.
- With the above, when multiple paths have equal cost/heuristic, expansion and selection order is reproducible across runs.

Testing guidance
- Add a spec where multiple actions are applicable with identical weights and effects toward the goal, and assert the returned action sequence matches the lexicographic order by action name.
- Run tests multiple times; sequences should be identical.

Here are the final files with the requested changes applied.

File: Goap.lua
--------------------------------
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

-- Deterministic lowest f selection with tie-breaking by (f, g, name)
local function lowest_f_in_open(olist)
    local best_key, best_node
    for sk, node in pairs(olist) do
        if not best_node then
            best_key, best_node = sk, node
        else
            if node.f < best_node.f then
                best_key, best_node = sk, node
            elseif node.f == best_node.f then
                if node.g < best_node.g then
                    best_key, best_node = sk, node
                elseif node.g == best_node.g then
                    local n1 = tostring(node.name or "")
                    local n2 = tostring(best_node.name or "")
                    if n1 < n2 then
                        best_key, best_node = sk, node
                    end
                end
            end
        end
    end
    return best_key, best_node
end

-- Returns true if we should skip pushing/updating this successor.
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
    local open_node = path.olist[succ_sk]
    local nn = open_node or { id = nil }

    if not nn.id then
        path.node_id = path.node_id + 1
        nn.id = path.node_id
    end

    nn.name = tostring(action_name or "")
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

    local open_node = path.olist[succ_sk]
    if not open_node or tentative_g < open_node.g then
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
function Goap.astar(start_state, goal_state, actions, reactions, weight_table, heuristic_strategy, heuristic_params)
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
        heuristic_ctx = {},
        sorted_action_names = {}
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

    local sk_start = Goap.state_key(_start_node.state)
    _path.olist[sk_start] = deepcopy(_start_node)

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
        if next(_path.olist) == nil then
            return {}
        end

        -- Extract node with lowest f from open (deterministic tie-break)
        local sk, node = lowest_f_in_open(_path.olist)
        if not sk then return {} end
        _path.olist[sk] = nil

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


File: Planner.lua
--------------------------------
local class = require('pl.class')
local deepcopy = require('pl.tablex').deepcopy
local Goap = require("Goap")

local Planner = class()
local function  update(t1,t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
end

function  Planner:_init(...)
    self.start_state = nil
    self.goal_state = nil
    self.values = {}
    for _,v in pairs({...}) do
        self.values[v] = -1
    end
    self.action_list = nil
    self.heuristic_strategy = "mismatch"
    self.heuristic_params = nil
end

function Planner:set_heuristic(strategy, params)
    self.heuristic_strategy = strategy or "mismatch"
    self.heuristic_params = params
end

function Planner:state(kwargs)
    local _new_state = deepcopy(self.values)
    update(_new_state,kwargs)
    return _new_state
end

function Planner:set_start_state(kwargs)
    for k,_ in pairs(kwargs) do
        if self.values[k] == nil then
            error("Invalid states for world start state: "..k)
        end
    end
    self.start_state = self:state(kwargs)
end

function  Planner:set_goal_state(kwargs)
    for k,_ in pairs(kwargs) do
        if self.values[k] == nil then
            error("Invalid states for world goal state: "..k)
        end
    end
    self.goal_state = self:state(kwargs)
end

function Planner:set_action_list(action_list)
    self.action_list = action_list
end

-- New: validate that each action has an explicit, positive numeric weight
local function validate_weights(action_list)
    if not action_list or not action_list.conditions then
        error("No actions provided to planner")
    end
    local weights = action_list.weights or {}
    for action_name, _ in pairs(action_list.conditions) do
        local w = weights[action_name]
        if w == nil then
            error("Missing weight for action '"..tostring(action_name).."'")
        end
        if type(w) ~= "number" or w <= 0 or w ~= w then -- includes NaN check
            error("Invalid weight for action '"..tostring(action_name).."': expected positive number, got "..tostring(w))
        end
    end
end

function Planner:calculate()
     -- Validate weights before planning
     validate_weights(self.action_list)

     return Goap.astar(
         self.start_state,
         self.goal_state,
         deepcopy(self.action_list.conditions),
         deepcopy(self.action_list.reactions),
         deepcopy(self.action_list.weights),
         self.heuristic_strategy,
         self.heuristic_params
     )
end

return Planner