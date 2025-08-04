Great—let’s implement the two new items:

1) Deduplicate by state with hashing (open/closed maps keyed by a canonical state key).
2) Clarify reaction semantics and disallow ambiguous `-1` in reactions (validation).

Summary of changes:
- Add `state_key(state)` that builds a stable key by sorting keys and concatenating key=value pairs.
- Replace list-based open/closed membership with maps keyed by `state_key`.
- Maintain per-state best g, f, parent info to allow re-open/update when a better path is found.
- Validate reactions at insertion time: `-1` is disallowed in reactions and will raise an error; `-1` remains allowed in conditions as “don’t care”.
- Keep the existing API; only `Action:add_reaction` gains validation.
- Keep previous heuristic options intact.

Updated files below.

File: /Action.lua
--------------------------------
Add reaction validation to reject `-1` and non-boolean values (if your domain is boolean). If you allow non-boolean domains, adjust validation accordingly.

```lua
local class = require('pl.class')
local Action = class()
function Action:_init()
    self.conditions = {}
    self.reactions = {}
    self.weights = {}
end
local function  update(t1,t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
end

function Action:add_condition(key, conditions)
    if not self.weights[key] then
        self.weights[key] = 1
    end

    if not self.conditions[key] then
        self.conditions[key] = conditions
        return
    end
    update(self.conditions[key],conditions)
end

local function validate_reaction_table(key, reaction)
    -- Reactions: disallow -1 (ambiguous); interpret only concrete assignments.
    for k, v in pairs(reaction) do
        if v == -1 then
            error("Invalid reaction value -1 for action '"..tostring(key).."' at key '"..tostring(k).."'. Reactions must specify concrete values (no -1).")
        end
        -- Optional: enforce boolean values; comment out if your domain is not strictly boolean.
        if type(v) ~= "boolean" then
            error("Invalid reaction value type for action '"..tostring(key).."', key '"..tostring(k).."': expected boolean, got "..type(v))
        end
    end
end

function Action:add_reaction(key, reaction)
    if not self.conditions[key] then
        error("Trying to add reaction '"..key.."' without matching condition.")
    end
    validate_reaction_table(key, reaction)
    if not self.reactions[key] then
        self.reactions[key] = reaction
        return
    end
    update(self.reactions[key],reaction)
end

function Action:set_weight(key, value)
    if not self.conditions[key] then
        error("Trying to set weight '"..key.."' without matching condition.")
    end
    self.weights[key] = value
end

return Action
```

File: /Goap.lua
--------------------------------
Replace the open/closed list handling with state-keyed maps. Also supply `state_key(state)` and use it everywhere for dedup.

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
    for key, rv in pairs(reaction) do
        -- Reactions have been validated to not contain -1
        if current_state[key] ~= rv then
            return false
        end
    end
    return true
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
        -- Open set keyed by state_key -> node
        olist =  {},
        -- Closed set keyed by state_key -> node
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
            -- Reconstruct using parent links (by id)
            local _path = {}
            while node.p_id do
                table.insert(_path, node)
                node = path.nodes[node.p_id]
            end
            return reverse(_path)
        end

        -- Move to closed
        path.clist[sk] = node

        -- Expand neighbors
        for action_name,_ in pairs(path.action_nodes) do
            if conditions_are_met(node.state, path.action_nodes[action_name].state) then
                local reaction = path.reactions[action_name]
                if reaction and not successor_is_noop(node.state, reaction) then
                    -- Build successor state
                    local succ_state = deepcopy(node.state)
                    for key, _value in pairs(reaction) do
                        succ_state[key] = _value
                    end
                    local succ_sk = state_key(succ_state)
                    local weight = path.weight_table[action_name] or 1
                    local tentative_g = node.g + weight

                    -- If state is in closed with better or equal g, skip
                    local closed_node = path.clist[succ_sk]
                    if closed_node and tentative_g >= closed_node.g then
                        goto continue_neighbor
                    end

                    local open_node = path.olist[succ_sk]
                    if not open_node or tentative_g < open_node.g then
                        -- Create or update node
                        local nn = open_node or { id = nil }
                        if not nn.id then
                            path.node_id = path.node_id + 1
                            nn.id = path.node_id
                        end
                        nn.name = action_name
                        nn.state = succ_state
                        nn.g = tentative_g
                        nn.h = heuristic_value(path.heuristic_strategy, succ_state, path.goal, path.heuristic_ctx)
                        nn.f = nn.g + nn.h
                        nn.p_id = node.id

                        path.nodes[nn.id] = nn
                        path.olist[succ_sk] = nn
                    end
                end
            end
            ::continue_neighbor::
        end
    end
end
```

File: /example_goap.lua
--------------------------------
No required change for functionality. Optional: keep the commented `world:set_heuristic("zero")` if you want guaranteed optimality with varied weights.

Behavioral notes and acceptance criteria:
- Deduplication: `olist` and `clist` are now keyed by `state_key(state)`. Re-expansions are prevented unless a strictly better `g` is found, in which case the node is updated/re-opened.
- `state_key(state)` sorts keys to ensure stable canonicalization; booleans are encoded as "1"/"0".
- Fewer expansions: hashing avoids O(n) scans and duplicate state entries, improving speed and correctness.
- Reaction semantics: `-1` is disallowed in reactions and raises an error on `Action:add_reaction`. `-1` continues to mean “don’t care” in conditions. The no-op skipping remains, but now reactions cannot contain `-1` (ambiguity removed).

If your domain needs non-boolean values in reactions:
- Remove or relax the boolean type check in `validate_reaction_table` but keep the `-1` rejection to preserve clarity.