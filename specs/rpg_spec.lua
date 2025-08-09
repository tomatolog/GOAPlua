local RPG = require("relaxed_planning_graph")
local Action = require("Action")

describe("Relaxed Planning Graph (RPG)", function()
    -- A simple crafting scenario: get wood, get ore, make tool
    local actions = Action()
    actions:add_condition("getWood", { hasWood = false })
    actions:add_reaction("getWood", { hasWood = true })

    actions:add_condition("getOre", { hasOre = false })
    actions:add_reaction("getOre", { hasOre = true })
    
    actions:add_condition("craftTool", { hasWood = true, hasOre = true, hasTool = false })
    actions:add_reaction("craftTool", { hasTool = true })

    local start_state = { hasWood = false, hasOre = false, hasTool = false }
    local goal_state = { hasTool = true }

    it("builds a graph with correct layers", function()
        local rpg = RPG.build(start_state, actions.conditions, actions.reactions)
        assert.is_not_nil(rpg)
        -- Expect 3 fact layers:
        -- L0: {hasWood=F, hasOre=F, hasTool=F} (start)
        -- L1: {hasWood=T, hasOre=T, hasTool=F} (after getWood/getOre)
        -- L2: {hasWood=T, hasOre=T, hasTool=T} (after craftTool)
        assert.equals(3, #rpg.fact_layers)
        assert.equals(2, #rpg.action_layers)

        -- Check action layers
        assert.same({"getOre", "getWood"}, rpg.action_layers[1]) -- FROM: {"getWood", "getOre"}
        assert.same({"craftTool"}, rpg.action_layers[2])
    end)

    it("calculates h_add heuristic correctly", function()
        local rpg = RPG.build(start_state, actions.conditions, actions.reactions)
        
        -- From start state, goal `hasTool=true` first appears in layer 2 (index 3).
        -- Levels are 0-indexed, so cost is 2.
        local h = RPG.h_add(rpg, start_state, goal_state)
        assert.equals(2, h)

        -- From a state where we have wood, cost should be lower.
        local mid_state = { hasWood = true, hasOre = false, hasTool = false }
        -- To satisfy the goal, we still need to reach layer 2.
        -- In a more complex heuristic this might be 1, but h_add just looks at goal proposition levels.
        local h2 = RPG.h_add(rpg, mid_state, goal_state)
        assert.equals(2, h2)
    end)

    it("returns math.huge for an unreachable goal", function()
        local impossible_goal = { hasMagic = true }
        local rpg = RPG.build(start_state, actions.conditions, actions.reactions)
        local h = RPG.h_add(rpg, start_state, impossible_goal)
        assert.equals(math.huge, h)
    end)
end)