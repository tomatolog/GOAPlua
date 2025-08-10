-- example/barricade_only.lua
-- --------------------------------------------------------------
--  Stand‑alone test of the reusable “barricade” task.
--  It shows the missing finish‑action problem and how to fix it.
-- --------------------------------------------------------------

require("bootstrap")   -- whatever your environment needs
require("deps")
local goap = require("goap")

local Planner = goap.Planner
local Action  = goap.Action

-----------------------------------------------------------------
-- 0️⃣  World – list **all** keys that any action may read or write
-----------------------------------------------------------------
local world = Planner(
    "hasHammer", "hasPlank", "hasNails", "atBuilding",
    "windowsRemaining", "hasTarget", "nearWindow", "equipped",
    "taskComplete"               -- appears in the goal, must be declared
)

-----------------------------------------------------------------
-- 1️⃣  Start and goal states
-----------------------------------------------------------------
world:set_start_state{
    hasHammer        = false,
    hasPlank         = false,
    hasNails         = false,
    atBuilding       = true,   -- already inside the building
    windowsRemaining = 3,      -- three windows to barricade
    hasTarget        = false,
    nearWindow       = false,
    equipped         = false,
    taskComplete     = false,
}
world:set_goal_state{
    windowsRemaining = 0,      -- all windows are done
    taskComplete     = true,   -- we will set this with a tiny finish action
}

-----------------------------------------------------------------
-- 2️⃣  Load the barricade actions from the factory
-----------------------------------------------------------------
local BarricadeTask = goap.tasks.barricade
local actions = BarricadeTask.create_actions(3)   -- three windows

-----------------------------------------------------------------
-- 2.5  Add the missing “finish” action
-----------------------------------------------------------------
-- After the last window is barricaded we have:
--   windowsRemaining = 0
--   hasTarget        = false
--   nearWindow       = false
--   (the NPC may still be equipped – that does not matter)
actions:add_condition('markTaskComplete', {
    windowsRemaining = 0,
    hasTarget        = false,
    nearWindow       = false,
    -- note: we **do not** require equipped = false here
})
actions:add_reaction('markTaskComplete', {
    taskComplete = true,
})
actions:set_weight('markTaskComplete', 1)   -- cheap, final step

-----------------------------------------------------------------
-- 3️⃣  Wire the planner
-----------------------------------------------------------------
world:set_action_list(actions)
world:set_heuristic("rpg_add")   -- any heuristic works; “rpg_add” is fine

-----------------------------------------------------------------
-- 4️⃣  Run the planner (optional tiny debug output)
-----------------------------------------------------------------
local t0 = os.clock()
local plan = world:calculate()
local took = os.clock() - t0

if not plan or #plan == 0 then
    print("\n❌ No barricade plan – something is impossible")
else
    print("\n=== BARRICADE PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-20s (g=%d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end