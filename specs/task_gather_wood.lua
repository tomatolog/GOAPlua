-- File: specs/gather_wood_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner using the reusable
--  gather wood task module.
-- ------------------------------------------------------------------

local Planner = require("Planner")
local GatherWoodTask = require("tasks.gather_wood") -- Import the new task actions

describe("Planner with Gather Wood Task", function()

  -- Helper function to set up the world using the gather wood task module.
  local function setup_gather_wood_world(wood_to_gather)
    -- World definition
    local world = Planner(
        "woodNeeded", "hasWoodTarget", "atWoodTarget", "carryingWood", "atDropoff"
    )

    -- Start and goal states
    world:set_start_state{
        woodNeeded = wood_to_gather,
        hasWoodTarget = false,
        atWoodTarget = false,
        carryingWood = false,
        atDropoff = false,
    }
    world:set_goal_state{
        woodNeeded = 0,
    }

    -- Get the actions from our reusable task module
    local actions = GatherWoodTask.create_actions(wood_to_gather)

    -- Return the planner and the actions object for manipulation in tests
    return world, actions
  end

  it("should find the correct plan for gathering 2 pieces of wood", function()
    local WOOD_TO_GATHER = 2
    local planner, actions = setup_gather_wood_world(WOOD_TO_GATHER)
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add") -- Use a good heuristic for testing

    local plan = planner:calculate()

    -- Assert that a valid plan was found
    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Assert the exact sequence of actions for gathering two pieces
    local expected_sequence = {
      "findWood2", "walkToWood2", "pickupWood2", "walkToDropoff", "dropWood2",
      "findWood1", "walkToWood1", "pickupWood1", "walkToDropoff", "dropWood1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Assert the total cost of the plan
    -- Cost for one loop: find(4) + walkTo(3) + pickup(1) + walkTo(3) + drop(1) = 12
    -- Total cost for two loops: 12 * 2 = 24
    local expected_cost = 24
    assert.are.equal(expected_cost, plan[#plan].g)

    -- Assert that the goal state is met
    assert.are.equal(0, plan[#plan].state.woodNeeded)
  end)

  it("should find a shorter plan if starting while carrying wood", function()
    local WOOD_TO_GATHER = 1
    local planner, actions = setup_gather_wood_world(WOOD_TO_GATHER)

    -- Modify the start state to be more advanced
    planner:set_start_state{
        woodNeeded = 1,
        hasWoodTarget = false,
        atWoodTarget = false,
        carryingWood = true, -- Start by already carrying a log
        atDropoff = false,
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)

    -- The plan should skip finding and picking up wood
    local expected_sequence = {
      "walkToDropoff",
      "dropWood1",
    }
    assert.are.equal(#expected_sequence, #plan)

    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: walkTo(3) + drop(1) = 4
    local expected_cost = 4
    assert.are.equal(expected_cost, plan[#plan].g)
    assert.are.equal(0, plan[#plan].state.woodNeeded)
  end)


  it("should find no plan if finding wood is impossible", function()
    local WOOD_TO_GATHER = 1
    local planner, actions = setup_gather_wood_world(WOOD_TO_GATHER)

    -- Sabotage the plan by removing the ability to find wood.
    -- This simulates a scenario where there are no logs on the ground.
    actions.conditions.findWood1 = nil
    actions.reactions.findWood1 = nil
    actions.weights.findWood1 = nil

    planner:set_action_list(actions)
    local plan = planner:calculate()

    -- The planner should return an empty table to indicate no plan was found.
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan)
  end)

end)