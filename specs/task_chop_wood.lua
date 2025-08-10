-- File: specs/chop_wood_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner using the reusable
--  chop wood task module.
-- ------------------------------------------------------------------

local Planner = require("goap.Planner")
local ChopWoodTask = require("goap.tasks.chop_wood") -- Import the new task actions

describe("Planner with Chop Wood Task", function()

  -- Helper function to set up the world for the chop wood task.
  local function setup_chop_wood_world(logs_to_create)
    -- World definition
    local world = Planner(
        "logsNeeded", "hasAxe", "axeEquipped", "hasTreeTarget", "atTree", "hasStamina"
    )

    -- Start and goal states
    world:set_start_state{
        logsNeeded = logs_to_create,
        hasAxe = false,
        axeEquipped = false,
        hasTreeTarget = false,
        atTree = false,
        hasStamina = true, -- Start with full stamina
    }
    world:set_goal_state{
        logsNeeded = 0,
    }

    -- Get actions from our reusable task module
    -- For testing, we simplify the condition on `findAxe` and `restToRegainStamina`
    -- to use an exact match, since the core GOAP engine doesn't support operators yet.
    local actions = ChopWoodTask.create_actions(logs_to_create)
    if actions.conditions.findAxe then
      actions.conditions.findAxe.logsNeeded = logs_to_create
    end
    if actions.conditions.restToRegainStamina then
      actions.conditions.restToRegainStamina.logsNeeded = logs_to_create
    end


    return world, actions
  end

  it("should find the correct plan for creating 1 log", function()
    local LOGS_TO_CREATE = 1
    local planner, actions = setup_chop_wood_world(LOGS_TO_CREATE)
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Assert the exact sequence of actions
    local expected_sequence = {
      "findAxe",
      "equipAxe",
      "findTree1",
      "walkToTree1",
      "chopTree1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Assert the total cost of the plan
    -- findAxe(10) + equipAxe(1) + findTree(4) + walkToTree(3) + chopTree(8) = 26
    local expected_cost = 26
    assert.are.equal(expected_cost, plan[#plan].g)
    assert.are.equal(0, plan[#plan].state.logsNeeded)
  end)

  it("should create a plan that includes resting if starting with no stamina", function()
    local LOGS_TO_CREATE = 1
    local planner, actions = setup_chop_wood_world(LOGS_TO_CREATE)
    
    -- Modify the start state
    planner:set_start_state{
        logsNeeded = 1,
        hasAxe = true,       -- We already have an axe...
        axeEquipped = true,  -- ...and it's equipped...
        hasTreeTarget = false,
        atTree = false,
        hasStamina = false,  -- ...but we are tired.
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)

    local expected_sequence = {
      "restToRegainStamina",
      "findTree1",
      "walkToTree1",
      "chopTree1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: rest(5) + findTree(4) + walkToTree(3) + chopTree(8) = 20
    local expected_cost = 20
    assert.are.equal(expected_cost, plan[#plan].g)
  end)
  
  it("should find no plan if an axe cannot be found", function()
    local LOGS_TO_CREATE = 1
    local planner, actions = setup_chop_wood_world(LOGS_TO_CREATE)

    -- Sabotage the plan by removing the ability to find an axe
    actions.conditions.findAxe = nil
    actions.reactions.findAxe = nil
    actions.weights.findAxe = nil
    
    planner:set_action_list(actions)
    local plan = planner:calculate()
    
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan)
  end)

end)