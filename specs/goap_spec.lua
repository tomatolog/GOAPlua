require("class")
local Goap = require("Goap") -- ensure file loaded for global functions

describe("Goap", function()
  it("distance_to_state handles equal states as 0", function()
    local s1 = { a = true, b = false }
    local s2 = { a = true, b = false }
    assert.equals(0, distance_to_state(s1, s2))
  end)

  it("distance_to_state counts differences and ignores -1 in goal", function()
    local s1 = { a = true, b = false, c = true }
    local s2 = { a = false, b = -1 } -- b ignored
    assert.equals(1, distance_to_state(s1, s2))
  end)

  it("distance_to_state handles asymmetric keys", function()
    local s1 = { a = true }
    local s2 = { a = false, b = true }
    -- a differs => 1; b in s2 vs s1[b]=nil => differs => +1 (since not -1)
    assert.equals(2, distance_to_state(s1, s2))
  end)

  it("conditions_are_met respects -1 wildcard", function()
    local s = { a = true, b = false }
    local cond = { a = -1, b = false }
    assert.is_true(conditions_are_met(s, cond))
  end)

  it("node_in_list compares name and exact state", function()
    local n = { name = "eat", state = { x=true, y=false } }
    local list = {
      [1] = { name = "eat", state = { x=true, y=false } },
      [2] = { name = "eat", state = { x=false } }
    }
    assert.is_true(node_in_list(n, list))
    local n2 = { name = "eat", state = { x=true, y=true } }
    assert.is_false(node_in_list(n2, list))
  end)

  it("astar finds a path and applies reactions", function()
    local start = { hungry = true, has_food = false }
    local goal  = { hungry = false }
    local actions = {
      cook = { hungry = true, has_food = false },
      eat = { hungry = true, has_food = true },
    }
    local reactions = {
      cook = { has_food = true },
      eat = { hungry = false, has_food = false },
    }
    local weights = { cook = 1, eat = 1 }

    local path = astar(start, goal, actions, reactions, weights)
    -- Expect two steps: cook then eat
    assert.is_true(#path >= 1)
    local names = {}
    for i, n in ipairs(path) do names[i] = n.name end
    assert.same({ "cook", "eat" }, names)
    -- final node state equals goal on checked keys
    local last = path[#path]
    assert.is_true(conditions_are_met(last.state, goal))
  end)

  it("astar prefers cheaper path based on weights", function()
    local start = { a = true }
    local goal  = { z = true }
    local actions = {
      step1 = { a=true },
      step2 = { b=true },
      heavy = { c=true },
    }
    local reactions = {
      step1 = { b = true },         -- a->b
      step2 = { z = true },         -- b->z
      heavy = { z = true },         -- c->z (but c not available)
    }
    local weights = { step1 = 1, step2 = 1, heavy = 100 }

    local path = astar(start, goal, actions, reactions, weights)
    local names = {}
    for i, n in ipairs(path) do names[i] = n.name end
    assert.same({ "step1", "step2" }, names)
  end)

  it("astar returns empty when no path", function()
    local start = { a = true }
    local goal  = { z = true }
    local actions = {
      x = { a = true }
    }
    local reactions = {
      x = { a = true } -- no progress to z
    }
    local weights = { x = 1 }
    local path = astar(start, goal, actions, reactions, weights)
    assert.same({}, path)
  end)
end)