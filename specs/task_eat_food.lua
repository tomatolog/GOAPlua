-- File: specs/task_eat_food.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with EatFoodTask actions.
-- ------------------------------------------------------------------

local Planner = require("goap.Planner")
local EatFoodTask = require("goap.tasks.eat_food")

describe("Planner with Eat Food Task", function()

  -- Helper to set up the world
  local function setup_eat_food_world()
    local world = Planner(
        "hungry", "hasFood"
    )

    -- Start: Hungry and no food
    world:set_start_state{
        hungry = true,
        hasFood = false,
    }
    -- Goal: Not hungry
    world:set_goal_state{
        hungry = false,
    }

    local actions = EatFoodTask.create_actions()
    return world, actions
  end

  it("should find a plan to find and eat food", function()
    local planner, actions = setup_eat_food_world()
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = {
      "findFood",
      "eatFood",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: findFood(5) + eatFood(1) = 6
    local expected_cost = 6
    assert.are.equal(expected_cost, plan[#plan].g)
    
    -- Goal state check
    assert.is_false(plan[#plan].state.hungry)
  end)

  it("should just eat if already has food", function()
    local planner, actions = setup_eat_food_world()
    
    -- Start: Hungry but HAS food
    planner:set_start_state{
        hungry = true,
        hasFood = true,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    
    local expected_sequence = {
      "eatFood",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: eatFood(1)
    local expected_cost = 1
    assert.are.equal(expected_cost, plan[#plan].g)
  end)

end)