-- File: specs/task_medical_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with MedicalTask actions.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local MedicalTask = require("09_GOAP/tasks.medical")

describe("Planner with Medical Task", function()

  -- Helper to set up the world
  local function setup_medical_world()
    local world = Planner(
        "isBleeding", "hasBandage", "hasGlass",
        "nearPatient", "patientInjured", "hasMedicalSupply", "knowsPatientLocation"
    )
    return world, MedicalTask.create_actions()
  end

  -----------------------------------------------------------------
  -- Test 1: Self-Care (Bandaging)
  -----------------------------------------------------------------
  it("should find a plan to bandage self when bleeding", function()
    local planner, actions = setup_medical_world()
    
    planner:set_start_state{
        isBleeding = true,
        hasBandage = false,
        hasGlass = false,
        nearPatient = false,
        patientInjured = false,
        hasMedicalSupply = false,
        knowsPatientLocation = false
    }
    planner:set_goal_state{
        isBleeding = false,
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = {
      "findBandage",
      "applyBandageSelf",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)
    
    -- Cost: 5 + 10 = 15
    assert.are.equal(15, plan[#plan].g)
  end)

  -----------------------------------------------------------------
  -- Test 2: Self-Care (Remove Glass)
  -----------------------------------------------------------------
  it("should find a plan to remove glass", function()
    local planner, actions = setup_medical_world()
    
    planner:set_start_state{
        hasGlass = true,
        isBleeding = false, -- Simplified for this test
    }
    planner:set_goal_state{
        hasGlass = false,
    }
    planner:set_action_list(actions)

    local plan = planner:calculate()
    assert.is_not_nil(plan)
    assert.are.equal(1, #plan)
    assert.are.equal("removeGlassSelf", plan[1].name)
  end)

  -----------------------------------------------------------------
  -- Test 3: Doctor (Treat Patient)
  -----------------------------------------------------------------
  it("should find a plan to go to and treat a patient", function()
    local planner, actions = setup_medical_world()
    
    planner:set_start_state{
        knowsPatientLocation = true,
        nearPatient = false,
        patientInjured = true,
        hasMedicalSupply = false,
        -- Self state
        isBleeding = false,
        hasBandage = false,
        hasGlass = false
    }
    planner:set_goal_state{
        patientInjured = false,
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Order might vary slightly for independent branches (findSupply vs goToPatient), 
    -- but usually planner picks cheapest heuristic path first.
    -- findSupply(5) vs goToPatient(5).
    -- Both are needed for treatPatient.
    
    local found_go = false
    local found_find = false
    local found_treat = false
    
    for _, node in ipairs(plan) do
        if node.name == "goToPatient" then found_go = true end
        if node.name == "findMedicalSupply" then found_find = true end
        if node.name == "treatPatient" then found_treat = true end
    end
    
    assert.is_true(found_go, "Should go to patient")
    assert.is_true(found_find, "Should find supplies")
    assert.is_true(found_treat, "Should treat patient")
    assert.are.equal("treatPatient", plan[#plan].name) -- Last action must be treatment

    -- Cost: 5 + 5 + 10 = 20
    assert.are.equal(20, plan[#plan].g)
  end)

end)