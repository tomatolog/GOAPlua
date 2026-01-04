-- File: specs/task_corpse_management_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with CorpseManagementTask actions.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local CorpseTask = require("09_GOAP/tasks.corpse_management")

describe("Planner with Corpse Management Task", function()

  -- Helper to set up the world
  local function setup_corpse_world(count)
    local world = Planner(
        "corpsesRemaining", "carryingCorpse", "hasCorpseTarget", "nearCorpse", "atCorpsePile"
    )
    return world, CorpseTask.create_actions(count)
  end

  -----------------------------------------------------------------
  -- Test 1: Clean Single Corpse
  -----------------------------------------------------------------
  it("should find a plan to pile one corpse", function()
    local planner, actions = setup_corpse_world(1)
    
    planner:set_start_state{
        corpsesRemaining = 1,
        carryingCorpse = false,
        hasCorpseTarget = false,
        nearCorpse = false,
        atCorpsePile = false
    }
    
    planner:set_goal_state{
        corpsesRemaining = 0,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = {
      "locateCorpse1",
      "walkToCorpse1",
      "pickupCorpse1",
      "walkToPile",
      "dropCorpse1"
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: Locate(2) + WalkTo(3) + Pick(5) + WalkPile(5) + Drop(1) = 16
    assert.are.equal(16, plan[#plan].g)
  end)

  -----------------------------------------------------------------
  -- Test 2: Clean Multiple Corpses
  -----------------------------------------------------------------
  it("should find a plan to pile multiple corpses", function()
    local planner, actions = setup_corpse_world(2)
    
    planner:set_start_state{
        corpsesRemaining = 2,
        carryingCorpse = false,
        hasCorpseTarget = false,
        nearCorpse = false,
        atCorpsePile = false
    }
    
    planner:set_goal_state{
        corpsesRemaining = 0,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    
    -- Verify we have two full cycles
    local pickup_count = 0
    local drop_count = 0
    for _, node in ipairs(plan) do
        if node.name:match("pickupCorpse") then pickup_count = pickup_count + 1 end
        if node.name:match("dropCorpse") then drop_count = drop_count + 1 end
    end
    
    assert.are.equal(2, pickup_count)
    assert.are.equal(2, drop_count)
    assert.are.equal(0, plan[#plan].state.corpsesRemaining)
  end)

end)