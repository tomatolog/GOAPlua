Below is a minimal refactor to modularize the Goap API and remove globals, while preserving all current functionality (hashing, no-op skipping, heuristics, no goto, etc.).

What changes
- Goap.lua now returns a module table with functions:
  - `distance_to_state`, `conditions_are_met`, `state_key`, `astar`, plus helpers if you want to call them in tests.
- Planner.lua and specs/goap_spec.lua import the module and call functions via `Goap.<fn>`.
- Removed dependence on implicit globals in other files.

Updated files

File: /Goap.lua
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

-- Expand all applicable actions from node
local function expand_neighbors(node, path)
    for action_name, _ in pairs(path.action_nodes) do
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
    _start_node.g = 0
    _start_node.h = heuristic_value(_path.heuristic_strategy, _start_node.state, goal_state, _path.heuristic_ctx)
    _start_node.f = _start_node.g + _start_node.h

    local sk_start = Goap.state_key(_start_node.state)
    _path.olist[sk_start] = deepcopy(_start_node)

    -- Cache action condition nodes for applicability checks
    for k,v in pairs(actions) do
        _path.action_nodes[k] = create_node(_path, deepcopy(v), k)
    end

    -- Walk
    while true do
        if next(_path.olist) == nil then
            return {}
        end

        -- Extract node with lowest f from open
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

        -- Expand neighbors
        expand_neighbors(node, _path)
    end
end

-- Export helpers if you want them for tests
Goap._helpers = {
    mismatch_count = mismatch_count
}

return Goap

File: /Planner.lua
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

function Planner:calculate()
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

File: /specs/goap_spec.lua
--------------------------------
Update tests to use the module functions.

local Goap = require("Goap") -- module table

describe("Goap", function()
  it("distance_to_state handles equal states as 0", function()
    local s1 = { a = true, b = false }
    local s2 = { a = true, b = false }
    assert.equals(0, Goap.distance_to_state(s1, s2))
  end)

  it("distance_to_state counts differences and ignores -1 in goal", function()
    local s1 = { a = true, b = false, c = true }
    local s2 = { a = false, b = -1 } -- b ignored
    assert.equals(1, Goap.distance_to_state(s1, s2))
  end)

  it("distance_to_state handles asymmetric keys", function()
    local s1 = { a = true }
    local s2 = { a = false, b = true }
    assert.equals(2, Goap.distance_to_state(s1, s2))
  end)

  it("conditions_are_met respects -1 wildcard", function()
    local s = { a = true, b = false }
    local cond = { a = -1, b = false }
    assert.is_true(Goap.conditions_are_met(s, cond))
  end)

  it("state_key is stable and canonical", function()
    local s = { b=false, a=true }
    local s2 = { a=true, b=false }
    assert.equals(Goap.state_key(s), Goap.state_key(s2))
  end)

  it("astar finds a path and applies reactions", function()
    local start = { hungry = true, has_food = false }
    local goal  = { hungry = false }
    local actions = {
      cook = { hungry = true, has_food = false },
      eat = { hungry = true, has_food = true },
    }
    local reactions = {
      cook = { has_food = true },
      eat = { hungry = false, has_food = false },
    }
    local weights = { cook = 1, eat = 1 }

    local path = Goap.astar(start, goal, actions, reactions, weights)
    assert.is_true(#path >= 1)
    local names = {}
    for i, n in ipairs(path) do names[i] = n.name end
    assert.same({ "cook", "eat" }, names)
    local last = path[#path]
    assert.is_true(Goap.conditions_are_met(last.state, goal))
  end)

  it("astar prefers cheaper path based on weights", function()
    local start = { a = true }
    local goal  = { z = true }
    local actions = {
      step1 = { a=true },
      step2 = { b=true },
      heavy = { c=true },
    }
    local reactions = {
      step1 = { b = true },         -- a->b
      step2 = { z = true },         -- b->z
      heavy = { z = true },         -- c->z (but c not available)
    }
    local weights = { step1 = 1, step2 = 1, heavy = 100 }

    local path = Goap.astar(start, goal, actions, reactions, weights)
    local names = {}
    for i, n in ipairs(path) do names[i] = n.name end
    assert.same({ "step1", "step2" }, names)
  end)

  it("astar returns empty when no path", function()
    local start = { a = true }
    local goal  = { z = true }
    local actions = {
      x = { a = true }
    }
    local reactions = {
      x = { a = true } -- no progress to z
    }
    local weights = { x = 1 }
    local path = Goap.astar(start, goal, actions, reactions, weights)
    assert.same({}, path)
  end)
end)

Notes
- World.lua and example_goap.lua do not require changes for this item, unless you directly referenced global functions before. If you were calling global distance_to_state elsewhere, switch to Goap.distance_to_state.
- If any other file relied on globals from Goap.lua, update them similarly to require("Goap") and use the module table.