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
--  - `goap.Action`: A class to define actions with preconditions, effects, and costs. Call `goap.Action:new()` to create an instance.
--  - `goap.Planner`: A class to configure and solve a single planning problem. Call `goap.Planner:new(...)` to create an instance.
--  - `goap.World`: A class to manage multiple planners. Call `goap.World:new()` to create an instance.
--  - `goap.tasks`: A collection of pre-made, reusable action sets for common tasks.
--
--@usage
-- -- main.lua
-- local goap = require("goap")
--
-- -- 1. Create an Action set.
-- local actions = goap.Action:new()
-- actions:add_condition('cook', { in_kitchen = true, has_food = false })
-- actions:add_reaction('cook', { has_food = true })
-- actions:set_weight('cook', 3)
--
-- -- 2. Create and configure a Planner.
-- local planner = goap.Planner:new('hungry', 'has_food', 'in_kitchen')
-- planner:set_start_state({ hungry = true, has_food = false, in_kitchen = false })
-- planner:set_goal_state({ hungry = false })
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
-- else
--     print("Could not find a plan.")
-- end

local goap = {}

-------------------------------------------------------------------------------
-- Class Definitions
-------------------------------------------------------------------------------

---
-- A class for defining a set of actions with preconditions, reactions, and costs.
-- @class goap.Action
-- @see goap.Action.add_condition
-- @see goap.Action.add_reaction
-- @see goap.Action.set_weight
goap.Action = require("goap.Action")

---
-- A class for setting up and running a single GOAP problem.
-- @class goap.Planner
-- @see goap.Planner.set_start_state
-- @see goap.Planner.set_goal_state
-- @see goap.Planner.set_action_list
-- @see goap.Planner.calculate
goap.Planner = require("goap.Planner")

---
-- A class for managing multiple planners to find the best overall plan.
-- @class goap.World
-- @see goap.World.add_planner
-- @see goap.World.calculate
-- @see goap.World.get_plan
goap.World = require("goap.World")


-------------------------------------------------------------------------------
-- Reusable Task Modules
-------------------------------------------------------------------------------

---
-- A collection of pre-defined, reusable action sets for common tasks.
-- @field barricade (table) Factory module for barricade actions.
-- @field chop_wood (table) Factory module for wood-chopping actions.
-- @field gather_wood (table) Factory module for wood-gathering actions.
-- @field scavenge (table) Factory module for scavenging actions.
goap.tasks = {
    barricade   = require("goap.tasks.barricade"),
    chop_wood   = require("goap.tasks.chop_wood"),
    gather_wood = require("goap.tasks.gather_wood"),
    scavenge    = require("goap.tasks.scavenge"),
}

return goap