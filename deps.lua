-- Try to load Penlight normally; if it fails, try a vendored 'pl' folder in the repo.
local ok = pcall(function() return require("pl.class") end)
if not ok then
package.path = "./pl/?.lua;./pl/?/init.lua;" .. package.path
end
return true