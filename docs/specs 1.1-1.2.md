Below is a minimal, self-contained set of changes to implement the two requested improvements:

1) Heuristic admissibility/consistency with a configuration flag.
2) Skipping no-op actions during neighbor generation.

Notes:
- I kept the existing API and behavior as default: the heuristic remains the existing “mismatch count” unless you choose one of the new strategies.
- Added a `heuristic_strategy` and optional `heuristic_params` to `Planner`, passed through to `astar`.
- Implemented three strategies:
  - "zero": always 0 (Dijkstra) — admissible and consistent.
  - "mismatch": current behavior — number of mismatched keys in goal (kept for backward compatibility; can be inadmissible in some domains).
  - "domain_aware": mismatches divided by a computed upper bound on how many mismatches a single action can fix, then ceiling. This is admissible if action costs are uniform; with varied weights, combine with "zero" to guarantee optimality. For varied weights, you can also use mismatch divided by max fixes as a lower bound on action count, then multiply by min action weight; see the note in code comments for an optional tweak.

- Added no-op filtering during neighbor generation.

Files to update:

File: /Goap.lua
- Add heuristic choice.
- Add domain-aware estimator helpers.
- Skip no-op successors.

Replace the content of Goap.lua with the following:

```lua
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

-- Backward compatible exposed function name kept (used elsewhere)
function distance_to_state(state_1, state_2)
    return mismatch_count(state_1, state_2)
end

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

local function compareTable(t1, t2)
    for k, v in pairs(t1) do
        if t2[k] ~= v then
            return false
        end
    end
    for k, v in pairs(t2) do
        if t1[k] ~= v then
            return false
        end
    end
    return true
end

function node_in_list(node,node_list)
    for _,v in pairs(node_list) do
        if node["name"] == v["name"] and compareTable(node["state"],v["state"]) then
            return true
        end
    end
    return false
end

function create_node(path,state,name)
    path["node_id"] = path["node_id"] + 1
    path["nodes"][ path["node_id"] ] = {state = state, f =  0, g =  0, h =  0, p_id =  nil, id =  path['node_id'], name = name or ""}
    return deepcopy(path["nodes"][ path["node_id"] ])
end

-- Heuristic strategies
local function compute_max_fixes_per_action(actions, reactions, goal_mask)
    -- Count, for each action, how many goal-relevant keys it sets to their goal values
    -- Returns max over actions
    local max_fix = 1
    for aname, _ in pairs(actions) do
        local r = reactions[aname]
        if r then
            local fixes = 0
            for k, goal_val in pairs(goal_mask) do
                if goal_val ~= -1 then
                    local rv = r[k]
                    if rv ~= nil and rv ~= -1 and rv == goal_val then
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
        -- Pure action-count heuristic (admissible with uniform weights)
        -- Optionally, to be conservative with varied weights, multiply by min action weight:
        -- return actions_required * (ctx.min_weight or 1)
        return actions_required
    else
        -- Fallback to safe
        return 0
    end
end

function astar(start_state, goal_state, actions, reactions, weight_table, heuristic_strategy, heuristic_params)
    local _path = {
        nodes =  {},
        node_id =  0,
        goal = goal_state,
        actions =  actions,
        reactions =  reactions,
        weight_table =  weight_table,
        action_nodes = {},
        olist =  {},
        clist =  {},
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

    local _start_node = create_node(_path, start_state,'start')
    _start_node['g'] = 0
    _start_node['h'] = heuristic_value(_path.heuristic_strategy, start_state, goal_state, _path.heuristic_ctx)
    _start_node['f'] = _start_node['g'] + _start_node['h']

    _path['olist'][ _start_node['id'] ] = deepcopy(_start_node)
    for k,v in pairs(actions) do
        _path['action_nodes'][k] = create_node(_path, deepcopy(v), k)
    end

    return walk_path(_path)
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
    -- Returns true if applying reaction does not modify any key
    for key, rv in pairs(reaction) do
        if rv ~= -1 then
            if current_state[key] ~= rv then
                return false -- at least one change
            end
        end
    end
    -- Also check keys present in state but not in reaction: they remain unchanged, which is fine.
    -- If we reach here, no key changed.
    return true
end

function walk_path(path)
    local node = nil
    local _clist = path["clist"]
    local _olist = path["olist"]

    while next(_olist) ~= nil do
        -- Find lowest f node
        local _lowest = {node = nil ,f = 9000000}
        for _,next_node in pairs(_olist) do
            if not _lowest["node"]  or next_node["f"] < _lowest["f"] then
               _lowest["node"] = next_node["id"]
               _lowest["f"] = next_node["f"]
            end
        end
        if _lowest["node"] then
            node = path["nodes"][_lowest["node"] ]
        else
            return
        end
        -- Remove from open
        _olist[ node["id"] ] = nil

        -- Goal test
        if conditions_are_met(node['state'], path['goal']) then
            local _path = {}
            while node['p_id'] do
                table.insert(_path,node)
                node = path['nodes'][node['p_id']]
            end
            return reverse(_path)
        end

        -- Add to closed
        _clist[ node['id'] ] = node

        -- Generate neighbors
        local _neighbors = {}
        for action_name,_ in pairs(path['action_nodes']) do
            if conditions_are_met(node['state'], path['action_nodes'][action_name]['state']) then
                -- Skip no-op reactions
                local reaction = path['reactions'][action_name]
                if reaction and not successor_is_noop(node['state'], reaction) then
                    path['node_id']  =  path["node_id" ] + 1
                    local _c_node = deepcopy(node)
                    _c_node["id"] = path["node_id"]
                    _c_node["name"] = action_name

                    -- Apply reaction
                    for key,_ in pairs(reaction) do
                        local _value = reaction[key]
                        if _value ~=  -1 then
                            _c_node['state'][key] = _value
                        end
                    end

                    path["nodes"][_c_node["id"] ] = _c_node
                    table.insert(_neighbors,_c_node)
                end
            end
        end

        for _,next_node in pairs(_neighbors) do
            local weight = path['weight_table'][next_node['name']] or 1
            local _g_cost = node['g'] + weight
            local  _in_olist, _in_clist = node_in_list(next_node, _olist), node_in_list(next_node, _clist)
            if _in_olist and _g_cost < next_node["g"] then
                _olist[next_node["id"]] = nil
            end

            if _in_clist and _g_cost < next_node["g"] then
                _clist[next_node["id"]] = nil
            end

            if (not node_in_list(next_node, _olist)) and (not node_in_list(next_node, _clist)) then
                next_node['g'] = _g_cost
                next_node['h'] = heuristic_value(path.heuristic_strategy, next_node['state'], path['goal'], path.heuristic_ctx)
                next_node['f'] = next_node['g'] + next_node['h']
                next_node['p_id'] = node['id']

                _olist[next_node['id']] = next_node
            end
        end
    end -- while
    return {}
end
```

