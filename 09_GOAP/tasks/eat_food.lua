-- File: goap/tasks/eat_food.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for the "eat food" task.
--  Converted from EatFoodTask.lua logic.
-- --------------------------------------------------------------
local Action = require("09_GOAP/Action")

local EatFoodTask = {}

-- Factory function to create the actions for the eat food task.
-- @return (Action) An Action object populated with all related actions.
function EatFoodTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  1. findFood
    --  Condition: We are hungry but don't have food.
    --  Effect: We have food.
    -----------------------------------------------------------------
    actions:add_condition('findFood', {
        hungry = true,
        hasFood = false,
    })
    actions:add_reaction('findFood', {
        hasFood = true
    })
    actions:set_weight('findFood', 5) -- Searching takes time

    -----------------------------------------------------------------
    --  2. eatFood
    --  Condition: We are hungry and have food.
    --  Effect: We are no longer hungry, and the food is consumed.
    -----------------------------------------------------------------
    actions:add_condition('eatFood', {
        hungry = true,
        hasFood = true,
    })
    actions:add_reaction('eatFood', {
        hungry = false,
        hasFood = false -- Consumed
    })
    actions:set_weight('eatFood', 1) -- Eating is quick

    return actions
end

return EatFoodTask