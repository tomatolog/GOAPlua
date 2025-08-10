local Planner = require("goap.Planner")
local World = require("goap.World")
local Action = require("goap.Action")

describe("World", function()
  it("adds planners and returns lowest-cost plan", function()
    local w = World()

    local p1 = Planner("s", "t")
    p1:set_start_state({ s = true, t = false })
    p1:set_goal_state({ t = true })
    local a1 = Action()
    a1:add_condition("fast", { s = true })
    a1:add_reaction("fast", { t = true })
    a1:set_weight("fast", 1)
    p1:set_action_list(a1)

    local p2 = Planner("s", "t")
    p2:set_start_state({ s = true, t = false })
    p2:set_goal_state({ t = true })
    local a2 = Action()
    a2:add_condition("slow1", { s = true })
    a2:add_reaction("slow1", { s = true }) -- no change
    a2:add_condition("slow2", { s = true })
    a2:add_reaction("slow2", { t = true })
    a2:set_weight("slow1", 10)
    a2:set_weight("slow2", 10)
    p2:set_action_list(a2)

    w:add_planner(p1)
    w:add_planner(p2)

    w:calculate()
    local plans = w:get_plan(false)
    -- Expect the first plan (fast) to be selected due to lower total g
    -- get_plan returns a list of plans sharing the same min cost; ensure at least one is the fast-only path
    local foundFast = false
    for _, plan in ipairs(plans) do
      local names = {}
      for i, n in ipairs(plan) do names[i] = n.name end
      if #names == 1 and names[1] == "fast" then
        foundFast = true
      end
    end
    assert.is_true(foundFast)
  end)
end)