--------------------------------------------------------------------
-- goap/init.lua
-- Public interface for the GOAP (Goal‑Oriented Action Planning) lib.
--
-- The file is deliberately *self‑contained*: it only requires the
-- internal implementation modules and then re‑exports a clean, fully
-- typed API together with extensive documentation and examples.
--
-- By reading this file you can:
--   • Create an Action set and add pre‑conditions / effects / costs.
--   • Build a Planner (world definition), set start & goal states,
--     give it the actions and run the A* search.
--   • Combine several Planners in a World and retrieve the cheapest plan.
--   • Use the ready‑made task factories (barricade, chop_wood,
--     gather_wood, scavenge) to avoid writing actions by hand.
--------------------------------------------------------------------

---@meta
---@module goap
---@author tomat

--------------------------------------------------------------------
-- Helper: short alias for the internal modules.
--------------------------------------------------------------------
local ActionImpl   = require("goap.Action")   -- class that stores conditions / reactions / weights
local PlannerImpl  = require("goap.Planner")  -- class that configures a single GOAP problem
local WorldImpl    = require("goap.World")    -- manager for many planners
local GoapImpl     = require("goap.Goap")     -- low‑level helpers (distance, astar, etc.)

--------------------------------------------------------------------
-- Export table – everything that `require("goap")` will return.
--------------------------------------------------------------------
local goap = {}

--------------------------------------------------------------------
-- Action
--------------------------------------------------------------------
--- Class representing a *set* of actions.
--- It is instantiated by calling the class like a function:
--- `local actions = goap.Action()`.
---
--- The internal representation stores three tables:
---   * `conditions` – map[action_name] = pre‑condition table
---   * `reactions`  – map[action_name] = effect table
---   * `weights`    – map[action_name] = numeric cost (must be > 0)
---
--- All three tables are public (read‑only) – they are useful for
--- debugging or for passing the whole object to a Planner.
---
--- **Public methods**
--- @field add_condition fun(self:goap.Action, name:string, cond:table):void
---   Add (or merge) a pre‑condition table for `name`.  Keys that already
---   exist are overwritten, otherwise they are added.
--- @field add_reaction  fun(self:goap.Action, name:string, reac:table):void
---   Add (or merge) an effect table for `name`.  A reaction must be
---   defined *after* a matching condition, otherwise an error is raised.
--- @field set_weight    fun(self:goap.Action, name:string, weight:number):void
---   Set the numeric cost of performing `name`.  The weight must be a
---   positive number; missing weights are considered an error by the
---   Planner.
goap.Action = ActionImpl

