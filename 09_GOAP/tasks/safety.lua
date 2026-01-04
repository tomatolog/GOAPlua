-- File: goap/tasks/safety.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for safety tasks:
--  1. Fleeing from danger
--  Converted from FleeTask.lua logic.
-- --------------------------------------------------------------
local Action = require("09_GOAP/Action")

local SafetyTask = {}

-- Factory function to create safety actions.
-- @return (Action) An Action object populated with safety actions.
function SafetyTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  Safety Actions
    -----------------------------------------------------------------

    -- 1. fleeDanger
    --    Condition: Danger is visible/detected.
    --    Effect: We are safe, and the danger is no longer visible (we outran it).
    --    Note: In GOAP, this has a very low cost to ensure it is prioritized 
    --    when safety is required.
    actions:add_condition('fleeDanger', {
        dangerVisible = true,
    })
    actions:add_reaction('fleeDanger', {
        isSafe = true,
        dangerVisible = false
    })
    actions:set_weight('fleeDanger', 1) -- Immediate priority

    return actions
end

return SafetyTask