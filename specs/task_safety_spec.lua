-- File: specs/task_safety_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with SafetyTask actions.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local SafetyTask = require("09_GOAP/tasks.safety")

describe("Planner with Safety Task", function()

  -- Helper to set up the world
  local function setup_safety_world()
    local world = Planner(
        "dangerVisible", "isSafe"
    )
    return world, SafetyTask.create_actions()
  end

  -----------------------------------------------------------------
  -- Test 1: Fleeing to Safety
  -----------------------------------------------------------------
  it("should find a plan to flee when danger is visible", function()
    local planner, actions = setup_safety_world()
    
    planner:set_start_state{
        dangerVisible = true,
        isSafe = false
    }
    
    planner:set_goal_state{
        isSafe = true,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    assert.are.equal("fleeDanger", plan[1].name)
    assert.are.equal(1, plan[1].g)
    assert.is_true(plan[1].state.isSafe)
    assert.is_false(plan[1].state.dangerVisible)
  end)

end)