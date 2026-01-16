-- File: specs/task_find_item_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with FindItemTask actions.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local FindItemTask = require("09_GOAP/tasks/find_item")

describe("Planner with Find Item Task", function()

  -- Helper to set up the world
  local function setup_find_item_world()
    local world = Planner(
        "hasItem", "hasTarget", "atTarget"
    )
    -- Default Start: Don't have it, don't know where it is
    world:set_start_state{
        hasItem = false,
        hasTarget = false,
        atTarget = false,
    }
    -- Goal: Have the item
    world:set_goal_state{
        hasItem = true,
    }
    return world, FindItemTask.create_actions()
  end

  -----------------------------------------------------------------
  -- Test 1: Full Sequence (Scan -> Walk -> Pickup)
  -----------------------------------------------------------------
  it("should find a plan to scan, walk to, and pickup an item", function()
    local planner, actions = setup_find_item_world()
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = {
      "scanForItem",
      "walkToTarget",
      "pickupItem",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)
    
    -- Cost: Scan(5) + Walk(2) + Pickup(2) = 9
    assert.are.equal(9, plan[#plan].g)
  end)

  -----------------------------------------------------------------
  -- Test 2: Already know target (Walk -> Pickup)
  -----------------------------------------------------------------
  it("should skip scan if target is already known", function()
    local planner, actions = setup_find_item_world()
    
    planner:set_start_state{
        hasItem = false,
        hasTarget = true, -- We already found it (e.g. from previous tick)
        atTarget = false
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")
    
    local plan = planner:calculate()
    
    assert.is_not_nil(plan)
    local expected_sequence = {
      "walkToTarget",
      "pickupItem",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    
    assert.are.same(expected_sequence, actual_sequence)
    
    -- Cost: Walk(2) + Pickup(2) = 4
    assert.are.equal(4, plan[#plan].g)
  end)

  -----------------------------------------------------------------
  -- Test 3: Already at target (Pickup only)
  -----------------------------------------------------------------
  it("should just pickup if already at target", function()
    local planner, actions = setup_find_item_world()
    
    planner:set_start_state{
        hasItem = false,
        hasTarget = true,
        atTarget = true
    }
    planner:set_action_list(actions)
    
    local plan = planner:calculate()
    
    assert.is_not_nil(plan)
    local expected_sequence = {
      "pickupItem",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    
    assert.are.same(expected_sequence, actual_sequence)
    
    -- Cost: Pickup(2)
    assert.are.equal(2, plan[#plan].g)
  end)

end)
