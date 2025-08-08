-- File: example_barricade.lua
-- --------------------------------------------------------------
--  A tiny stand‑alone GOAP demonstration that reproduces the
--  Project Zomboid "BarricadeBuildingTask", but works for an
--  arbitrary number of windows (controlled by MAX_WINDOWS).
-- --------------------------------------------------------------

require("bootstrap")       -- set the package path for the demo
require("deps")           -- optional, pulls in Penlight if vendored

local Planner = require("Planner")
local World   = require("World")   -- not used here, but kept for symmetry
local BarricadeTask = require("tasks.barricade") -- Import the reusable task actions

-----------------------------------------------------------------
--  0️⃣  World definition
-----------------------------------------------------------------
local MAX_WINDOWS = 3      -- change to 2,4,5 … to test other sizes

local world = Planner(
    "hasHammer", "hasPlank", "hasNails", "atBuilding",
    "windowsRemaining", "hasTarget", "nearWindow", "equipped"
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

world:set_goal_state{
    windowsRemaining = 0,
}

-----------------------------------------------------------------
--  2️⃣  Build the actions using the reusable task module
-----------------------------------------------------------------
local actions = BarricadeTask.create_actions(MAX_WINDOWS)

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