-- goap/debug/run_example.lua
-- --------------------------------------------------------------
--  Helper that loads an example file, extracts the Planner and Action
--  objects that the example builds, and then drops you into the
--  interactive Debugger REPL.
-- --------------------------------------------------------------

local Debugger = require('goap.debug.Debugger')   -- the REPL we already have

-- -----------------------------------------------------------------
--  Load a script in a sandbox and **capture** the Planner and Action
--  objects that it creates.
-- -----------------------------------------------------------------
local function load_script(path)
    -----------------------------------------------------------------
    -- 1) Build a clean environment that falls back to the global one.
    -----------------------------------------------------------------
    local env = {}
    setmetatable(env, { __index = _G })

    -----------------------------------------------------------------
    -- 2) Hide the '--debug' flag while the script runs (prevents
    --    infinite recursion if the script itself contains a debug flag).
    -----------------------------------------------------------------
    local saved_arg = arg
    arg = {}                      -- the script sees an empty arg list
    -----------------------------------------------------------------
    -- 3) **Monkey‑patch** the two constructors we need to spy on.
    -----------------------------------------------------------------
    local goap = require('goap')
    local captured_planner, captured_actions

    local OrigPlanner = goap.Planner
    local OrigAction   = goap.Action

    goap.Planner = function(...)
        local p = OrigPlanner(...)
        captured_planner = p
        return p
    end

    goap.Action = function(...)
        local a = OrigAction(...)
        captured_actions = a
        return a
    end

    -----------------------------------------------------------------
    -- 4) Load and execute the file inside the sandbox.
    -----------------------------------------------------------------
    local chunk, err = loadfile(path, 't', env)
    if not chunk then error("cannot load '"..path.."': "..err) end
    chunk()                         -- runs the example – it creates the world

    -----------------------------------------------------------------
    -- 5) Restore the original constructors (so other code is not polluted).
    -----------------------------------------------------------------
    goap.Planner = OrigPlanner
    goap.Action   = OrigAction

    -----------------------------------------------------------------
    -- 6) Restore the original command‑line arguments.
    -----------------------------------------------------------------
    arg = saved_arg

    -----------------------------------------------------------------
    -- 7) Return everything we captured.
    -----------------------------------------------------------------
    return {
        env      = env,
        planner  = captured_planner,
        actions  = captured_actions,
    }
end

-- -----------------------------------------------------------------
--  Public entry point – receives the *path* to the example file.
-- -----------------------------------------------------------------
return function(example_path)
    if not example_path or example_path == '' then
        error("run_example needs the path to an example file")
    end

    local data = load_script(example_path)

    -----------------------------------------------------------------
    --  The wrapper now hands the planner and the actions to the REPL.
    -----------------------------------------------------------------
    local dbg = require('goap.debug.Debugger'):new()
    dbg:set_planner(data.planner, data.actions)   -- <-- new call
    dbg:run()
end