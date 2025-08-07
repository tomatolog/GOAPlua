-- File: tasks/barricade.lua
-- --------------------------------------------------------------
--  Defines a reusable set of actions for the "barricade multiple
--  windows" task. This module exports a factory function that
--  creates the actions for a given number of windows.
-- --------------------------------------------------------------
local Action = require("Action")

local BarricadeTask = {}

-- Factory function to create the actions for the barricade task.
-- @param num_windows (integer) The number of windows to generate actions for.
-- @return (Action) An Action object populated with all barricade-related actions.
function BarricadeTask.create_actions(num_windows)
    assert(type(num_windows) == "number" and num_windows > 0, "num_windows must be a positive integer")

    local actions = Action()

    -----------------------------------------------------------------
    --  ensureResources – grab hammer, plank and nails if we don’t have them
    -----------------------------------------------------------------
    actions:add_condition('ensureResources', { hasHammer = false })
    actions:add_reaction ('ensureResources', {
        hasHammer = true,
        hasPlank  = true,
        hasNails  = true,
    })
    actions:set_weight('ensureResources', 1)

    -----------------------------------------------------------------
    --  findWindow<N> – pick a concrete window when the counter is N
    -----------------------------------------------------------------
    for i = num_windows, 1, -1 do
        local name = "findWindow" .. i
        actions:add_condition(name, {
            windowsRemaining = i,
            hasTarget        = false,
        })
        actions:add_reaction(name, {
            hasTarget = true,
        })
        actions:set_weight(name, 2)
    end

    -----------------------------------------------------------------
    --  walkToWindow – move next to the current target
    -----------------------------------------------------------------
    actions:add_condition('walkToWindow', {
        hasTarget  = true,
        nearWindow = false,
    })
    actions:add_reaction('walkToWindow', {
        nearWindow = true,
    })
    actions:set_weight('walkToWindow', 2)

    -----------------------------------------------------------------
    --  equipTools – put hammer in primary hand, plank in secondary
    -----------------------------------------------------------------
    actions:add_condition('equipTools', {
        hasHammer = true,
        hasPlank  = true,
        hasNails  = true,
        nearWindow = true,
        equipped   = false,
    })
    actions:add_reaction('equipTools', {
        equipped = true,
    })
    actions:set_weight('equipTools', 1)

    -----------------------------------------------------------------
    --  barricadeWindow<N> – actually barricade the window and decrement the counter
    -----------------------------------------------------------------
    for i = num_windows, 1, -1 do
        local name = "barricadeWindow" .. i
        actions:add_condition(name, {
            windowsRemaining = i,
            hasTarget        = true,
            nearWindow       = true,
            equipped         = true,
        })
        actions:add_reaction(name, {
            hasTarget        = false,
            nearWindow       = false,
            windowsRemaining = i - 1,
        })
        actions:set_weight(name, 5)
    end

    return actions
end

return BarricadeTask