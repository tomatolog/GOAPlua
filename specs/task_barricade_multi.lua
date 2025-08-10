-- File: specs/barricade_multi_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner using the reusable
--  barricade task module.
-- ------------------------------------------------------------------

local Planner = require("goap.Planner")
local BarricadeTask = require("goap.tasks.barricade") -- Import the reusable task actions

describe("Planner with Barricade Multi-Window Task", function()

  -- Helper function to set up the world using the barricade task module.
  local function setup_barricade_world(num_windows)
    -- World definition
    local world = Planner(
        "hasHammer", "hasPlank", "hasNails", "atBuilding",
        "windowsRemaining", "hasTarget", "nearWindow", "equipped"
    )

    -- Start and goal states
    world:set_start_state{
        hasHammer        = false,
        hasPlank         = false,
        hasNails         = false,
        atBuilding       = true,
        windowsRemaining = num_windows,
        hasTarget        = false,
        nearWindow       = false,
        equipped         = false,
    }
    world:set_goal_state{
        windowsRemaining = 0,
    }

    -- Get the actions from our reusable task module
    local actions = BarricadeTask.create_actions(num_windows)

    -- Return the planner and the actions object for manipulation in tests
    return world, actions
  end

  it("should find the correct plan for 3 windows", function()
    local MAX_WINDOWS = 3
    local planner, actions = setup_barricade_world(MAX_WINDOWS)
    planner:set_action_list(actions)

    local plan = planner:calculate()

    -- Assert that a valid plan was found
    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Assert the exact sequence of actions
    local expected_sequence = {
      "ensureResources",
      "findWindow3", "walkToWindow", "equipTools", "barricadeWindow3",
      "findWindow2", "walkToWindow", "barricadeWindow2",
      "findWindow1", "walkToWindow", "barricadeWindow1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Assert the total cost of the plan
    -- 1 + (2+2+1+5) + (2+2+5) + (2+2+5) = 29
    local expected_cost = 29
    assert.are.equal(expected_cost, plan[#plan].g)

    -- Assert that the goal state is met
    assert.are.equal(0, plan[#plan].state.windowsRemaining)
  end)

  it("should find the correct plan for 1 window", function()
    local MAX_WINDOWS = 1
    local planner, actions = setup_barricade_world(MAX_WINDOWS)
    planner:set_action_list(actions)

    local plan = planner:calculate()

    assert.is_not_nil(plan)

    local expected_sequence = {
      "ensureResources",
      "findWindow1",
      "walkToWindow",
      "equipTools",
      "barricadeWindow1",
    }
    assert.are.equal(#expected_sequence, #plan)
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- 1 + 2 + 2 + 1 + 5 = 11
    local expected_cost = 11
    assert.are.equal(expected_cost, plan[#plan].g)
    assert.are.equal(0, plan[#plan].state.windowsRemaining)
  end)

  it("should find no plan if resources cannot be acquired", function()
    local MAX_WINDOWS = 2
    local planner, actions = setup_barricade_world(MAX_WINDOWS)

    -- Sabotage the plan by removing the action to get resources.
    -- This tests our ability to manipulate the generated action set.
    actions.conditions.ensureResources = nil
    actions.reactions.ensureResources = nil
    actions.weights.ensureResources = nil

    planner:set_action_list(actions)
    local plan = planner:calculate()

    -- The planner should return an empty table to indicate no plan was found.
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan)
  end)

end)