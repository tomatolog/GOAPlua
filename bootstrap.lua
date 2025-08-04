package.path = "./?.lua;./?/init.lua;" .. package.path

-- Add user-local LuaRocks paths (Lua 5.1). Adjust if you use a different Lua version.
local appdata = os.getenv("APPDATA") or ""
local lrbase = appdata .. "/luarocks"
package.path = table.concat({
lrbase .. "/share/lua/5.1/?.lua",
lrbase .. "/share/lua/5.1/?/init.lua",
package.path
}, ";")
package.cpath = lrbase .. "/lib/lua/5.1/?.dll;" .. package.cpath

return true