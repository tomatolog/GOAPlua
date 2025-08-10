---@meta
---@module goap
---@author Lua Library Architect

---
-- A flexible and lightweight Goal-Oriented Action Planning (GOAP) library for Lua.
--
-- This module provides the core components to build and solve GOAP problems. It allows an
-- agent's world state, a set of possible actions, and a desired goal to be defined, and
-- then calculates an optimal sequence of actions to reach that goal.
--
--@usage
-- -- main.lua
-- local goap = require("goap")
--
-- -- 1. Create an Action set.
-- local actions = goap.Action()
--
-- actions:add_condition('cook', { in_kitchen = true, has_food = false })
-- actions:add_reaction('cook', { has_food = true })
-- actions:set_weight('cook', 3)
--
-- actions:add_condition('eat', { hungry = true, has_food = true })
-- actions:add_reaction('eat', { hungry = false, has_food = false })
-- actions:set_weight('eat', 1)
--
-- -- 2. Create and configure a Planner.
-- local planner = goap.Planner('hungry', 'has_food', 'in_kitchen')
-- planner:set_start_state({ hungry = true, has_food = false, in_kitchen = false })
-- planner:set_goal_state({ hungry = false })
-- planner:set_action_list(actions)
--
-- -- Optional: Set a different heuristic for the planner.
-- planner:set_heuristic("rpg_add")
--
-- -- 3. Calculate the plan.
-- local plan = planner:calculate()
--
-- -- 4. Print the result.
-- if plan and #plan > 0 then
--     print("=== Plan Found! ===")
--     for i, node in ipairs(plan) do
--         print(string.format("%d. %s (cost: %d)", i, node.name, node.g))
--     end
-- else
--     print("Could not find a plan.")
-- end

local goap = {}

-------------------------------------------------------------------------------
-- Class Definitions
-------------------------------------------------------------------------------

---
-- A class for defining a set of actions.
-- Instantiated by calling the class directly: `local actions = goap.Action()`
-- @class goap.Action
---@field add_condition fun(self, name:string, conditions:table):void Adds a precondition for an action.
---@field add_reaction fun(self, name:string, reaction:table):void Adds an effect (reaction) for an action.
---@field set_weight fun(self, name:string, weight:number):void Sets the cost for performing an action.
goap.Action = require("goap.Action")

---
-- A class for setting up and running a single GOAP problem.
-- Instantiated by calling the class directly, passing all world state keys as strings:
-- `local planner = goap.Planner('key1', 'key2', ...)`
-- @class goap.Planner
---@field set_start_state fun(self, state:table):void Sets the initial state of the world. Any keys not provided will be considered unknown.
---@field set_goal_state fun(self, state:table):void Sets the desired goal state for the planner to achieve.
---@field set_action_list fun(self, actions:goap.Action):void Provides the planner with the set of all possible actions.
---@field set_heuristic fun(self, name:string, params?:table):void Sets the heuristic function for the A* search.
---  Heuristics guide the search towards the goal. Available strategies for `name`:
---  - `"mismatch"` (default): A simple count of differing key-values between the current state and the goal. Fast but not very accurate.
---  - `"zero"`: Always returns 0. Turns A* into Dijkstra's algorithm, guaranteeing the cheapest path but can be very slow.
---  - `"rpg_add"`: Uses a Relaxed Planning Graph. Often provides the best balance of speed and accuracy for complex problems.
---@field calculate fun(self):table|nil Executes the search to find a plan.
---  @return table|nil An ordered list of plan nodes if a plan is found, or an empty table `{}` if no plan exists. Each node contains `name` (string), `g` (number), and `state` (table).
goap.Planner = require("goap.Planner")

---
-- A class for managing multiple planners to find the best overall plan.
-- Instantiated by calling the class directly: `local world = goap.World()`
-- @class goap.World
---@field add_planner fun(self, planner:goap.Planner):void Adds a configured `Planner` instance to the world.
---@field calculate fun(self):void Runs the `calculate` method on all planners added to the world.
---@field get_plan fun(self, debug?:boolean):table|nil Retrieves the best plan(s) from the last calculation.
goap.World = require("goap.World")


-------------------------------------------------------------------------------
-- Reusable Task Modules
-------------------------------------------------------------------------------

---
-- A collection of pre-defined, reusable action sets for common tasks.
-- These are factory modules, not classes.
-- @class goap.tasks
---@field barricade { create_actions: fun(num_windows:number):goap.Action } Factory for barricade actions.
---@field chop_wood { create_actions: fun(logs_to_create:number):goap.Action } Factory for wood-chopping actions.
---@field gather_wood { create_actions: fun(wood_to_gather:number):goap.Action } Factory for wood-gathering actions.
---@field scavenge { create_actions: fun(containers_to_loot?:number):goap.Action } Factory for scavenging actions.
goap.tasks = {
    barricade   = require("goap.tasks.barricade"),
    chop_wood   = require("goap.tasks.chop_wood"),
    gather_wood = require("goap.tasks.gather_wood"),
    scavenge    = require("goap.tasks.scavenge"),
}

return goap