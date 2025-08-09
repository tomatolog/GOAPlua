-- File: specs/entry_into_building_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner's ability to choose
--  different methods for entering a building.
-- ------------------------------------------------------------------

local Planner = require("Planner")
local ScavengeTask = require("tasks.scavenge") -- Import the task actions

describe("Planner with Attempt Entry Into Building Task", function()

  -- Helper function to set up a world for entering a building.
  local function setup_entry_world()
    -- World definition
    local world = Planner(
        "atBuilding", "isInside", "entryMethod", "hasBreachingTool"
    )

    -- Start and goal states
    world:set_start_state{
        atBuilding = true,
        isInside = false,
        entryMethod = "door", -- Default to trying the door
        hasBreachingTool = false,
    }
    world:set_goal_state{
        isInside = true,
    }

    local actions = ScavengeTask.create_actions()
    return world, actions
  end

  it("should find the cheapest plan via an unlocked door", function()
    local planner, actions = setup_entry_world()
    
    -- No changes needed, the default start state is trying the door.
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = { "enterBuildingViaDoor" }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost for using the door is 2
    assert.are.equal(2, plan[#plan].g)
  end)

  it("should find a plan through the window if the door is blocked", function()
    local planner, actions = setup_entry_world()

    -- Modify the start state to simulate a blocked door.
    -- The game logic would have set entryMethod to "window".
    planner:set_start_state{
        atBuilding = true,
        isInside = false,
        entryMethod = "window",
        hasBreachingTool = false,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = { "enterBuildingViaWindow" }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)
    
    -- Cost for using the window is 5
    assert.are.equal(5, plan[#plan].g)
  end)
  
  it("should find a plan to breach if door/window fail and tool is available", function()
    local planner, actions = setup_entry_world()

    -- Simulate door/window being unusable and having a tool.
    planner:set_start_state{
        atBuilding = true,
        isInside = false,
        entryMethod = "breach",
        hasBreachingTool = true,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()
    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    local expected_sequence = { "enterBuildingByBreaching" }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)
    
    -- Cost for breaching is 10
    assert.are.equal(10, plan[#plan].g)
  end)

  it("should find no plan to breach if no breaching tool is available", function()
    local planner, actions = setup_entry_world()

    -- Simulate door/window being unusable and having NO tool.
    planner:set_start_state{
        atBuilding = true,
        isInside = false,
        entryMethod = "breach",
        hasBreachingTool = false,
    }
    
    planner:set_action_list(actions)
    local plan = planner:calculate()
    
    assert.is_not_nil(plan)
    assert.are.equal(0, #plan, "Expected no plan when trying to breach without a tool")
  end)

end)