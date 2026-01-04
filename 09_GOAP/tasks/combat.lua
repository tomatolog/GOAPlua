-- File: goap/tasks/combat.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for combat tasks:
--  1. Equipping weapons
--  2. Pursuing targets (moving into range/visibility)
--  3. Engaging targets (attacking)
-- --------------------------------------------------------------
local Action = require("09_GOAP/Action")

local CombatTask = {}

-- Factory function to create combat actions.
-- @return (Action) An Action object populated with combat actions.
function CombatTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  Preparation
    -----------------------------------------------------------------

    -- 1. equipWeapon
    --    Condition: We have a weapon but are unarmed.
    --    Effect: We are armed.
    actions:add_condition('equipWeapon', {
        hasWeapon = true,
        armed = false,
    })
    actions:add_reaction('equipWeapon', {
        armed = true
    })
    actions:set_weight('equipWeapon', 1) -- Quick action

    -- 2. findWeapon
    --    Condition: We need to fight but have no weapon.
    --    Effect: We have a weapon.
    actions:add_condition('findWeapon', {
        hasWeapon = false,
    })
    actions:add_reaction('findWeapon', {
        hasWeapon = true
    })
    actions:set_weight('findWeapon', 5)

    -----------------------------------------------------------------
    --  Engagement Cycle
    -----------------------------------------------------------------

    -- 3. pursueTarget
    --    Condition: We know a threat exists but can't see it / out of range.
    --    Effect: Threat is visible / in range.
    actions:add_condition('pursueTarget', {
        threatKnown = true,
        threatVisible = false,
    })
    actions:add_reaction('pursueTarget', {
        threatVisible = true
    })
    actions:set_weight('pursueTarget', 5) -- Moving to target

    -- 4. engageThreat
    --    Condition: Threat is visible/in range. Preferably armed.
    --    Effect: Threat is eliminated.
    actions:add_condition('engageThreat', {
        threatVisible = true,
        armed = true, -- Strong preference for being armed
    })
    actions:add_reaction('engageThreat', {
        threatEliminated = true,
        threatKnown = false, -- Threat is gone
        threatVisible = false
    })
    actions:set_weight('engageThreat', 20) -- Fighting is risky/costly

    -- 4b. engageThreatUnarmed
    --    Fallback: Attack without weapon if necessary
    actions:add_condition('engageThreatUnarmed', {
        threatVisible = true,
        armed = false,
        hasWeapon = false, -- Only if we really don't have one
    })
    actions:add_reaction('engageThreatUnarmed', {
        threatEliminated = true,
        threatKnown = false,
        threatVisible = false
    })
    actions:set_weight('engageThreatUnarmed', 50) -- Very risky/undesirable

    return actions
end

return CombatTask