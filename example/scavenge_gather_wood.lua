-- example/scavenge_gather_wood.lua
-- --------------------------------------------------------------
--  A combined task:
--    1️⃣  Find an un‑looted building, enter it (door) and loot a container.
--    2️⃣  After the loot is secured, go outside, find wood, pick it up,
--        walk to a drop‑off point (the building) and drop it.
--  The plan shows a realistic “go‑out‑and‑collect‑resources‑after‑loot”
--  behaviour for a Zomboid survivor.
-- --------------------------------------------------------------

local goap = require("09_GOAP/01_init")

local Planner = goap.Planner
local World   = goap.World
local ScavengeTask = goap.tasks.scavenge   -- loot / entry task factory
local GatherTask   = goap.tasks.gather_wood -- wood‑gathering task factory

-----------------------------------------------------------------
-- 0️⃣  World definition (all keys that may appear in any task)
-----------------------------------------------------------------
local world = Planner(
    -- Scavenge‑related keys
    "wantsToLoot", "hasBuildingTarget", "atBuilding", "isInside",
    "containersToLoot", "hasContainerTarget", "atContainer", "hasRoomInBag",
    "entryMethod", "hasBreachingTool",
    -- Gather‑related keys
    "woodNeeded", "hasWoodTarget", "atWoodTarget", "carryingWood", "atDropoff"
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

    -- Gather start (outside, nothing collected yet)
    woodNeeded         = 2,    -- we want two pieces of wood
    hasWoodTarget      = false,
    atWoodTarget       = false,
    carryingWood       = false,
    atDropoff          = false,
}

-- Goal: no containers left to loot **and** no wood left to gather.
world:set_goal_state{
    containersToLoot = 0,
    woodNeeded      = 0,
}

-----------------------------------------------------------------
-- 2️⃣  Build the mixed action set
-----------------------------------------------------------------
local scavenge_actions = ScavengeTask.create_actions(1)   -- loot 1 container
local gather_actions   = GatherTask.create_actions(2)     -- gather 2 pieces

-- Merge the two Action objects – they share the same internal tables.
-- (Both factories return a goap.Action, so we can simply copy the tables.)
local actions = goap.Action()
actions.conditions = {}
actions.reactions  = {}
actions.weights    = {}

-- Helper to copy a table of tables
local function merge(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
end
merge(actions.conditions, scavenge_actions.conditions)
merge(actions.reactions,  scavenge_actions.reactions)
merge(actions.weights,    scavenge_actions.weights)

merge(actions.conditions, gather_actions.conditions)
merge(actions.reactions,  gather_actions.reactions)
merge(actions.weights,    gather_actions.weights)

-----------------------------------------------------------------
-- 3️⃣  Wire everything to the planner
-----------------------------------------------------------------
world:set_action_list(actions)
world:set_heuristic("rpg_add")   -- relaxed‑planning‑graph heuristic (fast & accurate)

-----------------------------------------------------------------
-- 4️⃣  Run & pretty‑print the plan
-----------------------------------------------------------------
local t0   = os.clock()
local plan = world:calculate()
local took = os.clock() - t0

if not plan or #plan == 0 then
    print("❌ No plan could be found – check the start/goal states.")
else
    print("\n=== SCAVENGE + GATHER PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-25s (g = %d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end