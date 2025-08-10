local class = require('pl.class')
local deepcopy = require('pl.tablex').deepcopy
local Goap = require("goap.Goap")
local RPG = require("goap.relaxed_planning_graph")

-- debug
local PlannerDebug = require("goap.debug.PlannerDebug")
local RPGDebug = require("goap.debug.RPGDebug")

local Planner = class()
-- debug
for k,v in pairs(PlannerDebug) do
    Planner[k] = v          -- shallow mix‑in
end
Planner.dump_rpg = RPGDebug.dump_rpg   -- static method, receives the RPG object

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

-- New: validate that each action has an explicit, positive numeric weight,
-- and a matching reaction table.
local function validate_actions_and_weights(action_list)
    if not action_list or not action_list.conditions then
        error("No actions provided to planner")
    end
    local weights = action_list.weights or {}
    local reactions = action_list.reactions or {}
    for action_name, _ in pairs(action_list.conditions) do
        -- Validate reaction presence
        local r = reactions[action_name]
        if r == nil then
            error("Missing reaction for action '"..tostring(action_name).."'")
        end
        -- Validate weight presence and positivity
        local w = weights[action_name]
        if w == nil then
            error("Missing weight for action '"..tostring(action_name).."'")
        end
        if type(w) ~= "number" or w <= 0 or w ~= w then -- includes NaN check
            error("Invalid weight for action '"..tostring(action_name).."'")
        end
    end
end

function Planner:calculate()
     validate_actions_and_weights(self.action_list)

     -- Build the Relaxed Planning Graph once before the search begins.
     local rpg = RPG.build(
         self.start_state,
         self.action_list.conditions,
         self.action_list.reactions
     )

     -- Pass the RPG into the heuristic context.
     local heuristic_params = self.heuristic_params or {}
     heuristic_params.rpg = rpg

     return Goap.astar(
         self.start_state,
         self.goal_state,
         deepcopy(self.action_list.conditions),
         deepcopy(self.action_list.reactions),
         deepcopy(self.action_list.weights),
         self.heuristic_strategy,
         heuristic_params
     )
end

return Planner