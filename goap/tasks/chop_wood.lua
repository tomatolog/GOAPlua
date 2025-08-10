-- File: tasks/chop_wood.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for the "chop wood" task,
--  which involves getting an axe, finding a tree, and felling it.
--  Converted from the original ChopWoodTask.lua logic.
-- --------------------------------------------------------------
local Action = require("goap.Action")

local ChopWoodTask = {}

-- Factory function to create the actions for the chop wood task.
-- @param logs_to_create (integer) The number of logs to create.
-- @return (Action) An Action object populated with all related actions.
function ChopWoodTask.create_actions(logs_to_create)
    assert(type(logs_to_create) == "number" and logs_to_create > 0, "logs_to_create must be a positive integer")

    local actions = Action()

    -----------------------------------------------------------------
    --  1. findAxe
    --  Original Logic: Searching inventory/bags, or triggering FindThisTask.
    --  Condition: We need logs but don't have an axe.
    --  Effect: We now possess an axe (in our inventory).
    -----------------------------------------------------------------
    actions:add_condition('findAxe', {
        logsNeeded = { greater_than_or_equal = 1 }, -- A way to say "we need at least one"
        hasAxe = false,
    })
    actions:add_reaction('findAxe', {
        hasAxe = true
    })
    actions:set_weight('findAxe', 10) -- Finding a specific tool can be a very long task

    -----------------------------------------------------------------
    --  2. equipAxe
    --  Original Logic: player:setPrimaryHandItem(self.Axe)
    --  Condition: We have an axe in inventory but it's not equipped.
    --  Effect: The axe is now equipped.
    -----------------------------------------------------------------
    actions:add_condition('equipAxe', {
        hasAxe = true,
        axeEquipped = false,
    })
    actions:add_reaction('equipAxe', {
        axeEquipped = true
    })
    actions:set_weight('equipAxe', 1) -- Quick action

    -----------------------------------------------------------------
    --  3. restToRegainStamina
    --  Original Logic: if(player:getStats():getEndurance() < 0.50) then ...
    --  Condition: We need to do work but have no stamina.
    --  Effect: We now have stamina.
    -----------------------------------------------------------------
    actions:add_condition('restToRegainStamina', {
        logsNeeded = { greater_than_or_equal = 1 },
        hasStamina = false
    })
    actions:add_reaction('restToRegainStamina', {
        hasStamina = true
    })
    actions:set_weight('restToRegainStamina', 5) -- Resting takes time

    -- This loop creates actions for each log we want to produce.
    -- This handles the case where multiple trees need to be chopped.
    for i = logs_to_create, 1, -1 do
        -----------------------------------------------------------------
        --  4. findTree<N>
        --  Original Logic: The large loop that scans for "tree" objects.
        --  Condition: We are ready to work but don't have a target.
        --  Effect: We now have a target tree.
        -----------------------------------------------------------------
        local find_name = "findTree" .. i
        actions:add_condition(find_name, {
            logsNeeded = i,
            axeEquipped = true,
            hasStamina = true,
            hasTreeTarget = false,
        })
        actions:add_reaction(find_name, {
            hasTreeTarget = true
        })
        actions:set_weight(find_name, 4) -- Searching an area has a cost

        -----------------------------------------------------------------
        --  5. walkToTree<N>
        --  Original Logic: self.parent:walkTo(self.Tree:getSquare())
        --  Condition: We have a tree target but are not at it.
        --  Effect: We are now at the tree.
        -----------------------------------------------------------------
        local walk_to_name = "walkToTree" .. i
        actions:add_condition(walk_to_name, {
            hasTreeTarget = true,
            atTree = false
        })
        actions:add_reaction(walk_to_name, {
            atTree = true
        })
        actions:set_weight(walk_to_name, 3) -- Walking cost

        -----------------------------------------------------------------
        --  6. chopTree<N>
        --  Original Logic: ISTimedActionQueue.add(ISChopTreeAction:new(player, self.Tree))
        --  Condition: We are at a tree, ready to work.
        --  Effect: A log is created (counter decrements), and stamina is lost.
        -----------------------------------------------------------------
        local chop_name = "chopTree" .. i
        actions:add_condition(chop_name, {
            logsNeeded = i,
            axeEquipped = true,
            hasStamina = true,
            hasTreeTarget = true,
            atTree = true,
        })
        actions:add_reaction(chop_name, {
            logsNeeded = i - 1,
            hasTreeTarget = false, -- We need to find a new tree
            atTree = false,
            hasStamina = false, -- Chopping is tiring, must rest again
        })
        actions:set_weight(chop_name, 8) -- Chopping is a long, costly action
    end

    return actions
end

return ChopWoodTask