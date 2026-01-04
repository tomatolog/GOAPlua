-- File: goap/tasks/medical.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for medical tasks:
--  1. Self-care (First Aid)
--  2. Doctor (Treating others)
-- --------------------------------------------------------------
local Action = require("09_GOAP/Action")

local MedicalTask = {}

-- Factory function to create medical actions.
-- @return (Action) An Action object populated with medical actions.
function MedicalTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  SELF-CARE (First Aid)
    -----------------------------------------------------------------

    -- 1. findBandage
    --    Condition: We are bleeding but have no bandage.
    --    Effect: We obtain a bandage (e.g. Ripped Sheets).
    actions:add_condition('findBandage', {
        hasBandage = false,
        isBleeding = true, -- Only look for one if we need it (optional optimization)
    })
    actions:add_reaction('findBandage', {
        hasBandage = true
    })
    actions:set_weight('findBandage', 5) -- Searching takes time

    -- 2. applyBandageSelf
    --    Condition: We are bleeding and have a bandage.
    --    Effect: Bleeding stops, bandage is used.
    actions:add_condition('applyBandageSelf', {
        isBleeding = true,
        hasBandage = true,
    })
    actions:add_reaction('applyBandageSelf', {
        isBleeding = false,
        hasBandage = false -- Consumed
    })
    actions:set_weight('applyBandageSelf', 10) -- Bandaging takes time

    -- 3. removeGlassSelf
    --    Condition: We have glass embedded (e.g. from broken window).
    --    Effect: Glass is removed (pre-requisite for bandaging usually, but modeled simply here).
    actions:add_condition('removeGlassSelf', {
        hasGlass = true,
    })
    actions:add_reaction('removeGlassSelf', {
        hasGlass = false
    })
    actions:set_weight('removeGlassSelf', 15) -- Painful and slow

    -----------------------------------------------------------------
    --  DOCTOR (Treating Others)
    -----------------------------------------------------------------

    -- 4. goToPatient
    --    Condition: We know where a patient is but aren't near them.
    --    Effect: We are near the patient.
    actions:add_condition('goToPatient', {
        knowsPatientLocation = true,
        nearPatient = false,
    })
    actions:add_reaction('goToPatient', {
        nearPatient = true
    })
    actions:set_weight('goToPatient', 5) -- Travel cost

    -- 5. treatPatient
    --    Condition: We are near the patient, they are injured, and we have supplies.
    --    Effect: Patient is cured (abstracted).
    actions:add_condition('treatPatient', {
        nearPatient = true,
        patientInjured = true,
        hasMedicalSupply = true,
    })
    actions:add_reaction('treatPatient', {
        patientInjured = false,
        hasMedicalSupply = false -- Consumed
    })
    actions:set_weight('treatPatient', 10)

    -- 6. findMedicalSupply (General)
    --    Condition: We need supplies to treat a patient.
    --    Effect: We have supplies.
    actions:add_condition('findMedicalSupply', {
        patientInjured = true,
        hasMedicalSupply = false,
    })
    actions:add_reaction('findMedicalSupply', {
        hasMedicalSupply = true
    })
    actions:set_weight('findMedicalSupply', 5)

    return actions
end

return MedicalTask