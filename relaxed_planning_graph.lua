local deepcopy = require('pl.tablex').deepcopy
local utils = require("utils")

local RPG = {}

-- Builds a Relaxed Planning Graph.
-- Ignores delete effects (i.e., it's monotonic).
-- @param start_state (table) The initial state of the world.
-- @param actions (table) The conditions table from an Action object.
-- @param reactions (table) The reactions table from an Action object.
-- @return (table) The RPG structure, or nil if inputs are invalid.
function RPG.build(start_state, actions, reactions)
    if not start_state or not actions or not reactions then return nil end

    local rpg = {
        fact_layers = {},  -- fact_layers[i] = set of facts (as a table with state_keys)
        action_layers = {},-- action_layers[i] = list of action names
        fact_level = {},   -- fact_level[fact_name] = first level it appears
        fact_costs = {}    -- fact_costs[fact_name] = min cost to achieve it (h_add/h_max)
    }

    -- Layer 0: Initial facts
    local initial_facts = {}
    for k, v in pairs(start_state) do
        -- We track individual facts, not the whole world state
        if v ~= -1 then
            initial_facts[k] = v
            rpg.fact_level[k] = 0
            rpg.fact_costs[k] = 0
        end
    end
    rpg.fact_layers[1] = initial_facts

    local level = 1
    while true do
        local current_facts = rpg.fact_layers[level]
        local applicable_actions = {}

        -- Find all actions whose preconditions are met by the current fact layer
        for name, conds in pairs(actions) do
            local all_preconds_met = true
            for fact_name, required_val in pairs(conds) do
                if required_val ~= -1 and current_facts[fact_name] ~= required_val then
                    all_preconds_met = false
                    break
                end
            end
            if all_preconds_met then
                table.insert(applicable_actions, name)
            end
        end
        
        -- need to guarantee a stable order
        table.sort(applicable_actions)
        
        -- If no new actions can be applied, the graph is complete
        if #applicable_actions == 0 then
            break
        end

        rpg.action_layers[level] = applicable_actions

        -- Create the next fact layer by applying all add-effects (reactions)
        local next_facts = deepcopy(current_facts)
        local facts_added_this_level = false
        for _, action_name in ipairs(applicable_actions) do
            local react = reactions[action_name]
            for fact_name, new_val in pairs(react) do
                -- If this fact is new or has changed, add it to the next layer
                if next_facts[fact_name] ~= new_val then
                    next_facts[fact_name] = new_val
                    facts_added_this_level = true
                    -- Record the level where this specific fact value first appeared
                    if not rpg.fact_level[fact_name] then
                       rpg.fact_level[fact_name] = level
                    end
                end
            end
        end

        -- If the fact layer hasn't changed, we've reached a fixed point
        if not facts_added_this_level and #rpg.fact_layers > 1 and utils.state_key(next_facts) == utils.state_key(rpg.fact_layers[#rpg.fact_layers]) then
            break
        end

        level = level + 1
        rpg.fact_layers[level] = next_facts

        -- Safety break for runaway graphs
        if level > 50 then
            print("Warning: RPG build exceeded 50 layers. Aborting.")
            break
        end
    end

    return rpg
end

-- Heuristic function using the 'add' strategy (h_add).
-- It sums the levels at which each unsatisfied goal proposition first appears.
function RPG.h_add(rpg, current_state, goal_state)
    if not rpg then return 0 end
    
    local cost = 0
    for fact_name, goal_val in pairs(goal_state) do
        if goal_val ~= -1 and current_state[fact_name] ~= goal_val then
            -- Find the first level where the GOAL condition is met in the RPG
            local found_level = nil
            for i, layer in ipairs(rpg.fact_layers) do
                if layer[fact_name] == goal_val then
                    found_level = i - 1 -- Level is 0-indexed
                    break
                end
            end
            
            if found_level then
                cost = cost + found_level
            else
                -- This goal is unreachable according to the RPG. Return infinity.
                return math.huge
            end
        end
    end
    return cost
end


return RPG