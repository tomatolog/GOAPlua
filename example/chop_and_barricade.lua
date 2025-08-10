-- example/chop_and_barricade.lua
-- --------------------------------------------------------------
--  Full GOAP example: 3 logs → 3 windows.
--  The plan now *must* chop the logs because the goal includes
--  logsNeeded = 0.
-- --------------------------------------------------------------

require("bootstrap")
require("deps")
local goap = require("goap")

local Planner = goap.Planner
local Action  = goap.Action

-----------------------------------------------------------------
-- 0️⃣  World definition – every key that any action may read/write
-----------------------------------------------------------------
local world = Planner(
    -- chop‑wood keys
    "logsNeeded", "hasAxe", "axeEquipped", "hasTreeTarget",
    "atTree", "hasStamina",
    -- barricade keys
    "hasHammer", "hasPlank", "hasNails", "atBuilding",
    "windowsRemaining", "hasTarget", "nearWindow", "equipped",
    "taskComplete"
)

-----------------------------------------------------------------
-- 1️⃣  Start & goal states
-----------------------------------------------------------------
world:set_start_state{
    -- chop‑wood start
    logsNeeded    = 3,
    hasAxe        = false,
    axeEquipped   = false,
    hasTreeTarget = false,
    atTree        = false,
    hasStamina    = true,

    -- barricade start
    hasHammer        = false,
    hasPlank         = false,
    hasNails         = false,
    atBuilding       = true,
    windowsRemaining = 3,
    hasTarget        = false,
    nearWindow       = false,
    equipped         = false,
    taskComplete     = false,
}
world:set_goal_state{
    windowsRemaining = 0,   -- all windows barricaded
    taskComplete     = true,
    logsNeeded       = 0,   -- **new** requirement – we must have cut all logs
}

-----------------------------------------------------------------
-- 2️⃣  Build the mixed action set
-----------------------------------------------------------------
local ChopTask      = goap.tasks.chop_wood
local BarricadeTask = goap.tasks.barricade

local chop_actions      = ChopTask.create_actions(3)   -- 3 logs
local barricade_actions = BarricadeTask.create_actions(3) -- 3 windows

local actions = Action()
actions.conditions = {}
actions.reactions  = {}
actions.weights    = {}

local function merge(dst, src)
    for k, v in pairs(src) do dst[k] = v end
end

-- copy chop‑wood tables
merge(actions.conditions, chop_actions.conditions)
merge(actions.reactions,  chop_actions.reactions)
merge(actions.weights,    chop_actions.weights)

-- copy barricade tables
merge(actions.conditions, barricade_actions.conditions)
merge(actions.reactions,  barricade_actions.reactions)
merge(actions.weights,    barricade_actions.weights)

-----------------------------------------------------------------
-- 2.5  Add the tiny “finish” action (sets taskComplete = true)
-----------------------------------------------------------------
actions:add_condition('markTaskComplete', {
    windowsRemaining = 0,
    hasTarget        = false,
    nearWindow       = false,
})
actions:add_reaction('markTaskComplete', {
    taskComplete = true,
})
actions:set_weight('markTaskComplete', 1)   -- cheap final step

-----------------------------------------------------------------
-- 3️⃣  Wire the planner
-----------------------------------------------------------------
world:set_action_list(actions)
world:set_heuristic("rpg_add")   -- any heuristic works; “rpg_add” is nice

-----------------------------------------------------------------
-- 4️⃣  Run & print the plan
-----------------------------------------------------------------
local t0   = os.clock()
local plan = world:calculate()
local took = os.clock() - t0

if not plan or #plan == 0 then
    print("\n❌ No plan – something is impossible")
else
    print("\n=== CHOP‑AND‑BARRICADE PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-30s (g = %d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end