-- example_barricade.lua
-- ---------------------------------------------------------------
--  This file demonstrates how to drive the GOAP engine you posted
--  with a “Barricade Building” problem that was previously
--  coded as a single task in Project Zomboid.
--
--  The six primitive actions are:
--      1) ensureResources   – get hammer, plank and nails
--      2) findWindow        – pick an un‑barricaded window
--      3) walkToWindow      – move next to the window
--      4) equipTools        – put hammer/plank in the hands
--      5) barricadeWindow   – perform the timed barricade action
--      (a sixth “finishTask” step isn’t needed – the
--       barricadeWindow action already marks the job done)
-- ---------------------------------------------------------------

require("bootstrap")      -- sets the package.path for the demo
require("deps")           -- only needed if you vendored Penlight yourself

local Planner = require("Planner")
local Action  = require("Action")

-----------------------------------------------------------------
-- 1)  Define the world variables (all booleans – the planner
--     treats missing keys as “don’t‑care”)
-----------------------------------------------------------------
local world = Planner(
    'hasHammer',        -- do we already have a hammer?
    'hasPlank',         -- do we already have a plank?
    'hasNails',         -- do we have at least two nails?
    'atBuilding',       -- are we inside a building?
    'windowAvailable',  -- is there at least one un‑barricaded window left?
    'windowTarget',     -- have we selected a window to work on?
    'nearWindow',       -- are we next to the selected window?
    'equipped',         -- are hammer & plank in the hands?
    'barricaded',      -- has the selected window been barricaded?
    'taskComplete'      -- overall job finished?
)

-- Starting conditions (what the survivor actually knows at the start)
world:set_start_state{
    hasHammer        = false,
    hasPlank         = false,
    hasNails         = false,
    atBuilding       = true,      -- we start inside a building
    windowAvailable  = true,      -- there is a window that needs a barricade
    windowTarget     = false,
    nearWindow       = false,
    equipped         = false,
    barricaded       = false,
    taskComplete     = false,
}

-- Goal – we just want the whole job to be done.
world:set_goal_state{
    taskComplete = true,
}

-----------------------------------------------------------------
-- 2)  Declare the six primitive actions.
-----------------------------------------------------------------
local actions = Action()

-- ----------------------------------------------------------------
-- 1) ensureResources
--    Preconditions: we do NOT already have a hammer (that is enough –
--    if the hammer is present the action is simply not applicable).
--    Effects: we now own hammer, plank and nails.
-- ----------------------------------------------------------------
actions:add_condition('ensureResources', {hasHammer = false})
actions:add_reaction ('ensureResources', {
    hasHammer = true,
    hasPlank  = true,
    hasNails  = true,
})

-- ----------------------------------------------------------------
-- 2) findWindow
--    Preconditions: we are inside a building and there is a window left.
--    Effects: a concrete window becomes our target and we mark that
--    the pool of “available windows” is now empty (single‑window demo).
-- ----------------------------------------------------------------
actions:add_condition('findWindow', {atBuilding = true, windowAvailable = true})
actions:add_reaction ('findWindow', {
    windowTarget    = true,
    windowAvailable = false,   -- we have claimed the only window
})

-- ----------------------------------------------------------------
-- 3) walkToWindow
--    Preconditions: we have a target window but we are not yet next
--    to it.
--    Effects: we are now “near” the window.
-- ----------------------------------------------------------------
actions:add_condition('walkToWindow', {windowTarget = true, nearWindow = false})
actions:add_reaction ('walkToWindow', {
    nearWindow = true,
})

-- ----------------------------------------------------------------
-- 4) equipTools
--    Preconditions: we have the required items, are near the window
--    and are not already equipped.
--    Effects: the survivor now holds hammer (primary) and plank
--    (secondary) – represented by a single boolean flag.
-- ----------------------------------------------------------------
actions:add_condition('equipTools', {
    hasHammer = true,
    hasPlank  = true,
    hasNails  = true,
    nearWindow = true,
    equipped   = false,
})
actions:add_reaction ('equipTools', {
    equipped = true,
})

-- ----------------------------------------------------------------
-- 5) barricadeWindow
--    Preconditions: we are equipped, are near the window and the
--    window has not yet been barricaded.
--    Effects: the window becomes barricaded, the overall task is
--    marked complete and a few temporary flags are cleared.
-- ----------------------------------------------------------------
actions:add_condition('barricadeWindow', {
    equipped   = true,
    nearWindow = true,
    barricaded = false,
})
actions:add_reaction ('barricadeWindow', {
    barricaded   = true,
    taskComplete = true,
    equipped     = false,   -- tools are dropped after the action
    nearWindow   = false,
    windowTarget = false,
})

-- ----------------------------------------------------------------
-- (Optional) a separate “finishTask” action is not needed for this
-- simple demo because the previous action already sets taskComplete.
-- ----------------------------------------------------------------

-- ----------------------------------------------------------------
-- 6)  Action costs (the planner adds the cost to the g‑value)
-- ----------------------------------------------------------------
actions:set_weight('ensureResources', 1)   -- cheap “grab stuff”
actions:set_weight('findWindow',      1)   -- locating a window
actions:set_weight('walkToWindow',   2)   -- walking costs a bit more
actions:set_weight('equipTools',     1)   -- instant equip
actions:set_weight('barricadeWindow',5)   -- the 100‑tick timed action

-----------------------------------------------------------------
-- 3)  Wire the actions to the planner
-----------------------------------------------------------------
world:set_action_list(actions)

-----------------------------------------------------------------
-- 4)  Run the planner and print the resulting plan
-----------------------------------------------------------------
local t0   = os.clock()
local plan = world:calculate()   -- returns a list of nodes (or {} if none)
local took = os.clock() - t0

if plan and #plan > 0 then
    print("=== PLAN ===")
    for i, node in ipairs(plan) do
        -- each node has .name (the action name) and .g (cumulative cost)
        print(string.format("%2d. %s  (g = %d)", i, node.name, node.g))
    end
    print(string.format("\nPlanning took %.4f s (total g‑cost = %d)",
                         took, plan[#plan].g))
else
    print("No plan could be found.")
end