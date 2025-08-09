-- File: tasks/scavenge.lua
-- --------------------------------------------------------------
--  Defines reusable actions for scavenging, including finding,
--  entering, and looting buildings.
-- --------------------------------------------------------------
local Action = require("Action")

local ScavengeTask = {}

-- Factory function to create the actions for scavenging.
-- @param containers_to_loot (integer) The number of containers to search.
function ScavengeTask.create_actions(containers_to_loot)
    containers_to_loot = containers_to_loot or 1 -- Default to 1 if not provided
    assert(type(containers_to_loot) == "number" and containers_to_loot > 0)

    local actions = Action()

    -- [[ Actions from previous conversions: findUnlootedBuilding, moveToBuilding, enterBuilding ]]
    -- ... (assuming they are here) ...
    actions:add_condition('findUnlootedBuilding', { wantsToLoot = true, hasBuildingTarget = false }); actions:add_reaction('findUnlootedBuilding', { hasBuildingTarget = true }); actions:set_weight('findUnlootedBuilding', 15)
    actions:add_condition('moveToBuilding', { hasBuildingTarget = true, atBuilding = false }); actions:add_reaction('moveToBuilding', { atBuilding = true }); actions:set_weight('moveToBuilding', 5)
    actions:add_condition('enterBuilding', { hasBuildingTarget = true, atBuilding = true, isInside = false }); actions:add_reaction('enterBuilding', { isInside = true }); actions:set_weight('enterBuilding', 2)

    -- New actions for the Loot task, converted from LootCategoryTask.lua
    for i = containers_to_loot, 1, -1 do
        -----------------------------------------------------------------
        --  1. findContainer<N>
        --  Original Logic: The large nested loop searching for unlooted containers.
        --  Condition: We are inside, have room, and need to loot more containers.
        --  Effect: We have identified a specific container to loot.
        -----------------------------------------------------------------
        local find_name = "findContainer" .. i
        actions:add_condition(find_name, {
            isInside = true,
            hasRoomInBag = true,
            containersToLoot = i,
            hasContainerTarget = false,
        })
        actions:add_reaction(find_name, {
            hasContainerTarget = true
        })
        actions:set_weight(find_name, 3) -- Searching within a building is cheaper than finding a new building

        -----------------------------------------------------------------
        --  2. walkToContainer<N>
        --  Original Logic: self.parent:walkTo(trySquare)
        --  Condition: We have a target container but are not next to it.
        --  Effect: We are now at the container.
        -----------------------------------------------------------------
        local walk_to_name = "walkToContainer" .. i
        actions:add_condition(walk_to_name, {
            containersToLoot = i,
            hasContainerTarget = true,
            atContainer = false,
        })
        actions:add_reaction(walk_to_name, {
            atContainer = true
        })
        actions:set_weight(walk_to_name, 2) -- Walking inside a building is usually short

        -----------------------------------------------------------------
        --  3. lootContainer<N>
        --  Original Logic: ISInventoryTransferAction and related checks.
        --  Condition: We are at a container, ready to loot.
        --  Effect: The container is looted (counter decrements).
        -----------------------------------------------------------------
        local loot_name = "lootContainer" .. i
        actions:add_condition(loot_name, {
            isInside = true,
            hasRoomInBag = true,
            containersToLoot = i,
            hasContainerTarget = true,
            atContainer = true,
        })
        actions:add_reaction(loot_name, {
            containersToLoot = i - 1, -- We have one less container to find
            hasContainerTarget = false, -- Reset target states to find the next one
            atContainer = false,
        })
        actions:set_weight(loot_name, 4) -- Looting a container takes time
    end

    return actions
end

return ScavengeTask