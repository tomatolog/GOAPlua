-- File: tasks/gather_wood.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for the "gather wood" task,
--  which involves finding wood, picking it up, and dropping it
--  at a designated location.
--  Converted from the original GatherWoodTask.lua logic.
-- --------------------------------------------------------------
local Action = require("Action")

local GatherWoodTask = {}

-- Factory function to create the actions for the gather wood task.
-- @param wood_to_gather (integer) The number of logs/planks to gather.
-- @return (Action) An Action object populated with all related actions.
function GatherWoodTask.create_actions(wood_to_gather)
    assert(type(wood_to_gather) == "number" and wood_to_gather > 0, "wood_to_gather must be a positive integer")

    local actions = Action()

    -- This loop creates a set of actions for each piece of wood we need to gather.
    -- The planner will chain these together as needed.
    for i = wood_to_gather, 1, -1 do
        -----------------------------------------------------------------
        --  1. findWood<N>
        --  Original Logic: The large loop that scans for "Log" or "Plank" on the ground.
        --  Condition: We need wood (counter > 0) and aren't carrying any, and don't have a target.
        --  Effect: We now have a target piece of wood.
        -----------------------------------------------------------------
        local find_name = "findWood" .. i
        actions:add_condition(find_name, {
            woodNeeded = i,
            carryingWood = false,
            hasWoodTarget = false,
        })
        actions:add_reaction(find_name, {
            hasWoodTarget = true
        })
        actions:set_weight(find_name, 4) -- Searching an area has a cost

        -----------------------------------------------------------------
        --  2. walkToWood<N>
        --  Original Logic: self.parent:walkTo(self.Target:getSquare())
        --  Condition: We have a wood target but are not at it.
        --  Effect: We are now at the wood target.
        -----------------------------------------------------------------
        local walk_to_name = "walkToWood" .. i
        actions:add_condition(walk_to_name, {
            woodNeeded = i,
            hasWoodTarget = true,
            atWoodTarget = false,
        })
        actions:add_reaction(walk_to_name, {
            atWoodTarget = true
        })
        actions:set_weight(walk_to_name, 3) -- Walking cost

        -----------------------------------------------------------------
        --  3. pickupWood<N>
        --  Original Logic: self.parent.player:getInventory():AddItem(self.Target:getItem())
        --  Condition: We are at a wood target and not carrying anything.
        --  Effect: We are now carrying wood. Resets the target states.
        -----------------------------------------------------------------
        local pickup_name = "pickupWood" .. i
        actions:add_condition(pickup_name, {
            woodNeeded = i,
            hasWoodTarget = true,
            atWoodTarget = true,
            carryingWood = false,
        })
        actions:add_reaction(pickup_name, {
            carryingWood = true,
            hasWoodTarget = false, -- We no longer have a target on the ground
            atWoodTarget = false   -- We are no longer "at" that specific target
        })
        actions:set_weight(pickup_name, 1) -- Quick action

    end -- End of the per-item loop

    -----------------------------------------------------------------
    --  4. walkToDropoff
    --  Original Logic: self.parent:walkTo(self.BringHereSquare)
    --  Condition: We are carrying wood but not at the dropoff point.
    --  Effect: We are now at the dropoff point.
    --  (This action is generic and doesn't need to be in the loop)
    -----------------------------------------------------------------
    actions:add_condition('walkToDropoff', {
        carryingWood = true,
        atDropoff = false
    })
    actions:add_reaction('walkToDropoff', {
        atDropoff = true
    })
    actions:set_weight('walkToDropoff', 3) -- Walking cost

    -----------------------------------------------------------------
    --  5. dropWood
    --  Original Logic: self.BringHereSquare:AddWorldInventoryItem(...)
    --  Condition: We are carrying wood and are at the dropoff point.
    --  Effect: We are no longer carrying wood, and the woodNeeded counter decrements.
    --  (This action is also generic and combines states from the loop)
    -----------------------------------------------------------------
    for i = wood_to_gather, 1, -1 do
        local drop_name = "dropWood" .. i
        actions:add_condition(drop_name, {
            woodNeeded = i,
            carryingWood = true,
            atDropoff = true,
        })
        actions:add_reaction(drop_name, {
            carryingWood = false,
            atDropoff = false, -- We are no longer at the dropoff for the *next* trip
            woodNeeded = i - 1, -- Decrement the main goal counter
        })
        actions:set_weight(drop_name, 1) -- Quick action
    end

    return actions
end

return GatherWoodTask