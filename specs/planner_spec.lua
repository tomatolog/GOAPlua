local deepcopy = require('pl.tablex').deepcopy

local Planner = require("Planner")
local Action = require("Action")

describe("Planner", function()
  it("validates start/goal state keys", function()
    local p = Planner("a", "b")
    assert.has_error(function() p:set_start_state({ c = true }) end, "Invalid states for world start state: c")
    assert.has_error(function() p:set_goal_state({ c = true }) end, "Invalid states for world goal state: c")
  end)

  it("builds state with unknowns set to -1", function()
    local p = Planner("a", "b")
    local s = p:state({ a = true })
    assert.equals(true, s.a)
    assert.equals(-1, s.b)
  end)

  it("calculates a plan from actions", function()
    local p = Planner("hungry", "has_food")
    p:set_start_state({ hungry = true, has_food = false })
    p:set_goal_state({ hungry = false })

    local act = Action()
    act:add_condition("cook", { hungry = true, has_food = false })
    act:add_reaction("cook", { has_food = true })
    act:set_weight("cook", 1)
    act:add_condition("eat", { hungry = true, has_food = true })
    act:add_reaction("eat", { hungry = false, has_food = false })
    act:set_weight("eat", 1)    
    p:set_action_list(act)

    local path = p:calculate()
    local names = {}
    for i, n in ipairs(path) do names[i] = n.name end
    assert.same({ "cook", "eat" }, names)
  end)

  it("does not mutate provided action tables", function()
    local p = Planner("x", "y")
    p:set_start_state({ x = true, y = false })
    p:set_goal_state({ y = true })
    local act = Action()
    act:add_condition("toggle", { x = true })
    act:add_reaction("toggle", { y = true })
    act:set_weight("toggle", 1)
    p:set_action_list(act)
    local before = {
      cond = deepcopy(act.conditions),
      react = deepcopy(act.reactions),
      weights = deepcopy(act.weights),
    }
    p:calculate()
    assert.same(before.cond, act.conditions)
    assert.same(before.react, act.reactions)
    assert.same(before.weights, act.weights)
  end)
  
  it("errors if an action is missing a weight", function()
    local p = Planner("a", "b")
    p:set_start_state({ a = true, b = false })
    p:set_goal_state({ b = true })
    local act = Action()
    act:add_condition("go", { a = true })
    act:add_reaction("go", { b = true })
    -- No weight set
    p:set_action_list(act)
    assert.has_error(function() p:calculate() end, "Missing weight for action 'go'")
  end)
  
  it("errors if weight is non-positive or non-number", function()
    local invalids = { 0, -1, "x", 0/0 } -- NaN as 0/0
    for _, w in ipairs(invalids) do
      local p = Planner("a", "b")
      p:set_start_state({ a = true, b = false })
      p:set_goal_state({ b = true })
      local act = Action()
      act:add_condition("go", { a = true })
      act:add_reaction("go", { b = true })
      act:set_weight("go", w)
      p:set_action_list(act)
      assert.has_error(function() p:calculate() end, "Invalid weight for action 'go'")
    end
  end)
  
  it("succeeds when all weights are explicit and positive", function()
    local p = Planner("a", "b")
    p:set_start_state({ a = true, b = false })
    p:set_goal_state({ b = true })
    local act = Action()
    act:add_condition("go", { a = true })
    act:add_reaction("go", { b = true })
    act:set_weight("go", 2)
    p:set_action_list(act)
    local path = p:calculate()
    assert.equals(1, #path)
    assert.equals("go", path[1].name)
  end)  
  
 it("errors if an action condition is missing a matching reaction", function()
   local p = Planner("a", "b")
   p:set_start_state({ a = true, b = false })
   p:set_goal_state({ b = true })
   local act = Action()
   act:add_condition("go", { a = true })
   -- missing reaction
   act:set_weight("go", 1)
   p:set_action_list(act)
   assert.has_error(function() p:calculate() end, "Missing reaction for action 'go'")
 end)
   
end)