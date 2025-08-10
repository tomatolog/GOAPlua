-- example/scavenge_then_barricade.lua
-- --------------------------------------------------------------
--  A realistic “loot‑then‑secure” routine:
--    1️⃣  Find an un‑looted building, move inside (door) and loot a container.
--    2️⃣  While still inside, barricade all windows (3 in this demo).
--  The plan demonstrates how two distinct task factories can be blended
--  into a single coherent GOAP plan.
-- --------------------------------------------------------------

require("bootstrap")
require("deps")
local goap = require("goap")

local Planner = goap.Planner
local ScavengeTask = goap.tasks.scavenge
local BarricadeTask = goap.tasks.barricade

-----------------------------------------------------------------
-- 0️⃣  World definition – union of both task key‑sets
-----------------------------------------------------------------
local world = Planner(
    -- Scavenge keys
    "wantsToLoot", "hasBuildingTarget", "atBuilding", "isInside",
    "containersToLoot", "hasContainerTarget", "atContainer", "hasRoomInBag",
    "entryMethod", "hasBreachingTool",
    -- Barricade keys
    "hasHammer", "hasPlank", "hasNails", "windowsRemaining",
    "hasTarget", "nearWindow", "equipped", "taskComplete"
)

-----------------------------------------------------------------
-- 1️⃣  Start & goal
-----------------------------------------------------------------
world:set_start_state{
    -- Scavenge start
    wantsToLoot        = true,
    hasBuildingTarget  = false,
    atBuilding         = false,
    isInside           = false,
    containersToLoot   = 1,
    hasContainerTarget = false,
    atContainer        = false,
    hasRoomInBag       = true,
    entryMethod        = "door",
    hasBreachingTool   = false,

    -- Barricade start
    hasHammer          = false,
    hasPlank           = false,
    hasNails           = false,
    windowsRemaining   = 3,
    hasTarget          = false,
    nearWindow         = false,
    equipped           = false,
    taskComplete       = false,
}

world:set_goal_state{
    containersToLoot = 0,      -- all loot taken
    windowsRemaining = 0,      -- all windows barricaded
    taskComplete     = true,   -- optional flag
}

-----------------------------------------------------------------
-- 2️⃣  Build the combined action set
-----------------------------------------------------------------
local scavenge_actions = ScavengeTask.create_actions(1)   -- loot one container
local barricade_actions = BarricadeTask.create_actions(3) -- three windows

local actions = goap.Action()
actions.conditions = {}
actions.reactions  = {}
actions.weights    = {}

local function merge(dst, src)
    for k, v in pairs(src) do dst[k] = v end
end

merge(actions.conditions, scavenge_actions.conditions)
merge(actions.reactions,  scavenge_actions.reactions)
merge(actions.weights,    scavenge_actions.weights)

merge(actions.conditions, barricade_actions.conditions)
merge(actions.reactions,  barricade_actions.reactions)
merge(actions.weights,    barricade_actions.weights)

-----------------------------------------------------------------
-- 3️⃣  Configure planner
-----------------------------------------------------------------
world:set_action_list(actions)
world:set_heuristic("rpg_add")

-----------------------------------------------------------------
-- 4️⃣  Run & display plan
-----------------------------------------------------------------
local t0   = os.clock()
local plan = world:calculate()
local took = os.clock() - t0

if not plan or #plan == 0 then
    print("❌ No viable plan – check that the start state satisfies the pre‑conditions.")
else
    print("\n=== SCAVENGE + BARRICADE PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-30s (g = %d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end