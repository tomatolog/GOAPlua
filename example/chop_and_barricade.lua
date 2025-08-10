-- example/chop_and_barricade.lua
-- --------------------------------------------------------------
--  Combined “chop‑tree → barricade‑windows” example.
--  1️⃣  Chop wood to produce the required number of logs.
--  2️⃣  Use the same world to barricade three windows.
--  The plan interleaves the two task sets so the NPC first gets the
--  tools, chops, then proceeds to the windows.
-- --------------------------------------------------------------

require("bootstrap")
require("deps")
local goap = require("goap")

local Planner = goap.Planner
local ChopTask = goap.tasks.chop_wood   -- typo fixed below
local BarricadeTask = goap.tasks.barricade

-----------------------------------------------------------------
-- 0️⃣  World definition – union of all keys used by both tasks
-----------------------------------------------------------------
local world = Planner(
    -- Chop‑wood keys
    "logsNeeded", "hasAxe", "axeEquipped", "hasTreeTarget", "atTree", "hasStamina",
    -- Barricade keys
    "hasHammer", "hasPlank", "hasNails", "atBuilding",
    "windowsRemaining", "hasTarget", "nearWindow", "equipped", "taskComplete"
)

-----------------------------------------------------------------
-- 1️⃣  Starting and goal states
-----------------------------------------------------------------
world:set_start_state{
    -- Chop‑wood start
    logsNeeded     = 3,   -- we need three logs (one per window)
    hasAxe         = false,
    axeEquipped    = false,
    hasTreeTarget  = false,
    atTree         = false,
    hasStamina     = true,   -- start with stamina

    -- Barricade start
    hasHammer      = false,
    hasPlank       = false,
    hasNails       = false,
    atBuilding     = true,    -- already inside the building
    windowsRemaining = 3,
    hasTarget      = false,
    nearWindow     = false,
    equipped       = false,
    taskComplete   = false,
}

world:set_goal_state{
    windowsRemaining = 0,      -- all windows barricaded
    taskComplete     = true,   -- optional flag for readability
}

-----------------------------------------------------------------
-- 2️⃣  Build the mixed action set
-----------------------------------------------------------------
local chop_actions   = ChopTask.create_actions(3)      -- need 3 logs
local barricade_actions = BarricadeTask.create_actions(3)

local actions = goap.Action()
actions.conditions = {}
actions.reactions  = {}
actions.weights    = {}

local function merge(dst, src)
    for k, v in pairs(src) do dst[k] = v end
end

merge(actions.conditions, chop_actions.conditions)
merge(actions.reactions,  chop_actions.reactions)
merge(actions.weights,    chop_actions.weights)

merge(actions.conditions, barricade_actions.conditions)
merge(actions.reactions,  barricade_actions.reactions)
merge(actions.weights,    barricade_actions.weights)

-----------------------------------------------------------------
-- 3️⃣  Wire up planner
-----------------------------------------------------------------
world:set_action_list(actions)
world:set_heuristic("rpg_add")

-----------------------------------------------------------------
-- 4️⃣  Execute & print the plan
-----------------------------------------------------------------
local t0   = os.clock()
local plan = world:calculate()
local took = os.clock() - t0

if not plan or #plan == 0 then
    print("❌ No plan found – maybe some pre‑conditions are impossible.")
else
    print("\n=== CHOP‑AND‑BARRICADE PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-30s (g = %d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end