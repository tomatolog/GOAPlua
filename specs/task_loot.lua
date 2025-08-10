-- File: specs/task_loot.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner's ability to use the
--  actions converted from LootCategoryTask.
-- ------------------------------------------------------------------

local Planner = require("goap.Planner")
local ScavengeTask = require("goap.tasks.scavenge") -- Import the task actions

describe("Planner with Loot Task", function()

  -- Helper function to set up a world for a looting plan.
  local function setup_loot_world(containers_to_loot)
    -- World definition -- MUST BE COMPLETE
    local world = Planner(
        "isInside", "hasRoomInBag", "containersToLoot", "hasContainerTarget", "atContainer",
        "atBuilding", "entryMethod", "hasBreachingTool", "wantsToLoot" -- Add ALL states
    )

    -- Start and goal states
    world:set_start_state{
        isInside = true,
        hasRoomInBag = true,
        containersToLoot = containers_to_loot,
        hasContainerTarget = false,
        atContainer = false,
        atBuilding = true,
        entryMethod = "door",
        hasBreachingTool = false,
        wantsToLoot = true, -- Add missing state
    }
    world:set_goal_state{
        containersToLoot = 0,
    }

    local actions = ScavengeTask.create_actions(containers_to_loot)
    return world, actions
  end
  
  it("should find a full plan to loot 2 containers", function()
    local CONTAINERS_TO_LOOT = 2
    local planner, actions = setup_loot_world(CONTAINERS_TO_LOOT)
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0, "A plan should have been found") -- This assertion should now pass

    -- Assert the exact sequence for looting two containers
    local expected_sequence = {
      "findContainer2", "walkToContainer2", "lootContainer2",
      "findContainer1", "walkToContainer1", "lootContainer1",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Assert the total cost of the plan
    -- Cost for one loop: find(3) + walk(2) + loot(4) = 9
    -- Total cost for two loops: 9 * 2 = 18
    local expected_cost = 18
    assert.are.equal(expected_cost, plan[#plan].g)

    -- Assert that the goal state is met
    assert.are.equal(0, plan[#plan].state.containersToLoot)
  end)

  it("should find a shorter plan if already targeting a container", function()
    local CONTAINERS_TO_LOOT = 1
    local planner, actions = setup_loot_world(CONTAINERS_TO_LOOT)

    planner:set_start_state{
        isInside = true,
        hasRoomInBag = true,
        containersToLoot = 1,
        hasContainerTarget = true,
        atContainer = false,
        atBuilding = true,
        entryMethod = "door",
        hasBreachingTool = false,
        wantsToLoot = true,
    }
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)

    local expected_sequence = { "walkToContainer1", "lootContainer1" }
    local actual_sequence = {}
    for _, node in ipairs(plan) do table.insert(actual_sequence, node.name) end
    assert.are.same(expected_sequence, actual_sequence)

    local expected_cost = 6
    assert.are.equal(expected_cost, plan[#plan].g) -- The error was here, this will now pass
  end)

  it("should find no plan if the bag is full", function()
    local CONTAINERS_TO_LOOT = 1
    local planner, actions = setup_loot_world(CONTAINERS_TO_LOOT)

    -- Modify the start state to have no room in the bag.
    planner:set_start_state{
        isInside = true,
        hasRoomInBag = false, -- This should block the entire plan
        containersToLoot = 1,
        hasContainerTarget = false,
        atContainer = false,
        atBuilding = true,
        entryMethod = "door",
        hasBreachingTool = false,
    }
    planner:set_action_list(actions)
    
    local plan = planner:calculate()
    
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan, "Expected no plan when bag is full")
  end)

end)