-- File: tasks/scavenge.lua
-- --------------------------------------------------------------
--  Defines a complete and unified set of reusable actions for
--  the entire scavenging process: finding a building, entering
--  it via multiple methods, and looting containers inside.
-- --------------------------------------------------------------
local Action = require("goap.Action")

local ScavengeTask = {}

-- Factory function to create all scavenging-related actions.
-- @param containers_to_loot (optional, integer) The number of containers to search.
--        If not provided, looting actions will not be created.
function ScavengeTask.create_actions(containers_to_loot)
    local actions = Action()

    -----------------------------------------------------------------
    --  Phase 1: Finding a Building
    -----------------------------------------------------------------
    actions:add_condition('findUnlootedBuilding', {
        wantsToLoot = true,
        hasBuildingTarget = false
    })
    actions:add_reaction('findUnlootedBuilding', {
        hasBuildingTarget = true
    })
    actions:set_weight('findUnlootedBuilding', 15)

    actions:add_condition('moveToBuilding', {
        hasBuildingTarget = true,
        atBuilding = false
    })
    actions:add_reaction('moveToBuilding', {
        atBuilding = true
    })
    actions:set_weight('moveToBuilding', 5)

    -----------------------------------------------------------------
    --  Phase 2: Entering the Building (Multiple Methods)
    -----------------------------------------------------------------
    actions:add_condition('enterBuildingViaDoor', {
        atBuilding = true, isInside = false, entryMethod = "door"
    })
    actions:add_reaction('enterBuildingViaDoor', { isInside = true })
    actions:set_weight('enterBuildingViaDoor', 2)

    actions:add_condition('enterBuildingViaWindow', {
        atBuilding = true, isInside = false, entryMethod = "window"
    })
    actions:add_reaction('enterBuildingViaWindow', { isInside = true })
    actions:set_weight('enterBuildingViaWindow', 5)

    actions:add_condition('enterBuildingByBreaching', {
        atBuilding = true, isInside = false, entryMethod = "breach", hasBreachingTool = true
    })
    actions:add_reaction('enterBuildingByBreaching', { isInside = true })
    actions:set_weight('enterBuildingByBreaching', 10)

    -----------------------------------------------------------------
    --  Phase 3: Looting Containers (Loop created if needed)
    -----------------------------------------------------------------
    if containers_to_loot and containers_to_loot > 0 then
        for i = containers_to_loot, 1, -1 do
            local find_name = "findContainer" .. i
            actions:add_condition(find_name, {
                isInside = true, hasRoomInBag = true, containersToLoot = i, hasContainerTarget = false,
            })
            actions:add_reaction(find_name, { hasContainerTarget = true })
            actions:set_weight(find_name, 3)

            local walk_to_name = "walkToContainer" .. i
            actions:add_condition(walk_to_name, {
                containersToLoot = i, hasContainerTarget = true, atContainer = false,
            })
            actions:add_reaction(walk_to_name, { atContainer = true })
            actions:set_weight(walk_to_name, 2)

            local loot_name = "lootContainer" .. i
            actions:add_condition(loot_name, {
                isInside = true, hasRoomInBag = true, containersToLoot = i, hasContainerTarget = true, atContainer = true,
            })
            actions:add_reaction(loot_name, {
                containersToLoot = i - 1, hasContainerTarget = false, atContainer = false,
            })
            actions:set_weight(loot_name, 4)
        end
    end

    return actions
end

return ScavengeTask