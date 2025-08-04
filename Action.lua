local class = require('pl.class')
local Action = class()
function Action:_init()
    self.conditions = {}
    self.reactions = {}
    self.weights = {}
end
local function  update(t1,t2)
    for k,v in pairs(t2) do
        t1[k] = v
    end
end

function Action:add_condition(key, conditions)
    if not self.conditions[key] then
        self.conditions[key] = conditions
        return
    end
    update(self.conditions[key],conditions)
end

local function validate_reaction_table(key, reaction)
    -- Reactions: disallow -1 (ambiguous); interpret only concrete assignments.
    for k, v in pairs(reaction) do
        if v == -1 then
            error("Invalid reaction value -1 for action '"..tostring(key).."' at key '"..tostring(k).."'. Reactions must specify concrete values (no -1).")
        end
        -- Optional: enforce boolean values; comment out if your domain is not strictly boolean.
        if type(v) ~= "boolean" then
            error("Invalid reaction value type for action '"..tostring(key).."', key '"..tostring(k).."': expected boolean, got "..type(v))
        end
    end
end

function Action:add_reaction(key, reaction)
    if not self.conditions[key] then
        error("Trying to add reaction '"..key.."' without matching condition.")
    end
    validate_reaction_table(key, reaction)
    if not self.reactions[key] then
        self.reactions[key] = reaction
        return
    end
    update(self.reactions[key],reaction)
end

function Action:set_weight(key, value)
    if not self.conditions[key] then
        error("Trying to set weight '"..key.."' without matching condition.")
    end
    self.weights[key] = value
end

return Action
