-- goap/debug/ActionDebug.lua
local ActionDebug = {}

function ActionDebug:list_actions(actions)
    for name,_ in pairs(actions.conditions) do
        io.write(name .. "\n")
    end
end

function ActionDebug:find_conflicts()
    -- Detect two different actions that write the same key with *different* values.
    local conflicts = {}
    for name,react in pairs(self.reactions) do
        for key,val in pairs(react) do
            conflicts[key] = conflicts[key] or {}
            conflicts[key][name] = val
        end
    end
    local dup = {}
    for key, tbl in pairs(conflicts) do
        local distinct = {}
        for _,v in pairs(tbl) do distinct[v] = true end
        if next(distinct) and #tbl > 1 then
            dup[key] = tbl
        end
    end
    return dup
end

return ActionDebug