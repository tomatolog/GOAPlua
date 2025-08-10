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
-- The primary components are:
--  - `goap.Action`: Defines the building blocks of a plan: actions with preconditions, effects, and costs.
--  - `goap.Planner`: Configures and solves a single planning problem.
--  - `goap.World`: Manages multiple planners to find the best plan among various strategies.
--  - `goap.tasks`: A collection of pre-made, reusable action sets for common tasks.
--
--@usage
-- -- main.lua
-- -- Assume this library is in a folder named 'goap' and is on the package path.
-- local goap = require("goap")
--
-- -- 1. Define all possible actions the agent can perform.
-- local actions = goap.Action()
--
-- -- Action: 'cook'
-- actions:add_condition('cook', { in_kitchen = true, has_food = false })
-- actions:add_reaction('cook', { has_food = true })
-- actions:set_weight('cook', 3) -- Cooking takes some time.
--
-- -- Action: 'eat'
-- actions:add_condition('eat', { hungry = true, has_food = true })
-- actions:add_reaction('eat', { hungry = false, has_food = false })
-- actions:set_weight('eat', 1) -- Eating is fast.
--
-- -- Action: 'go_to_kitchen'
-- actions:add_condition('go_to_kitchen', { in_kitchen = false })
-- actions:add_reaction('go_to_kitchen', { in_kitchen = true })
-- actions:set_weight('go_to_kitchen', 2)
--
-- -- 2. Define the planning problem.
-- -- The Planner needs to know all possible variables that define the world state.
-- local planner = goap.Planner('hungry', 'has_food', 'in_kitchen')
--
-- -- Set the initial state of the world.
-- planner:set_start_state({
--     hungry = true,
--     has_food = false,
--     in_kitchen = false,
-- })
--
-- -- Set the desired goal state.
-- planner:set_goal_state({
--     hungry = false,
-- })
--
-- -- Provide the set of available actions to the planner.
-- planner:set_action_list(actions)
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
--     print("Total plan cost: " .. plan[#plan].g)
-- else
--     print("Could not find a plan to satisfy the goal.")
-- end
--
-- -- Expected output:
-- -- === Plan Found! ===
-- -- 1. go_to_kitchen (cost: 2)
-- -- 2. cook (cost: 5)
-- -- 3. eat (cost: 6)
-- -- Total plan cost: 6
--
-- CORRECTED REQUIRES:
local Action = require("goap.Action")
local Planner = require("goap.Planner")
local World = require("goap.World")
local BarricadeTask = require("goap.tasks.barricade")
local ChopWoodTask = require("goap.tasks.chop_wood")
local GatherWoodTask = require("goap.tasks.gather_wood")
local ScavengeTask = require("goap.tasks.scavenge")

local goap = {}

-------------------------------------------------------------------------------
-- Classes
-------------------------------------------------------------------------------

---
-- Represents a collection of actions available to an agent.
--
-- An Action object is a container for defining the preconditions, effects (reactions),
-- and costs (weights) of all possible actions an agent can perform.
-- @class Action
goap.Action = Action

---
-- Adds a precondition for an action. If the action already exists, the new
-- conditions are merged with the existing ones.
-- @param name string The unique name of the action.
-- @param conditions table A table where keys are world state variables and values are the required states (e.g., `{ hungry = true }`).
function Action:add_condition(name, conditions) end

---
-- Adds an effect (reaction) for an action. This defines how the world state
-- changes after the action is successfully performed.
-- @param name string The unique name of the action. Must have a corresponding condition.
-- @param reaction table A table defining the resulting world state (e.g., `{ hungry = false }`).
function Action:add_reaction(name, reaction) end

---
-- Sets the cost for performing an action.
-- @param name string The unique name of the action. Must have a corresponding condition.
-- @param weight number The cost of the action. Must be a positive number.
function Action:set_weight(name, weight) end

---
-- Manages the setup and execution of a single GOAP problem.
--
-- A Planner is initialized with the complete set of variables that can describe
-- the world. It is then configured with a start state, a goal state, and a set
-- of available actions. The `calculate` method runs the A* search algorithm
-- to find a sequence of actions to reach the goal.
-- @class Planner
---@param ... string A variable number of strings, each being a key for a world state variable.
-- @usage local planner = goap.Planner('is_tired', 'has_energy', 'in_bed')
function Planner:new(...) end
goap.Planner = Planner

---
-- Sets the initial state of the world for the planning problem.
--
-- All keys in the state table must have been declared in the Planner's constructor.
-- Any declared world variables not included in the table will be considered "unknown" (`-1`).
-- @param state table A table representing the starting world state.
-- @usage planner:set_start_state({ is_tired = true, in_bed = false })
function Planner:set_start_state(state) end

---
-- Sets the desired goal state for the planner to achieve.
--
-- The planner will search for a sequence of actions that results in a world state
-- that satisfies all conditions specified in the goal state.
-- @param state table A table representing the goal state.
-- @usage planner:set_goal_state({ is_tired = false })
function Planner:set_goal_state(state) end

---
-- Provides the planner with the set of all possible actions.
-- @param actions Action An `Action` object containing all defined actions.
function Planner:set_action_list(actions) end

---
-- Sets the heuristic function to be used by the A* search algorithm.
--
-- Heuristics guide the search towards the goal, significantly affecting performance.
-- Available built-in heuristics:
-- - `"mismatch"` (default): A simple count of differing key-values between the current state and the goal.
-- - `"zero"`: A heuristic that always returns 0. Turns A* into Dijkstra's algorithm. Useful for finding the absolute cheapest path without any guidance.
-- - `"rpg_add"`: A more advanced heuristic based on a Relaxed Planning Graph. Often provides better performance for complex problems.
-- @param name string The name of the heuristic to use.
-- @param params? table Optional parameters for the heuristic function.
-- @usage planner:set_heuristic("rpg_add")
function Planner:set_heuristic(name, params) end

---
-- Executes the A* search to find a plan.
--
-- This method orchestrates the planning process based on the configured start state,
-- goal state, and actions. It returns the calculated sequence of actions.
-- @return table|nil An ordered list of plan nodes if a plan is found, or an empty table `{}` if no plan exists.
-- Each node in the list is a table with fields like `name` (the action name), `g` (cumulative cost), and `state`.
function Planner:calculate() end

---
-- A container for managing multiple `Planner` instances.
--
-- A World can be used to run several different planning strategies (each encapsulated
-- in a `Planner`) simultaneously and then select the best (lowest cost) plan from all
-- the results.
-- @class World
goap.World = World

---
-- Adds a configured `Planner` instance to the world.
-- @param planner Planner The planner object to add.
function World:add_planner(planner) end

---
-- Runs the `calculate` method on all planners added to the world.
function World:calculate() end

---
-- Retrieves the best plan(s) from the last calculation.
--
-- After `calculate()` is called, this method returns the plan or plans with the
-- lowest total cost among all managed planners.
-- @param debug? boolean If true, prints all calculated plans and their costs to the console.
-- @return table|nil A table containing the best plan(s), or `nil` if no plans were found.
function World:get_plan(debug) end


-------------------------------------------------------------------------------
-- Reusable Task Modules
-------------------------------------------------------------------------------

---
-- A collection of pre-defined, reusable action sets for common tasks.
--
-- These modules provide factory functions that generate a complete `goap.Action`
-- object for a specific, complex task, such as barricading multiple windows or
-- scavenging a building.
-- @class goap.tasks
goap.tasks = {
    ---
    -- A factory for creating barricade-related actions.
    -- @class goap.tasks.barricade
    barricade = {
        ---
        -- Generates a set of actions for barricading a specified number of windows.
        -- @param num_windows number The number of windows to generate actions for.
        -- @return Action An `Action` object populated with all barricade-related actions.
        create_actions = BarricadeTask.create_actions
    },
    ---
    -- A factory for creating wood-chopping actions.
    -- @class goap.tasks.chop_wood
    chop_wood = {
        ---
        -- Generates actions for finding an axe, felling trees, and resting.
        -- @param logs_to_create number The number of logs the plan should aim to create.
        -- @return Action An `Action` object populated with all wood-chopping actions.
        create_actions = ChopWoodTask.create_actions
    },
    ---
    -- A factory for creating wood-gathering actions.
    -- @class goap.tasks.gather_wood
    gather_wood = {
        ---
        -- Generates actions for finding, picking up, and dropping off wood.
        -- @param wood_to_gather number The number of wood items the plan should aim to gather.
        -- @return Action An `Action` object populated with all wood-gathering actions.
        create_actions = GatherWoodTask.create_actions
    },
    ---
    -- A factory for creating scavenging actions.
    -- @class goap.tasks.scavenge
    scavenge = {
        ---
        -- Generates a full set of actions for finding a building, entering it, and looting containers.
        -- @param containers_to_loot? number The number of containers to loot. If omitted, looting actions are not created.
        -- @return Action An `Action` object populated with all scavenging actions.
        create_actions = ScavengeTask.create_actions
    }
}


return goap