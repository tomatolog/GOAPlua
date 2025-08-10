-- goap/debug/PlannerDebug.lua
local PlannerDebug = {}

-- -----------------------------------------------------------------
-- 1) Verbose A* – a thin wrapper around goap.Goap.astar
-- -----------------------------------------------------------------
local Goap = require("goap.Goap")
local utils = require("goap.utils")

function PlannerDebug:set_verbose(level)
    self._verbose = level or 0
end

local function log(pl, fmt, ...)
    if pl._verbose and pl._verbose > 0 then
        io.write(string.format(fmt, ...))
    end
end

-- -----------------------------------------------------------------
-- 2) **run_debug** – the method the REPL expects.
--    It does exactly the same thing that the debug‑aware
--    `PlannerDebug:calculate()` does, but returns the extra
--    statistics table.
-- -----------------------------------------------------------------
function PlannerDebug:run_debug()
    -- validation (same as before)
    self:validate()

    -- build the relaxed‑planning‑graph once
    local rpg = require("goap.relaxed_planning_graph").build(
        self.start_state,
        self.action_list.conditions,
        self.action_list.reactions)

    -- put the RPG into the heuristic context
    local heuristic_params = self.heuristic_params or {}
    heuristic_params.rpg = rpg

    -----------------------------------------------------------------
    -- statistics that the REPL will print
    -----------------------------------------------------------------
    local stats = {expansions = 0, open_max = 0, closed = 0}

    -----------------------------------------------------------------
    -- a tiny wrapper around Goap.astar so we can measure time
    -----------------------------------------------------------------
    local wrapped_astar = function(...)
        local start = os.clock()
        local plan = Goap.astar(...)
        local elapsed = os.clock() - start
        log(self, "\n=== A* finished (%.3fs) ===\n", elapsed)
        return plan, stats
    end

    -----------------------------------------------------------------
    -- monkey‑patch the neighbour‑expansion function to collect stats
    -----------------------------------------------------------------
    local orig_expand = require("goap.Goap").expand_neighbors
    local function debug_expand(node, path)
        stats.expansions = stats.expansions + 1
        if path.open and #path.open.data > stats.open_max then
            stats.open_max = #path.open.data
        end
        orig_expand(node, path)
    end
    package.loaded["goap.Goap"].expand_neighbors = debug_expand

    -----------------------------------------------------------------
    -- run the real search
    -----------------------------------------------------------------
    local plan, _ = wrapped_astar(
        self.start_state,
        self.goal_state,
        self.action_list.conditions,
        self.action_list.reactions,
        self.action_list.weights,
        self.heuristic_strategy,
        heuristic_params)

    -----------------------------------------------------------------
    -- restore the original neighbour function
    -----------------------------------------------------------------
    package.loaded["goap.Goap"].expand_neighbors = orig_expand

    return plan, stats
end

-- -----------------------------------------------------------------
-- 3) Validation helpers (unchanged)
-- -----------------------------------------------------------------
function PlannerDebug:validate()
    assert(self.start_state, "start state not set")
    assert(self.goal_state,  "goal state not set")
    assert(self.action_list, "action list not set")

    -- a) every goal key must be producible
    for k,_ in pairs(self.goal_state) do
        local producible = false
        for a,react in pairs(self.action_list.reactions) do
            if react[k] ~= nil and react[k] == self.goal_state[k] then
                producible = true
                break
            end
        end
        if not producible then
            error(string.format(
                "Goal key '%s' cannot be produced by any action", k))
        end
    end

    -- b) at least one action applicable from start
    local any = false
    for name,cond in pairs(self.action_list.conditions) do
        if Goap.conditions_are_met(self.start_state, cond) then
            any = true
            break
        end
    end
    if not any then
        error("No action is applicable from the start state – check pre‑conditions")
    end

    -- c) each action has a positive weight
    for name,w in pairs(self.action_list.weights) do
        if type(w) ~= "number" or w <= 0 then
            error(string.format(
                "Invalid weight for action '%s' (must be >0)", name))
        end
    end
    return true
end

-- -----------------------------------------------------------------
-- 4) Dump helpers (only `dump_state` needed a tiny fix)
-- -----------------------------------------------------------------
local pretty = require("pl.pretty")

function PlannerDebug:dump_state(state)
    -- `pl.pretty` does not have a `state` function; use `write` instead.
    io.write(pretty.write(state) .. "\n")
end

function PlannerDebug:dump_actions()
    for name,cond in pairs(self.action_list.conditions) do
        local reac = self.action_list.reactions[name]
        local w    = self.action_list.weights[name] or "?"
        io.write(string.format("[%-30s] w=%s\n  pre: %s\n  eff: %s\n",
            name, tostring(w), pretty.table(cond), pretty.table(reac)))
    end
end

function PlannerDebug:dump_unreachable_actions()
    local unreachable = {}
    for name,cond in pairs(self.action_list.conditions) do
        if not Goap.conditions_are_met(self.start_state, cond) then
            table.insert(unreachable, name)
        end
    end
    return unreachable
end

function PlannerDebug:dump_goal_contributors()
    for gk,_ in pairs(self.goal_state) do
        io.write(string.format("Goal key '%s' can be set by:\n", gk))
        for name,react in pairs(self.action_list.reactions) do
            if react[gk] ~= nil then
                io.write("   - " .. name .. "\n")
            end
        end
    end
end

return PlannerDebug