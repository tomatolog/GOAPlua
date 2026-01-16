-- File: tasks/find_item.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for finding a specific item.
--  This is a generic task that involves:
--  1. Scanning for the item (Container or Ground)
--  2. Moving to the item's location
--  3. Picking up or transferring the item
-- --------------------------------------------------------------
local Action = require("09_GOAP/Action")

local FindItemTask = {}

-- Factory function to create the actions for finding an item.
-- @return (Action) An Action object populated with all related actions.
function FindItemTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  1. scanForItem
    --  Condition: We don't have the item, and we don't know where it is.
    --  Effect: We found a target (Context.TargetItem).
    -----------------------------------------------------------------
    actions:add_condition('scanForItem', {
        hasItem = false,
        hasTarget = false,
    })
    actions:add_reaction('scanForItem', {
        hasTarget = true
    })
    actions:set_weight('scanForItem', 5) -- Scanning takes time/effort

    -----------------------------------------------------------------
    --  2. walkToTarget
    --  Condition: We found it, but aren't near it.
    --  Effect: We are at the location (Context.TargetObject square).
    -----------------------------------------------------------------
    actions:add_condition('walkToTarget', {
        hasTarget = true,
        atTarget = false,
    })
    actions:add_reaction('walkToTarget', {
        atTarget = true
    })
    actions:set_weight('walkToTarget', 2) -- Walking cost

    -----------------------------------------------------------------
    --  3. pickupItem
    --  Condition: We are at the target.
    --  Effect: We have the item.
    --  Note: Resets target states because this specific target is consumed/held.
    -----------------------------------------------------------------
    actions:add_condition('pickupItem', {
        atTarget = true,
        hasItem = false,
    })
    actions:add_reaction('pickupItem', {
        hasItem = true,
        hasTarget = false,
        atTarget = false
    })
    actions:set_weight('pickupItem', 2) -- Action cost (grab/transfer)

    return actions
end

return FindItemTask
