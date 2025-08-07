-- File: example_barricade.lua
-- --------------------------------------------------------------
--  A tiny stand‑alone GOAP demonstration that reproduces the
--  Project Zomboid "BarricadeBuildingTask", but works for an
--  arbitrary number of windows (controlled by MAX_WINDOWS).
-- --------------------------------------------------------------

require("bootstrap")       -- set the package path for the demo
require("deps")           -- optional, pulls in Penlight if vendored

local Planner = require("Planner")
local Action  = require("Action")
local World   = require("World")   -- not used here, but kept for symmetry

-----------------------------------------------------------------
--  0️⃣  World definition – every variable that can appear in a
--      condition / reaction must be listed here.
-----------------------------------------------------------------
local MAX_WINDOWS = 3      -- change to 2,4,5 … to test other sizes

local world = Planner(
    "hasHammer",      -- boolean – do we own a hammer?
    "hasPlank",       -- boolean – do we own a plank?
    "hasNails",       -- boolean – at least two nails?
    "atBuilding",     -- we start inside a building (always true)
    "windowsRemaining", -- integer counter of how many windows still need a barricade
    "hasTarget",      -- are we currently pointing at a concrete window?
    "nearWindow",     -- are we standing next to the target window?
    "equipped"        -- hammer+plank already in hand?
)

-----------------------------------------------------------------
--  1️⃣  Starting and goal states
-----------------------------------------------------------------
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

-- Goal: *all* windows have been barricaded → counter reaches 0
world:set_goal_state{
    windowsRemaining = 0,
}

-----------------------------------------------------------------
--  2️⃣  Build the six primitive actions
-----------------------------------------------------------------
local actions = Action()

-----------------------------------------------------------------
--  ensureResources – grab hammer, plank and nails if we don’t have them
-----------------------------------------------------------------
actions:add_condition('ensureResources', { hasHammer = false })
actions:add_reaction ('ensureResources', {
    hasHammer = true,
    hasPlank  = true,
    hasNails  = true,
})
actions:set_weight('ensureResources', 1)   -- cheap

-----------------------------------------------------------------
--  findWindow<N> – pick a concrete window when the counter is N
-----------------------------------------------------------------
for i = MAX_WINDOWS, 1, -1 do
    local name = "findWindow" .. i
    actions:add_condition(name, {
        windowsRemaining = i,
        hasTarget        = false,
    })
    actions:add_reaction(name, {
        hasTarget = true,               -- we now “own” a concrete window
    })
    actions:set_weight(name, 2)         -- a little more costly than walking
end

-----------------------------------------------------------------
--  walkToWindow – move next to the current target
-----------------------------------------------------------------
actions:add_condition('walkToWindow', {
    hasTarget  = true,
    nearWindow = false,
})
actions:add_reaction('walkToWindow', {
    nearWindow = true,
})
actions:set_weight('walkToWindow', 2)

-----------------------------------------------------------------
--  equipTools – put hammer in primary hand, plank in secondary
-----------------------------------------------------------------
actions:add_condition('equipTools', {
    hasHammer = true,
    hasPlank  = true,
    hasNails  = true,
    nearWindow = true,
    equipped   = false,          -- we only equip once (or when we drop them)
})
actions:add_reaction('equipTools', {
    equipped = true,
})
actions:set_weight('equipTools', 1)

-----------------------------------------------------------------
--  barricadeWindow<N> – actually barricade the window and decrement the counter
-----------------------------------------------------------------
for i = MAX_WINDOWS, 1, -1 do
    local name = "barricadeWindow" .. i
    actions:add_condition(name, {
        windowsRemaining = i,
        hasTarget        = true,
        nearWindow       = true,
        equipped         = true,
    })
    actions:add_reaction(name, {
        hasTarget        = false,          -- done with this window
        nearWindow       = false,          -- step back so we can walk to the next one
        windowsRemaining = i - 1,          -- one less window to barricade
        -- we keep 'equipped = true' – the tools stay in the hands
    })
    actions:set_weight(name, 5)          -- mirrors the 100‑tick timed action
end

-----------------------------------------------------------------
--  3️⃣  Hand the actions to the planner
-----------------------------------------------------------------
world:set_action_list(actions)

-----------------------------------------------------------------
--  4️⃣  Run the planner and pretty‑print the result
-----------------------------------------------------------------
local t0   = os.clock()
local plan = world:calculate()   -- returns an ordered array of nodes
local took = os.clock() - t0

if not plan or #plan == 0 then
    print("❌ No plan found – something is wrong.")
else
    print("\n=== PLAN (total cost = "..plan[#plan].g..") ===")
    for i, node in ipairs(plan) do
        -- node.name is the GOAP action name we gave above
        print(string.format("%2d. %-20s  (g = %d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end