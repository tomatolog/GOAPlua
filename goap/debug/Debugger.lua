-- goap/debug/Debugger.lua
require("bootstrap")
require("deps")

local goap = require("goap")
local Planner = goap.Planner
local Action  = goap.Action
local tasks   = goap.tasks
local deepcopy = require("pl.tablex").deepcopy   -- <‑‑ add this

local Debugger = {}
Debugger.__index = Debugger

function Debugger:new()
    return setmetatable({
        planner = nil,
        actions = nil,
        original_goal  = nil,   -- will hold a deep‑copy of the goal
        verbose = 0,
    }, self)
end

function Debugger:help()
    print [[
Commands:
  new_world  <key1> <key2> …                – create a fresh Planner
  start      <k>=<v> …                      – set start state (bool/number)
  goal       <k>=<v> …                      – set goal state
  add_task   <name> <count>                 – create actions from a factory
      e.g. add_task barricade 3
  add_action <name>                         – add a *single* custom action
      (you will be prompted for pre‑conditions, effects, weight)
  set_weight <action> <weight>
  run       [verbose]                       – run planner, print plan + stats
  dump      actions|state|unreach|rpg|goal   – various diagnostics
  quit
]]
end

function Debugger:parse_kv(str)
    local k, v = str:match("^([^=]+)=(.+)")
    assert(k and v, "expected key=value")
    if v == "true" then v = true
    elseif v == "false" then v = false
    else v = tonumber(v) or v end
    return k, v
end

function Debugger:cmd_new_world(arg)
    local keys = {}
    for w in arg:gmatch("%S+") do table.insert(keys, w) end
    self.planner = Planner(table.unpack(keys))
    print("Created world with keys:", table.concat(keys, ", "))
end

function Debugger:cmd_start(arg)
    local state = {}
    for kv in arg:gmatch("%S+") do
        local k,v = self:parse_kv(kv)
        state[k] = v
    end
    self.planner:set_start_state(state)
    print("Start state set.")
end

function Debugger:cmd_goal(arg)
    local state = {}
    for kv in arg:gmatch("%S+") do
        local k,v = self:parse_kv(kv)
        state[k] = v
    end
    self.planner:set_goal_state(state)
    print("Goal state set.")
end

function Debugger:cmd_add_task(arg)
    local name, cnt = arg:match("^(%S+)%s+(%d+)")
    assert(name and cnt, "usage: add_task <name> <count>")
    cnt = tonumber(cnt)
    local factory = tasks[name]
    assert(factory, "unknown task '"..name.."'")
    local new_actions = factory.create_actions(cnt)
    if not self.actions then self.actions = goap.Action() end
    -- merge (same code as in the example)
    local function merge(dst, src)
        for k,v in pairs(src) do dst[k] = v end
    end
    merge(self.actions.conditions, new_actions.conditions)
    merge(self.actions.reactions,  new_actions.reactions)
    merge(self.actions.weights,    new_actions.weights)
    print(string.format("Added %d actions from %s(%d)", 
        #new_actions.conditions, name, cnt))
end

function Debugger:cmd_add_action(arg)
    io.write("Enter name of the new action: ")
    local name = io.read()
    local act = goap.Action()
    -- pre‑conditions
    print("Enter pre‑conditions (key=value), one per line, empty line to finish:")
    local cond = {}
    while true do
        local line = io.read()
        if line == "" then break end
        local k,v = self:parse_kv(line)
        cond[k] = v
    end
    act:add_condition(name, cond)

    -- effects
    print("Enter effects (key=value), one per line, empty line to finish:")
    local reac = {}
    while true do
        local line = io.read()
        if line == "" then break end
        local k,v = self:parse_kv(line)
        reac[k] = v
    end
    act:add_reaction(name, reac)

    io.write("Weight: ")
    local w = tonumber(io.read())
    act:set_weight(name, w)

    if not self.actions then self.actions = goap.Action() end
    merge(self.actions.conditions, act.conditions)
    merge(self.actions.reactions,  act.reactions)
    merge(self.actions.weights,    act.weights)

    print("Custom action added.")
end

function Debugger:cmd_set_weight(arg)
    local name, w = arg:match("^(%S+)%s+(%d+)")
    assert(name and w, "usage: set_weight <action> <weight>")
    self.actions:set_weight(name, tonumber(w))
    print("Weight updated.")
end

-----------------------------------------------------------------
--  HELP command (the REPL looks for cmd_<name>)
-----------------------------------------------------------------
function Debugger:cmd_help(_)
    self:help()
end

-----------------------------------------------------------------
--  When the wrapper creates the debugger we give it the planner
-----------------------------------------------------------------
-- (the wrapper (run_example.lua) will set dbg.planner and dbg.actions;
-- after that we store a copy of the goal so we can restore it later)
function Debugger:set_planner(planner, actions)
    self.planner = planner
    self.actions = actions
    self.original_goal = deepcopy(planner.goal_state)   -- keep a clean copy
end

-----------------------------------------------------------------
--  RUN command – restore the original goal before each execution
-----------------------------------------------------------------
function Debugger:cmd_run(arg)
    if not self.planner or not self.actions then
        error("You must create a world and add actions first")
    end

    self.planner:set_action_list(self.actions)

    -- *** restore the original goal (prevents the “atContainer” pollution) ***
    self.planner.goal_state = deepcopy(self.original_goal)

    if arg == "verbose" then self.planner:set_verbose(1) end

    local plan, stats = self.planner:run_debug()
    if not plan or #plan == 0 then
        print("❌ No viable plan")
        print("Unreachable actions:",
              table.concat(self.planner:dump_unreachable_actions(), ", "))
        return
    end

    print("\n=== PLAN (total cost = " .. plan[#plan].g .. ") ===")
    for i,node in ipairs(plan) do
        print(string.format("%2d. %-30s (g=%d)", i, node.name, node.g))
    end
    print("\n--- Stats ---")
    print("expansions :", stats.expansions)
    print("max open   :", stats.open_max)
end

function Debugger:cmd_dump(arg)
    if not self.planner then error("no planner yet") end
    if arg == "actions" then
        self.planner:dump_actions()
    elseif arg == "state" then
        self.planner:dump_state(self.planner.start_state)
        self.planner:dump_state(self.planner.goal_state)
    elseif arg == "unreach" then
        local u = self.planner:dump_unreachable_actions()
        print("Unreachable from start:", (#u>0 and table.concat(u, ", ") or "none"))
    elseif arg == "rpg" then
        local rpg = require("goap.relaxed_planning_graph").build(
            self.planner.start_state,
            self.planner.action_list.conditions,
            self.planner.action_list.reactions)
        self.planner:dump_rpg(rpg)
    elseif arg == "goal" then
        self.planner:dump_goal_contributors()
    else
        print("unknown dump target")
    end
end

function Debugger:cmd_help(_)
    self:help()
end

function Debugger:run()
    self:help()
    while true do
        io.write("\ngoap> ")
        local line = io.read()
        if not line then break end
        local cmd, rest = line:match("^(%S+)%s*(.*)")
        if cmd == "quit" or cmd == "exit" then break end
        local fn = self["cmd_"..cmd]
        if fn then
            local ok, err = pcall(fn, self, rest)
            if not ok then print("Error:", err) end
        else
            print("unknown command – type 'help'")
        end
    end
end

return Debugger