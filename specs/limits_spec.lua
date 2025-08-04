local Goap = require("Goap")

describe("Goap limits", function()
  it("stops search when expansion limit is reached (expansion_limit)", function()
    -- Unsolvable setup: goal requires z=true but no action can ever set z.
    local start = { a = true }
    local goal  = { z = true }
    local actions = {
      -- These actions only toggle between x and y; they never set z.
      to_x = { a = true },
      to_y = { x = true },
      loop = { y = true },
    }
    local reactions = {
      to_x = { x = true },
      to_y = { y = true },
      loop = { x = true }, -- loop x<->y dance
    }
    local weights = { to_x = 1, to_y = 1, loop = 1 }

    -- Without limits, the search would keep exploring until open is exhausted.
    -- With a very small expansion limit, we expect an early stop and empty plan.
    local path = Goap.astar(start, goal, actions, reactions, weights, nil, nil, {
      max_expansions = 5
    })
    assert.same({}, path)
  end)
  
  it("stops search when expansion limit is reached (broad branching, many actions)", function()
    -- Unsolvable, but with many distinct actions that never set goal key 'goal_reached'.
    local start = { seed = true }
    local goal  = { goal_reached = true }

    -- Generate many actions that flip or set unrelated keys.
    local actions = {}
    local reactions = {}
    local weights = {}

    -- A chain of actions that set temp_1..temp_N, none touching 'goal_reached'.
    local N = 50
    actions["start_step_1"] = { seed = true }
    reactions["start_step_1"] = { temp_1 = true }
    weights["start_step_1"] = 1

    for i = 2, N do
      local prev = "temp_" .. (i - 1)
      local curr = "temp_" .. i
      local aname = "step_" .. i
      actions[aname] = { [prev] = true }
      reactions[aname] = { [curr] = true }
      weights[aname] = 1
    end

    -- Add unrelated toggles to widen branching factor
    for i = 1, 50 do
      local key = "noise_" .. i
      local set_name = "set_" .. key
      local clr_name = "clr_" .. key
      actions[set_name] = { seed = true }
      reactions[set_name] = { [key] = true }
      weights[set_name] = 1

      actions[clr_name] = { [key] = true }
      reactions[clr_name] = { [key] = false }
      weights[clr_name] = 1
    end

    -- With a strict expansion limit, search should stop early and return empty.
    local path = Goap.astar(start, goal, actions, reactions, weights, nil, nil, {
      max_expansions = 10
    })
    assert.same({}, path)
  end)
end)