File: /Planner.lua
- Add heuristic configuration and pass to `astar`.

Replace the `Planner` class definition with this updated version (only diffs shown; rest unchanged):

```lua
local class = require('pl.class')
local deepcopy = require('pl.tablex').deepcopy
require("Goap")

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
    -- New: heuristic config
    self.heuristic_strategy = "mismatch"  -- options: "zero", "mismatch", "domain_aware"
    self.heuristic_params = nil           -- optional table for strategy-specific params
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

function Planner:calculate()
     return astar(
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
```

How to use:

- Default behavior remains unchanged: mismatch-count heuristic.
- To guarantee optimality with varied weights, set the heuristic to zero:
  - In `example_goap.lua`, after creating the planner:
    `world:set_heuristic("zero")` if you were using `Planner` directly. In your current example you name the planner `world`, but it’s actually a `Planner` instance.
- To use the domain-aware heuristic:
  - `planner:set_heuristic("domain_aware")`
  - This is admissible if action costs are uniform. If you have varied weights and still want admissibility, change the line in `heuristic_value` to multiply by `ctx.min_weight` (commented in code).

No-op acceptance criteria:

- Neighbor generation now calls `successor_is_noop` and skips creating successors that would not change any key. This ensures no-ops aren’t expanded and reduces loops/branching.

Optional unit-test ideas (not code, just brief):

- Add an action whose reaction is `{}` or sets all keys to current values; assert it never appears in the returned plan.
- Create a scenario where an action fixes two goal keys at once. With "mismatch", the heuristic might overestimate; with "zero" or "domain_aware", ensure optimal plan is returned.
- With varied weights, enable "zero" and confirm cheapest-cost plan is chosen.