-- File: goap/tasks/farming.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for the "farming" task.
--  Converted from FarmingTask.lua logic.
-- --------------------------------------------------------------
local Action = require("goap.Action")

local FarmingTask = {}

-- Factory function to create the actions for the farming task.
-- @return (Action) An Action object populated with all related actions.
function FarmingTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  Preparation: Getting Tools & Resources
    -----------------------------------------------------------------
    
    -- 1. findTrowel
    --    Condition: We need to plow but have no tool.
    --    Effect: We have a trowel/shovel.
    actions:add_condition('findTrowel', {
        hasTrowel = false,
    })
    actions:add_reaction('findTrowel', {
        hasTrowel = true
    })
    actions:set_weight('findTrowel', 5)

    -- 2. findSeeds
    --    Condition: We need to plant but have no seeds.
    --    Effect: We have seeds.
    actions:add_condition('findSeeds', {
        hasSeeds = false,
    })
    actions:add_reaction('findSeeds', {
        hasSeeds = true
    })
    actions:set_weight('findSeeds', 5)

    -- 3. findWater
    --    Condition: We need to water but have no water source/container.
    --    Effect: We have water.
    actions:add_condition('findWater', {
        hasWaterContainer = false,
    })
    actions:add_reaction('findWater', {
        hasWaterContainer = true
    })
    actions:set_weight('findWater', 5)

    -----------------------------------------------------------------
    --  Farming Cycle Actions
    -----------------------------------------------------------------

    -- 4. plowField
    --    Condition: We are at the farming area, have a tool, and the ground is raw.
    --    Effect: The ground is plowed.
    actions:add_condition('plowField', {
        atFarmingArea = true,
        hasTrowel = true,
        isPlowed = false,
        isSeeded = false, -- Can't plow if already growing (simplification)
    })
    actions:add_reaction('plowField', {
        isPlowed = true
    })
    actions:set_weight('plowField', 5)

    -- 5. sowSeeds
    --    Condition: Ground is plowed, we have seeds.
    --    Effect: Ground is seeded (crop planted).
    actions:add_condition('sowSeeds', {
        atFarmingArea = true,
        isPlowed = true,
        hasSeeds = true,
    })
    actions:add_reaction('sowSeeds', {
        isSeeded = true,
        isPlowed = false, -- State transition: plowed -> seeded
        hasSeeds = true,  -- Presume we have a packet with multiple seeds, or simple toggle
    })
    actions:set_weight('sowSeeds', 3)

    -- 6. waterPlant
    --    Condition: Crop is seeded but dry.
    --    Effect: Crop is watered.
    actions:add_condition('waterPlant', {
        atFarmingArea = true,
        isSeeded = true,
        isWatered = false,
        hasWaterContainer = true,
    })
    actions:add_reaction('waterPlant', {
        isWatered = true
    })
    actions:set_weight('waterPlant', 2)

    -- 7. harvestCrop
    --    Condition: Crop is ready (mature).
    --    Effect: We have produce (food), and the plot is cleared.
    actions:add_condition('harvestCrop', {
        atFarmingArea = true,
        cropReady = true,
    })
    actions:add_reaction('harvestCrop', {
        hasProduce = true,
        cropReady = false,
        isSeeded = false,
        isWatered = false,
        isPlowed = false, -- usually reverts to furrowed or dirt
    })
    actions:set_weight('harvestCrop', 4)

    -----------------------------------------------------------------
    --  Movement
    -----------------------------------------------------------------
    
    -- 8. goToFarmingArea
    --    Condition: We aren't there.
    --    Effect: We are there.
    actions:add_condition('goToFarmingArea', {
        atFarmingArea = false,
    })
    actions:add_reaction('goToFarmingArea', {
        atFarmingArea = true
    })
    actions:set_weight('goToFarmingArea', 2)

    return actions
end

return FarmingTask