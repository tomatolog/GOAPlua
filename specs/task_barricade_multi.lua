-- File: specs/barricade_multi_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner using the logic from
--  the example_barricade_multi.lua file. It verifies that the
--  planner can find correct and optimal plans for varying numbers
--  of windows.
-- ------------------------------------------------------------------

local Planner = require("Planner")
local Action  = require("Action")

describe("Planner with Barricade Multi-Window example", function()

  -- Helper function to set up the world based on the example.
  -- It creates a planner instance and a corresponding set of actions
  -- for a given number of windows.
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

    -- Actions
    local actions = Action()

    -- ensureResources – grab hammer, plank and nails if we don’t have them
    actions:add_condition('ensureResources', { hasHammer = false })
    actions:add_reaction ('ensureResources', { hasHammer = true, hasPlank  = true, hasNails  = true })
    actions:set_weight('ensureResources', 1)

    -- findWindow<N> – pick a concrete window when the counter is N
    for i = num_windows, 1, -1 do
        local name = "findWindow" .. i
        actions:add_condition(name, { windowsRemaining = i, hasTarget = false })
        actions:add_reaction(name, { hasTarget = true })
        actions:set_weight(name, 2)
    end

    -- walkToWindow – move next to the current target
    actions:add_condition('walkToWindow', { hasTarget = true, nearWindow = false })
    actions:add_reaction('walkToWindow', { nearWindow = true })
    actions:set_weight('walkToWindow', 2)

    -- equipTools – put hammer in primary hand, plank in secondary
    actions:add_condition('equipTools', {
        hasHammer = true, hasPlank = true, hasNails = true,
        nearWindow = true, equipped = false
    })
    actions:add_reaction('equipTools', { equipped = true })
    actions:set_weight('equipTools', 1)

    -- barricadeWindow<N> – actually barricade the window and decrement the counter
    for i = num_windows, 1, -1 do
        local name = "barricadeWindow" .. i
        actions:add_condition(name, {
            windowsRemaining = i, hasTarget = true, nearWindow = true, equipped = true,
        })
        actions:add_reaction(name, {
            hasTarget        = false,
            nearWindow       = false,
            windowsRemaining = i - 1,
        })
        actions:set_weight(name, 5)
    end

    -- Return the planner and the actions separately for manipulation in tests
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

    -- Assert that a valid plan was found
    assert.is_not_nil(plan)

    -- Assert the exact sequence of actions
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

    -- Assert the total cost of the plan
    -- 1 + 2 + 2 + 1 + 5 = 11
    local expected_cost = 11
    assert.are.equal(expected_cost, plan[#plan].g)

    -- Assert that the goal state is met
    assert.are.equal(0, plan[#plan].state.windowsRemaining)
  end)

  it("should find no plan if resources cannot be acquired", function()
    local MAX_WINDOWS = 2
    local planner, actions = setup_barricade_world(MAX_WINDOWS)

    -- Sabotage the plan by removing the action to get resources.
    -- The start state has hasHammer=false, so without this action,
    -- the rest of the plan is impossible.
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