local Utils = {}

-- Canonical state key: sorted keys joined as key=value; booleans as 1/0
function Utils.state_key(state)
    local keys = {}
    for k in pairs(state) do table.insert(keys, k) end
    table.sort(keys, function(a,b) return a < b end)
    local parts = {}
    for _,k in ipairs(keys) do
        local v = state[k]
        local vs
        if type(v) == "boolean" then
            vs = v and "1" or "0"
        else
            vs = tostring(v)
        end
        table.insert(parts, tostring(k).."="..vs)
    end
    return table.concat(parts, ";")
end

return Utils