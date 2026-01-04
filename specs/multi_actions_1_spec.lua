-- File: specs/multi_actions_1_spec.lua
-- ------------------------------------------------------------------
--  A complex multi-domain test for the GOAP planner.
--  Scenario: "The Ultimate Survival Day"
--  Goal: Eat food, plant crops, and eliminate a threat.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local Action = require("09_GOAP/Action")

-- Import task factories
local ScavengeTask = require("09_GOAP/tasks.scavenge")
local EatFoodTask = require("09_GOAP/tasks.eat_food")
local FarmingTask = require("09_GOAP/tasks.farming")
local CombatTask = require("09_GOAP/tasks.combat")

describe("Complex Multi-Action Planner", function()

  -- Helper to merge action sets
  local function merge_actions(target, source)
    for k, v in pairs(source.conditions) do target.conditions[k] = v end
    for k, v in pairs(source.reactions) do target.reactions[k] = v end
    for k, v in pairs(source.weights) do target.weights[k] = v end
  end

  it("should create a long plan involving scavenging, eating, farming, and combat", function()
    -- 1. Define the World Keys
    local world = Planner(
        -- Scavenge
        "wantsToLoot", "hasBuildingTarget", "atBuilding", "isInside",
        "containersToLoot", "hasContainerTarget", "atContainer", "hasRoomInBag",
        "entryMethod", "hasBreachingTool",
        -- Eat
        "hungry", "hasFood", "isSafe",
        -- Farming
        "hasTrowel", "hasSeeds", "hasWaterContainer", "atFarmingArea",
        "isPlowed", "isSeeded", "isWatered", "cropReady", "hasProduce",
        -- Combat
        "hasWeapon", "armed", "threatKnown", "threatVisible", "threatEliminated"
    )

    -- 2. Define Start State
    world:set_start_state{
        -- Scavenge
        wantsToLoot = true,
        hasBuildingTarget = false,
        atBuilding = false,
        isInside = false,
        containersToLoot = 1, -- Looting will give us items (abstracted via effects below)
        hasContainerTarget = false,
        atContainer = false,
        hasRoomInBag = true,
        entryMethod = "door",
        hasBreachingTool = false,

        -- Needs
        hungry = true,
        hasFood = false,
        isSafe = false,

        -- Farming resources (missing)
        hasTrowel = true, -- Let's say we have a trowel already to save *some* steps
        hasSeeds = false,
        hasWaterContainer = false,
        atFarmingArea = false,
        isPlowed = false,
        isSeeded = false,
        isWatered = false,
        cropReady = false,
        hasProduce = false,

        -- Combat (Threat active!)
        hasWeapon = false,
        armed = false,
        threatKnown = true,
        threatVisible = false,
        threatEliminated = false
    }

    -- 3. Define Goal State
    world:set_goal_state{
        hungry = false,          -- Must find and eat food
        isSeeded = true,         -- Must find seeds and plant them
        threatEliminated = true, -- Must find weapon and fight
    }

    -- 4. Combine Actions
    local combined_actions = Action()
    
    -- Load base task actions
    merge_actions(combined_actions, ScavengeTask.create_actions(1))
    merge_actions(combined_actions, EatFoodTask.create_actions())
    merge_actions(combined_actions, FarmingTask.create_actions())
    merge_actions(combined_actions, CombatTask.create_actions())

    -- 5. Link Scavenging to Resources
    -- The generic 'scavenge' task just reduces 'containersToLoot'.
    -- We need a bridge action: "Process Loot" or specific "Find X" actions 
    -- that are satisfied by looting.
    -- To keep it simple but working, we'll override the 'find' actions 
    -- from the individual tasks to require being inside/looting.
    
    -- Bridge: Looting a container gives us Food, Seeds, and a Weapon.
    -- We add a specific action that represents finding *all* these in the loot run.
    combined_actions:add_condition('rummageForSupplies', {
        isInside = true,
        containersToLoot = 0, -- Must have finished the looting cycle (generic scavenge)
        hasFood = false,
    })
    combined_actions:add_reaction('rummageForSupplies', {
        hasFood = true,
        hasSeeds = true,
        hasWeapon = true,
    })
    combined_actions:set_weight('rummageForSupplies', 2)

    -- Disable the generic "magic" find actions so the planner forces scavenging
    combined_actions.conditions.findFood = nil -- Must rummage
    combined_actions.conditions.findSeeds = nil -- Must rummage
    combined_actions.conditions.findWeapon = nil -- Must rummage
    
    -- 6. Execute Planner
    world:set_action_list(combined_actions)
    world:set_heuristic("rpg_add")

    local plan = world:calculate()

    -- 7. Verification
    assert.is_not_nil(plan)
    assert.is_true(#plan > 5, "Plan should be complex (length > 5)")

    local names = {}
    for i, node in ipairs(plan) do
        table.insert(names, node.name)
        -- print(i, node.name) -- Debug print
    end
    
    -- Check for key phases
    local phases = {
        scavenge = false,
        supplies = false,
        eat = false,
        farm = false,
        combat = false
    }

    for _, name in ipairs(names) do
        if name:find("Building") or name:find("Container") then phases.scavenge = true end
        if name == "rummageForSupplies" then phases.supplies = true end
        if name == "eatFood" then phases.eat = true end
        if name == "sowSeeds" then phases.farm = true end
        if name == "engageThreat" then phases.combat = true end
    end

    assert.is_true(phases.scavenge, "Should include scavenging")
    assert.is_true(phases.supplies, "Should find supplies")
    assert.is_true(phases.eat, "Should eat food")
    assert.is_true(phases.farm, "Should plant seeds")
    assert.is_true(phases.combat, "Should fight threat")
    
    -- Ensure logical ordering (roughly)
    -- Must rummage before eating/farming/fighting
    local rummage_idx
    for i, name in ipairs(names) do
        if name == "rummageForSupplies" then rummage_idx = i break end
    end
    assert.is_not_nil(rummage_idx)
    
    -- Check other actions happen AFTER rummaging
    for i, name in ipairs(names) do
        if name == "eatFood" or name == "sowSeeds" or name == "equipWeapon" then
            assert.is_true(i > rummage_idx, "Action " .. name .. " happened before rummaging!")
        end
    end

  end)
end)