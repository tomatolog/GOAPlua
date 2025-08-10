local class = require('pl.class')
local World = class()

function World:_init()
	self.planners = {}
	self.plans = {}
end 

function World:add_planner(planner)
	table.insert(self.planners,planner)
end 

function World:calculate()
	self.plans = {}
	for _,v in pairs(self.planners) do 
		table.insert(self.plans,v:calculate())
	end 
end 

function World:get_plan(debug)
	local _plans_by_cost = {}
	for _, plan in pairs(self.plans) do
        -- A plan might be empty if no path was found
		if plan and #plan > 0 then
            -- The total cost of a plan is the 'g' score of the FINAL node.
			local plan_cost = plan[#plan].g
			
			_plans_by_cost[plan_cost] = _plans_by_cost[plan_cost] or {}
			table.insert(_plans_by_cost[plan_cost], plan)
        end
	end

	if debug then
		local i = 1
        -- Stable, sorted iteration by plan_cost
        local costs = {}
        for k in pairs(_plans_by_cost) do table.insert(costs, k) end
        table.sort(costs) -- Sort costs numerically ascending

		for _, plan_cost in ipairs(costs) do
            local plans = _plans_by_cost[plan_cost]
			for _, plan in pairs(plans) do
				print(i, " (Total Cost: "..tostring(plan_cost)..")")
				for _, node in ipairs(plan) do
					print("\t", node.name, "(g="..node.g..")")
				end
				i = i + 1
			end
		end
	end

    -- Return the plan(s) with the minimal cost
    local min_cost = nil
    for k in pairs(_plans_by_cost) do
        if min_cost == nil or k < min_cost then
            min_cost = k
        end
    end

    if min_cost ~= nil then
        return _plans_by_cost[min_cost]
    end
    
    return nil -- No valid plans found
end

return World
