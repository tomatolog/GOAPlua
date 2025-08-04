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
local function sum(plan)
	local s = 0 
	for _,v in pairs(plan)  do 
		s = s + v["g"]
	end 
	return s 
end 
function World:get_plan(debug)
	local _plans = {}
	for _,plan in pairs(self.plans) do 
		local _plan_cost = sum( plan )
		
		_plans[_plan_cost] = _plans[_plan_cost] or {}
		table.insert(_plans[_plan_cost],plan)
	end 
	if  debug then 
		local  i = 1
        -- stable, sorted iteration by plan_score
        local keys = {}
        for k in pairs(_plans) do table.insert(keys, k) end
        table.sort(keys, function(a,b) return a < b end)
		for _, plan_score in ipairs(keys) do
            local plans = _plans[plan_score]
			for _,plan in pairs(plans) do 
				print(i)
				for _,v in pairs(plan) do 
					print("\t",v["name"])
				end 
				i = i + 1
				print("\n\tTotal cost",plan_score)
			end 
		end 
	end 
    -- return the plan(s) with minimal cost deterministically
    local min_key = nil
    for k in pairs(_plans) do
        if min_key == nil or k < min_key then
            min_key = k
        end
    end
    if min_key ~= nil then
        return _plans[min_key]
    end
    return nil
end

return World