--------------------------------------------------------------------
-- Planner
--------------------------------------------------------------------
--- Class that defines a single GOAP problem (a “world” with a start
--- state, a goal state and a list of possible actions).
--- It is instantiated by passing the *complete* list of state keys that
--- may appear in the problem:
--- `local p = goap.Planner('hungry','has_food','in_kitchen')`.
---
--- The constructor builds an internal “unknown” value (`-1`) for every
--- key – this is the wildcard used by the planner.
---
--- **Public methods**
--- @field set_start_state  fun(self:goap.Planner, state:table):void
---   Define the initial world state.  All keys must belong to the list
---   given at construction time, otherwise an error is thrown.
--- @field set_goal_state   fun(self:goap.Planner, state:table):void
---   Define the desired goal state (same key restrictions as above).
--- @field set_action_list  fun(self:goap.Planner, actions:goap.Action):void
---   Provide the set of actions the planner may use.
--- @field set_heuristic    fun(self:goap.Planner, name:string, params?:table):void
---   Choose a heuristic for the A* search.  Supported names:
---     * `"mismatch"` – simple count of differing key‑values (default)
---     * `"zero"`     – Dijkstra (always 0)
---     * `"rpg_add"`  – relaxed‑planning‑graph additive heuristic
---     * `"domain_aware"` – a cheap, domain‑aware estimate:
---         * Counts how many key‑value pairs differ between the current
---           state and the goal.
---         * Divides that number by the *maximum* number of goal
---           propositions any single action can fix (pre‑computed by the
---           planner).  The result is an optimistic lower bound on the
---           number of actions still required.
---         * The heuristic is cheap (O(#goal)) and works well when action
---           costs are similar.
---   `params` is an optional table forwarded to the heuristic (e.g. the
---   pre‑built RPG when using `"rpg_add"`).
--- @field calculate        fun(self:goap.Planner):table|nil
---   Run the A* search and return an ordered list of nodes (or `{}` if
---   no plan exists).  Each node contains:
---     * `name` – action name (string)
---     * `g`    – cumulative cost up to this node
---     * `state`– world state after the action
---   The last node’s `state` satisfies the goal.
goap.Planner = PlannerImpl

--------------------------------------------------------------------
-- World
--------------------------------------------------------------------
--- Class that can hold *many* Planner instances and compute the cheapest
--- plan among them.  Useful when you want to try several start/goal
--- configurations in parallel (e.g. different entry methods for a
--- building).
---
--- **Public methods**
--- @field add_planner fun(self:goap.World, planner:goap.Planner):void
---   Register a Planner that will be evaluated when `calculate()` is called.
--- @field calculate   fun(self:goap.World):void
---   Run `calculate()` on every registered Planner, storing the results.
--- @field get_plan    fun(self:goap.World, debug?:boolean):table|nil
---   Return the cheapest plan(s).  If `debug` is true a human‑readable
---   dump of all found plans (sorted by total cost) is printed.
goap.World = WorldImpl

--------------------------------------------------------------------
-- Low‑level helpers (rarely needed directly)
--------------------------------------------------------------------
--- The `goap.Goap` table contains pure functions that the planner
--- uses internally.  They are documented here for completeness.
--- @field distance_to_state fun(a:table, b:table):number
---   Number of mismatching key‑values (ignores `-1` wildcards).
--- @field conditions_are_met fun(state:table, cond:table):boolean
---   Returns true if `cond` is satisfied by `state` (wildcards allowed).
--- @field astar fun(
---        start:table,
---        goal:table,
---        actions:table,
---        reactions:table,
---        weights:table,
---        heuristic:string?,
---        heuristic_params:table?,
---        options:table?
---     ):table|nil
---   Core A* implementation.  Normally you call it through
---   `Planner:calculate()`; the signature is shown for advanced use.
goap.Goap = GoapImpl

--------------------------------------------------------------------
-- Reusable task factories
--------------------------------------------------------------------
--- `goap.tasks` groups a handful of ready‑made action generators.
--- They are **factory modules**, not classes – each provides a single
--- function `create_actions(<parameter>)` that returns a fully‑filled
--- `goap.Action` object.
---
--- The factories are deliberately lightweight, so you can import only the
--- ones you need:
---   * `goap.tasks.barricade.create_actions(num_windows)`
---   * `goap.tasks.chop_wood.create_actions(logs_to_create)`
---   * `goap.tasks.gather_wood.create_actions(wood_to_gather)`
---   * `goap.tasks.scavenge.create_actions(containers_to_loot?)`
---
--- The return type of each factory is `goap.Action`, ready to be passed
--- to a Planner via `Planner:set_action_list()`.
goap.tasks = {
    barricade   = require("goap.tasks.barricade"),
    chop_wood   = require("goap.tasks.chop_wood"),
    gather_wood = require("goap.tasks.gather_wood"),
    scavenge    = require("goap.tasks.scavenge"),
}

--------------------------------------------------------------------
-- Example snippets
--------------------------------------------------------------------
--[[ ----------------------------------------------------------------
--- 1️⃣  Simple “cook‑and‑eat” example
--- ----------------------------------------------------------------
local goap = require("goap")
local actions = goap.Action()

actions:add_condition('cook', { in_kitchen = true, has_food = false })
actions:add_reaction ('cook', { has_food = true })
actions:set_weight('cook', 3)

actions:add_condition('eat', { hungry = true, has_food = true })
actions:add_reaction ('eat', { hungry = false, has_food = false })
actions:set_weight('eat', 1)

local planner = goap.Planner('hungry', 'has_food', 'in_kitchen')
planner:set_start_state{ hungry = true, has_food = false, in_kitchen = false }
planner:set_goal_state { hungry = false }
planner:set_action_list(actions)
planner:set_heuristic('rpg_add')      -- optional, default is "mismatch"

local plan = planner:calculate()
if plan and #plan > 0 then
    print("=== Plan ===")
    for i, node in ipairs(plan) do
        print(i .. ". " .. node.name .. " (cost=" .. node.g .. ")")
    end
else
    print("No plan found.")
end
]]--

--[[ ----------------------------------------------------------------
--- 2️⃣  Using a reusable task (barricade multiple windows)
--- ----------------------------------------------------------------
local goap = require("goap")
local Planner = goap.Planner
local World   = goap.World
local BarricadeTask = goap.tasks.barricade   -- factory module

local MAX_WINDOWS = 3
local world = Planner(
    "hasHammer","hasPlank","hasNails","atBuilding",
    "windowsRemaining","hasTarget","nearWindow","equipped"
)

world:set_start_state{
    hasHammer        = false,
    hasPlank         = false,
    hasNails         = false,
    atBuilding       = true,
    windowsRemaining = MAX_WINDOWS,
    hasTarget        = false,
    nearWindow       = false,
    equipped         = false,
}
world:set_goal_state{ windowsRemaining = 0 }

-- Create the actions specific to the number of windows we have.
world:set_action_list( BarricadeTask.create_actions(MAX_WINDOWS) )
world:set_heuristic("rpg_add")

local plan = world:calculate()
if plan and #plan > 0 then
    print("\n=== Barricade Plan (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-20s (g=%d)", i, node.name, node.g))
    end
else
    print("No barricade plan found.")
end
]]--

--[[ ----------------------------------------------------------------
--- 3️⃣  Combining several planners in a World (different entry methods)
--- ----------------------------------------------------------------
local goap = require("goap")
local Planner = goap.Planner
local World   = goap.World
local ScavengeTask = goap.tasks.scavenge

local world = World()

-- Planner A – try to enter via door
local pDoor = Planner(
    "wantsToLoot","hasBuildingTarget","atBuilding","isInside",
    "containersToLoot","hasContainerTarget","atContainer","hasRoomInBag",
    "entryMethod","hasBreachingTool"
)
pDoor:set_start_state{
    wantsToLoot = true, hasBuildingTarget = false, atBuilding = false,
    isInside = false, containersToLoot = 1, hasContainerTarget = false,
    atContainer = false, hasRoomInBag = true, entryMethod = "door",
    hasBreachingTool = false,
}
pDoor:set_goal_state{ containersToLoot = 0 }
pDoor:set_action_list( ScavengeTask.create_actions(1) )
pDoor:set_heuristic("rpg_add")
world:add_planner(pDoor)

-- Planner B – try to enter via window (different entryMethod)
local pWindow = Planner(
    "wantsToLoot","hasBuildingTarget","atBuilding","isInside",
    "containersToLoot","hasContainerTarget","atContainer","hasRoomInBag",
    "entryMethod","hasBreachingTool"
)
pWindow:set_start_state{
    wantsToLoot = true, hasBuildingTarget = false, atBuilding = false,
    isInside = false, containersToLoot = 1, hasContainerTarget = false,
    atContainer = false, hasRoomInBag = true, entryMethod = "window",
    hasBreachingTool = false,
}
pWindow:set_goal_state{ containersToLoot = 0 }
pWindow:set_action_list( ScavengeTask.create_actions(1) )
pWindow:set_heuristic("rpg_add")
world:add_planner(pWindow)

world:calculate()
local bestPlans = world:get_plan(true)   -- prints debug info
if bestPlans then
    print("\n=== Cheapest plan (cost = " .. bestPlans[1] [ #bestPlans [ 1 ] ] . g .. ") ===")
    for i, node in ipairs(bestPlans[1]) do
        print(i .. ". " .. node.name)
    end
else
    print("No plan could be found.")
end
]]--

--------------------------------------------------------------------
-- Return the public table
--------------------------------------------------------------------
return goap