-- goap/debug/RPGDebug.lua
local RPGDebug = {}

function RPGDebug:dump_rpg(rpg, opts)
    opts = opts or {}
    local out = opts.out or io.stdout
    out:write("=== Relaxed Planning Graph ===\n")
    for i,layer in ipairs(rpg.fact_layers) do
        out:write(string.format("Fact layer %d:\n", i-1))
        for k,v in pairs(layer) do
            out:write(string.format("  %s = %s\n", k, tostring(v)))
        end
        if rpg.action_layers[i] then
            out:write("  Actions:\n")
            for _,a in ipairs(rpg.action_layers[i]) do
                out:write("    " .. a .. "\n")
            end
        end
        out:write("\n")
    end
end

return RPGDebug