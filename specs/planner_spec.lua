local Planner = require("Planner")
local Action = require("Action")

describe("Planner", function()
  it("validates start/goal state keys", function()
    local p = Planner.new("a", "b")
    assert.has_error(function() p:set_start_state({ c = true }) end, "Invalid states for world start state: c")
    assert.has_error(function() p:set_goal_state({ c = true }) end, "Invalid states for world goal state: c")
  end)

  it("builds state with unknowns set to -1", function()
    local p = Planner.new("a", "b")
    local s = p:state({ a = true })
    assert.equals(true, s.a)
    assert.equals(-1, s.b)
  end)

  it("calculates a plan from actions", function()
    local p = Planner.new("hungry", "has_food")
    p:set_start_state({ hungry = true, has_food = false })
    p:set_goal_state({ hungry = false })

    local act = Action.new()
    act:add_condition("cook", { hungry = true, has_food = false })
    act:add_reaction("cook", { has_food = true })
    act:add_condition("eat", { hungry = true, has_food = true })
    act:add_reaction("eat", { hungry = false, has_food = false })
    p:set_action_list(act)

    local path = p:calculate()
    local names = {}
    for i, n in ipairs(path) do names[i] = n.name end
    assert.same({ "cook", "eat" }, names)
  end)

  it("does not mutate provided action tables", function()
    local p = Planner.new("x", "y")
    p:set_start_state({ x = true, y = false })
    p:set_goal_state({ y = true })
    local act = Action.new()
    act:add_condition("toggle", { x = true })
    act:add_reaction("toggle", { y = true })
    p:set_action_list(act)
    local before = {
      cond = copyTable(act.conditions),
      react = copyTable(act.reactions),
      weights = copyTable(act.weights),
    }
    p:calculate()
    assert.same(before.cond, act.conditions)
    assert.same(before.react, act.reactions)
    assert.same(before.weights, act.weights)
  end)
end)