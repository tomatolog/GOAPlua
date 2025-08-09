-- File: specs/find_unlooted_building_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner's ability to form a
--  plan that starts with finding a building.
-- ------------------------------------------------------------------

local Planner = require("Planner")
local ScavengeTask = require("tasks.scavenge") -- Import the task actions

describe("Planner with Find Unlooted Building Task", function()

  -- Helper function to set up a world for a full scavenging plan.
  local function setup_scavenge_world()
    -- World definition
    local world = Planner(
        "wantsToLoot", "hasBuildingTarget", "atBuilding", "isInside", "suppliesFound"
    )

    -- Start and goal states
    world:set_start_state{
        wantsToLoot = true,
        hasBuildingTarget = false,
        atBuilding = false,
        isInside = false,
        suppliesFound = 0,
    }
    world:set_goal_state{
        suppliesFound = 5,
    }

    local actions = ScavengeTask.create_actions()
    return world, actions
  end

  it("should find a full plan from wanting to loot to having supplies", function()
    local planner, actions = setup_scavenge_world()
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Assert the exact sequence for a full scavenging run
    local expected_sequence = {
      "findUnlootedBuilding",
      "moveToBuilding",
      "enterBuilding",
      "lootBuilding",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Assert the total cost of the plan
    -- find(15) + move(5) + enter(2) + loot(8) = 30
    local expected_cost = 30
    assert.are.equal(expected_cost, plan[#plan].g)

    -- Assert that the goal state is met
    assert.are.equal(5, plan[#plan].state.suppliesFound)
  end)

  it("should find a shorter plan if already at a building", function()
    local planner, actions = setup_scavenge_world()

    -- Modify the start state: we already found a building and are at it.
    planner:set_start_state{
        wantsToLoot = true,
        hasBuildingTarget = true,
        atBuilding = true,
        isInside = false,
        suppliesFound = 0,
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)

    -- The plan should skip finding and moving to the building
    local expected_sequence = {
      "enterBuilding",
      "lootBuilding",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: enter(2) + loot(8) = 10
    local expected_cost = 10
    assert.are.equal(expected_cost, plan[#plan].g)
  end)

  it("should find no plan if no unlooted buildings can be found", function()
    local planner, actions = setup_scavenge_world()

    -- Sabotage the plan by removing the ability to find a building.
    -- This simulates a world where all nearby buildings are looted.
    actions.conditions.findUnlootedBuilding = nil
    actions.reactions.findUnlootedBuilding = nil
    actions.weights.findUnlootedBuilding = nil
    
    planner:set_action_list(actions)
    local plan = planner:calculate()
    
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan)
  end)

end)