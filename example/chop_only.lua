-- example/chop_only_fixed.lua
local goap = require("09_GOAP/01_init")

local Planner = goap.Planner
local Action  = goap.Action

-----------------------------------------------------------------
-- 0️⃣  World – only the keys that we really need
-----------------------------------------------------------------
local world = Planner(
    "logsNeeded",      -- how many logs we still have to produce
    "hasAxe",          -- do we own an axe?
    "axeEquipped",     -- is the axe in the primary hand?
    "hasTreeTarget",   -- have we selected a tree to chop?
    "atTree",          -- are we standing next to the selected tree?
    "hasStamina"       -- do we have stamina for a chop?
)

-----------------------------------------------------------------
-- 1️⃣  Start / Goal
-----------------------------------------------------------------
world:set_start_state{
    logsNeeded    = 2,      -- we want two logs
    hasAxe        = false,
    axeEquipped   = false,
    hasTreeTarget = false,
    atTree        = false,
    hasStamina    = true,   -- we start fresh
}
world:set_goal_state{
    logsNeeded = 0,         -- all logs produced
}

-----------------------------------------------------------------
-- 2️⃣  Action set – **only scalar equality** conditions
-----------------------------------------------------------------
local actions = Action()

-- 2.1  Find an axe (no fancy “>0” test)
actions:add_condition('findAxe', {
    hasAxe = false,
})
actions:add_reaction('findAxe', {
    hasAxe = true,
})
actions:set_weight('findAxe', 10)

-- 2.2  Equip the axe
actions:add_condition('equipAxe', {
    hasAxe      = true,
    axeEquipped = false,
})
actions:add_reaction('equipAxe', {
    axeEquipped = true,
})
actions:set_weight('equipAxe', 1)

-- 2.3  Rest (only needed when stamina is false)
actions:add_condition('rest', {
    hasStamina = false,
})
actions:add_reaction('rest', {
    hasStamina = true,
})
actions:set_weight('rest', 5)

-- 2.4  For each log we need a *find‑tree / walk‑to‑tree / chop* trio.
--    The condition `logsNeeded = i` guarantees we only run the i‑th
--    trio while we still need that many logs.
local logs_to_make = 2
for i = logs_to_make, 1, -1 do
    -- find a tree
    actions:add_condition('findTree'..i, {
        logsNeeded    = i,          -- we still need i logs
        axeEquipped   = true,
        hasStamina    = true,
        hasTreeTarget = false,
    })
    actions:add_reaction('findTree'..i, {
        hasTreeTarget = true,
    })
    actions:set_weight('findTree'..i, 4)

    -- walk to the tree
    actions:add_condition('walkToTree'..i, {
        hasTreeTarget = true,
        atTree        = false,
    })
    actions:add_reaction('walkToTree'..i, {
        atTree = true,
    })
    actions:set_weight('walkToTree'..i, 3)

    -- chop the tree (produces one log and drains stamina)
    actions:add_condition('chopTree'..i, {
        logsNeeded    = i,
        axeEquipped   = true,
        hasStamina    = true,
        hasTreeTarget = true,
        atTree        = true,
    })
    actions:add_reaction('chopTree'..i, {
        logsNeeded    = i - 1,   -- one log created
        hasTreeTarget = false,  -- we must find a new tree for the next log
        atTree        = false,
        hasStamina    = false,  -- chopping makes us tired
    })
    actions:set_weight('chopTree'..i, 8)
end

-----------------------------------------------------------------
-- 3️⃣  Wire up planner
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
    print("❌ No plan – something is still impossible")
else
    print("\n=== CHOP‑ONLY PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i, node in ipairs(plan) do
        print(string.format("%2d. %-20s (g=%d)", i, node.name, node.g))
    end
    print(string.format("\n🕑 Planning took %.4f s\n", took))
end