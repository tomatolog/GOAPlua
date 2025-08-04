local Action = require("Action")

describe("Action", function()
  it("adds conditions and reactions; weight must be set explicitly", function()
  local actions = Action()
  actions:add_condition("eat", { hungry = true, has_food = true })
  actions:add_reaction("eat", { hungry = false })
  
  assert.is_true(actions.conditions.eat.hungry)
  assert.is_true(actions.conditions.eat.has_food)
  assert.is_true(actions.reactions.eat.hungry == false)
  -- Weight is not auto-set anymore
  assert.is_nil(actions.weights.eat)
  end)

  it("merges multiple conditions/reactions for the same action", function()
    local actions = Action()
    actions:add_condition("cook", { in_kitchen = true })
    actions:add_condition("cook", { hungry = true })
    actions:add_reaction("cook", { has_food = true })
    actions:add_reaction("cook", { hungry = false })

    assert.is_true(actions.conditions.cook.in_kitchen)
    assert.is_true(actions.conditions.cook.hungry)
    assert.is_true(actions.reactions.cook.has_food)
    assert.is_true(actions.reactions.cook.hungry == false)
  end)

  it("errors when adding a reaction without a matching condition", function()
    local actions = Action()
    assert.has_error(function()
      actions:add_reaction("sleep", { tired = false })
    end, "Trying to add reaction 'sleep' without matching condition.")
  end)

  it("errors when setting weight without a matching condition", function()
    local actions = Action()
    assert.has_error(function()
      actions:set_weight("move", 3)
    end, "Trying to set weight 'move' without matching condition.")
  end)

  it("overrides weight correctly", function()
    local actions = Action()
    actions:add_condition("walk", { ok = true })
    actions:set_weight("walk", 5)
    assert.equals(5, actions.weights.walk)
  end)
  
  it("errors when adding a reaction with -1 value", function()
    local actions = Action()
    actions:add_condition("bad", { a = true })
    
    local ok, err = pcall(function()
      actions:add_reaction("bad", { a = -1 })
    end)
    
    assert.is_false(ok)
    err = tostring(err)
    -- Match substring anywhere to be robust to Busted's filename:line prefixes
    assert.is_truthy(err:match("Invalid reaction value %-1 for action 'bad'"))
  end)
   
end)