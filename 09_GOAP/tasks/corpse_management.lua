-- File: goap/tasks/corpse_management.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for the "pile corpses" task.
--  Converted from PileCorpsesTask.lua logic.
-- --------------------------------------------------------------
local Action = require("09_GOAP/Action")

local CorpseManagementTask = {}

-- Factory function to create the actions for corpse management.
-- @param corpses_to_pile (integer) Number of corpses to clean up (optional, defaults to 1 for infinite loops)
-- @return (Action) An Action object populated with all related actions.
function CorpseManagementTask.create_actions(corpses_to_pile)
    local actions = Action()
    
    -- If a specific count isn't needed for the logic, we can just model the cycle.
    -- But to satisfy a planner goal like "areaClean", we might iterate or just use boolean flags.
    -- Let's support a count to allow "clean up 3 bodies" scenarios.
    
    if not corpses_to_pile or corpses_to_pile < 1 then corpses_to_pile = 1 end

    for i = corpses_to_pile, 1, -1 do
        -- 1. locateCorpse<N>
        --    Condition: We need to clean up, aren't carrying one, and don't see one yet.
        --    Effect: We have a target corpse.
        local loc_name = "locateCorpse" .. i
        actions:add_condition(loc_name, {
            corpsesRemaining = i,
            carryingCorpse = false,
            hasCorpseTarget = false,
        })
        actions:add_reaction(loc_name, {
            hasCorpseTarget = true
        })
        actions:set_weight(loc_name, 2)

        -- 2. walkToCorpse<N>
        --    Condition: We have a target.
        --    Effect: We are near it.
        local walk_name = "walkToCorpse" .. i
        actions:add_condition(walk_name, {
            hasCorpseTarget = true,
            nearCorpse = false,
            corpsesRemaining = i
        })
        actions:add_reaction(walk_name, {
            nearCorpse = true
        })
        actions:set_weight(walk_name, 3)

        -- 3. pickupCorpse<N>
        --    Condition: Near corpse, hands empty (implied by not carrying).
        --    Effect: Carrying corpse.
        local pick_name = "pickupCorpse" .. i
        actions:add_condition(pick_name, {
            nearCorpse = true,
            carryingCorpse = false,
            corpsesRemaining = i
        })
        actions:add_reaction(pick_name, {
            carryingCorpse = true,
            nearCorpse = false,
            hasCorpseTarget = false, -- Target is now in hand
        })
        actions:set_weight(pick_name, 5) -- Heavy lifting

        -- 4. dropCorpse<N>
        --    Condition: Carrying corpse, at pile location.
        --    Effect: Corpse dropped, remaining count decreases.
        local drop_name = "dropCorpse" .. i
        actions:add_condition(drop_name, {
            carryingCorpse = true,
            atCorpsePile = true,
            corpsesRemaining = i
        })
        actions:add_reaction(drop_name, {
            carryingCorpse = false,
            corpsesRemaining = i - 1,
            atCorpsePile = false -- Reset pos for next run
        })
        actions:set_weight(drop_name, 1)
    end

    -- 5. walkToPile
    --    Condition: Carrying corpse, not at pile.
    --    Effect: At pile.
    --    (Generic action shared across iterations)
    actions:add_condition('walkToPile', {
        carryingCorpse = true,
        atCorpsePile = false,
    })
    actions:add_reaction('walkToPile', {
        atCorpsePile = true
    })
    actions:set_weight('walkToPile', 5) -- Walking with load

    return actions
end

return CorpseManagementTask