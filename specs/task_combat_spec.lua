-- File: specs/task_combat_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with CombatTask actions.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local CombatTask = require("09_GOAP/tasks.combat")

describe("Planner with Combat Task", function()

  -- Helper to set up the world
  local function setup_combat_world()
    local world = Planner(
        "hasWeapon", "armed", "threatKnown", "threatVisible", "threatEliminated"
    )
    return world, CombatTask.create_actions()
  end

  -----------------------------------------------------------------
  -- Test 1: Full Engagement (Equip -> Pursue -> Attack)
  -----------------------------------------------------------------
  it("should find a plan to equip weapon, pursue, and eliminate threat", function()
    local planner, actions = setup_combat_world()
    
    planner:set_start_state{
        hasWeapon = true,
        armed = false,
        threatKnown = true,
        threatVisible = false,
        threatEliminated = false
    }
    
    planner:set_goal_state{
        threatEliminated = true,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Expected flow:
    -- 1. equipWeapon (Cost 1) - because engageThreat prefers armed
    -- 2. pursueTarget (Cost 5)
    -- 3. engageThreat (Cost 20)
    
    local names = {}
    for _, node in ipairs(plan) do
      table.insert(names, node.name)
    end
    
    -- Check sequence
    local hasEquip = false
    local hasPursue = false
    local hasEngage = false
    
    for _, name in ipairs(names) do
        if name == "equipWeapon" then hasEquip = true end
        if name == "pursueTarget" then hasPursue = true end
        if name == "engageThreat" then hasEngage = true end
    end
    
    assert.is_true(hasEquip, "Should equip weapon")
    assert.is_true(hasPursue, "Should pursue target")
    assert.is_true(hasEngage, "Should engage threat")
    
    -- Cost: 1 + 5 + 20 = 26
    assert.are.equal(26, plan[#plan].g)
  end)

  -----------------------------------------------------------------
  -- Test 2: Unarmed desperation
  -----------------------------------------------------------------
  it("should fight unarmed if no weapon available", function()
    local planner, actions = setup_combat_world()
    
    planner:set_start_state{
        hasWeapon = false,
        armed = false,
        threatKnown = true,
        threatVisible = true, -- Already close
        threatEliminated = false
    }
    
    planner:set_goal_state{
        threatEliminated = true,
    }
    
    planner:set_action_list(actions)
    
    -- Remove the 'findWeapon' action to simulate no weapons available in world
    actions.conditions.findWeapon = nil
    actions.reactions.findWeapon = nil
    actions.weights.findWeapon = nil

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    
    -- Should choose engageThreatUnarmed (Cost 50)
    assert.are.equal("engageThreatUnarmed", plan[#plan].name)
    assert.are.equal(50, plan[#plan].g)
  end)

end)