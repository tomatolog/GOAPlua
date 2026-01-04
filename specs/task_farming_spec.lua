-- File: specs/task_farming_spec.lua
-- ------------------------------------------------------------------
--  A Busted spec to test the GOAP planner with FarmingTask actions.
-- ------------------------------------------------------------------

local Planner = require("09_GOAP/Planner")
local FarmingTask = require("09_GOAP/tasks.farming")

describe("Planner with Farming Task", function()

  -- Helper to set up the world
  local function setup_farming_world()
    local world = Planner(
        "hasTrowel", "hasSeeds", "hasWaterContainer",
        "atFarmingArea", "isPlowed", "isSeeded", "isWatered",
        "cropReady", "hasProduce"
    )
    return world, FarmingTask.create_actions()
  end

  -----------------------------------------------------------------
  -- Test 1: Full Cycle (Plow -> Plant -> Water)
  -----------------------------------------------------------------
  it("should find a plan to plant and water crops", function()
    local planner, actions = setup_farming_world()
    
    planner:set_start_state{
        hasTrowel = false,
        hasSeeds = false,
        hasWaterContainer = false,
        atFarmingArea = false,
        isPlowed = false,
        isSeeded = false,
        isWatered = false,
        cropReady = false,
        hasProduce = false
    }
    
    -- Goal: A watered crop in the ground
    planner:set_goal_state{
        isWatered = true,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    assert.is_true(#plan > 0)

    -- Expected flow:
    -- 1. Get Trowel (for plowing)
    -- 2. Get Seeds (for planting)
    -- 3. Get Water (for watering)
    -- 4. Go to Farm
    -- 5. Plow
    -- 6. Sow
    -- 7. Water
    
    -- Note: Ordering of "Find" actions might vary depending on tie-breaking since costs are equal.
    -- But the farming steps must be sequential.
    
    local names = {}
    for _, node in ipairs(plan) do
      table.insert(names, node.name)
    end
    
    -- Verify essential steps are present
    assert.is_truthy(table.concat(names):find("plowField"))
    assert.is_truthy(table.concat(names):find("sowSeeds"))
    assert.is_truthy(table.concat(names):find("waterPlant"))
    
    -- Verify final state
    assert.is_true(plan[#plan].state.isWatered)
  end)

  -----------------------------------------------------------------
  -- Test 2: Harvesting
  -----------------------------------------------------------------
  it("should find a plan to harvest mature crops", function()
    local planner, actions = setup_farming_world()
    
    planner:set_start_state{
        atFarmingArea = false,
        cropReady = true,
        hasProduce = false,
        
        -- Irrelevant for harvesting
        hasTrowel = false,
        hasSeeds = false,
        isPlowed = false,
        isSeeded = true,
    }
    
    planner:set_goal_state{
        hasProduce = true,
    }
    
    planner:set_action_list(actions)
    planner:set_heuristic("rpg_add")

    local plan = planner:calculate()

    assert.is_not_nil(plan)
    
    local expected_sequence = {
      "goToFarmingArea",
      "harvestCrop",
    }
    local actual_sequence = {}
    for _, node in ipairs(plan) do
      table.insert(actual_sequence, node.name)
    end
    assert.are.same(expected_sequence, actual_sequence)

    -- Cost: Go(2) + Harvest(4) = 6
    assert.are.equal(6, plan[#plan].g)
  end)

end)