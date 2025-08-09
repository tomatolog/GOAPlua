-- File: specs/find_unlooted_building_spec.lua
-- ------------------------------------------------------------------
-- A Busted spec to test the GOAP planner's ability to form a
-- plan that starts with finding a building.
-- ------------------------------------------------------------------

local Planner = require("Planner")
local ScavengeTask = require("tasks.scavenge") -- Import the task actions

describe("Planner with Find Unlooted Building Task", function()

  -- Helper function to set up a world for a full scavenging plan.
  local function setup_scavenge_world(containers_to_loot)
    containers_to_loot = containers_to_loot or 1

    -- World definition -- MUST BE COMPLETE
    local world = Planner(
        "wantsToLoot", "hasBuildingTarget", "atBuilding", "isInside",
        "containersToLoot", "hasContainerTarget", "atContainer", "hasRoomInBag",
        "entryMethod", "hasBreachingTool" -- ADD THE MISSING STATES
    )

    -- Start and goal states
    world:set_start_state{
        wantsToLoot = true,
        hasBuildingTarget = false,
        atBuilding = false,
        isInside = false,
        containersToLoot = containers_to_loot,
        hasContainerTarget = false,
        atContainer = false,
        hasRoomInBag = true,
        entryMethod = "door", -- PROVIDE A DEFAULT ENTRY METHOD
        hasBreachingTool = false,
    }
    world:set_goal_state{
        containersToLoot = 0,
    }

    local actions = ScavengeTask.create_actions(containers_to_loot)
    return world, actions
  end

  it("should find a full plan from wanting to loot to having supplies", function()
    local CONTAINERS_TO_LOOT = 1
    local planner, actions = setup_scavenge_world(CONTAINERS_TO_LOOT)
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)
    assert.is_true(#plan > 0, "A plan should have been found")

    -- The expected sequence needs the door entry method
    local expected_sequence = {
      "findUnlootedBuilding",
      "moveToBuilding",
      "enterBuildingViaDoor", -- This action is now possible
      "findContainer1",
      "walkToContainer1",
      "lootContainer1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do table.insert(actual_sequence, node.name) end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: find(15) + move(5) + enter(2) + findCont(3) + walk(2) + loot(4) = 31
    local expected_cost = 31
    assert.are.equal(expected_cost, plan[#plan].g)
    assert.are.equal(0, plan[#plan].state.containersToLoot)
  end)

  it("should find a shorter plan if already at a building", function()
    local CONTAINERS_TO_LOOT = 1
    local planner, actions = setup_scavenge_world(CONTAINERS_TO_LOOT)

    -- Modify the start state, ensuring all states are defined
    planner:set_start_state{
        wantsToLoot = true,
        hasBuildingTarget = true,
        atBuilding = true,
        isInside = false,
        containersToLoot = 1,
        hasContainerTarget = false,
        atContainer = false,
        hasRoomInBag = true,
        entryMethod = "door", -- MUST BE DEFINED
        hasBreachingTool = false,
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)
    assert.is_true(#plan > 0, "A shorter plan should have been found")

    local expected_sequence = {
      "enterBuildingViaDoor",
      "findContainer1",
      "walkToContainer1",
      "lootContainer1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do table.insert(actual_sequence, node.name) end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: enter(2) + find(3) + walk(2) + loot(4) = 11
    local expected_cost = 11
    assert.are.equal(expected_cost, plan[#plan].g)
  end)

  -- This test remains valid as is.
  it("should find no plan if no unlooted buildings can be found", function()
    local planner, actions = setup_scavenge_world(1)
    actions.conditions.findUnlootedBuilding = nil
    actions.reactions.findUnlootedBuilding = nil
    actions.weights.findUnlootedBuilding = nil
    planner:set_action_list(actions)
    local plan = planner:calculate()
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan)
  end)
end)