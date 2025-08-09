-- File: tasks/scavenge.lua
-- --------------------------------------------------------------
--  Defines reusable actions for scavenging, including finding,
--  entering, and looting buildings.
-- --------------------------------------------------------------
local Action = require("Action")

local ScavengeTask = {}

function ScavengeTask.create_actions()
    local actions = Action()

    -----------------------------------------------------------------
    --  findUnlootedBuilding
    --  Original Logic: The entire SpiralSearch and Wander logic.
    --  Condition: We want to loot but don't have a target building yet.
    --  Effect: We now have a target building.
    -----------------------------------------------------------------
    actions:add_condition('findUnlootedBuilding', {
        wantsToLoot = true,
        hasBuildingTarget = false
    })
    actions:add_reaction('findUnlootedBuilding', {
        hasBuildingTarget = true
    })
    actions:set_weight('findUnlootedBuilding', 15) -- Searching a large area is very costly and time-consuming

    -----------------------------------------------------------------
    --  moveToBuilding
    --  Original Logic: self.parent:walkTo(self.parent:FindClosestOutsideSquare(Square))
    --  Condition: We have a target building but are not yet at its perimeter.
    --  Effect: We have arrived at the building.
    -----------------------------------------------------------------
    actions:add_condition('moveToBuilding', {
        hasBuildingTarget = true,
        atBuilding = false
    })
    actions:add_reaction('moveToBuilding', {
        atBuilding = true
    })
    actions:set_weight('moveToBuilding', 5) -- Travel cost depends on distance

    -----------------------------------------------------------------
    --  enterBuilding
    --  (This action would be the GOAP equivalent of AttemptEntryIntoBuildingTask)
    --  Condition: We are at the building but still outside.
    --  Effect: We are now inside the building.
    -----------------------------------------------------------------
    actions:add_condition('enterBuilding', {
        hasBuildingTarget = true,
        atBuilding = true,
        isInside = false
    })
    actions:add_reaction('enterBuilding', {
        isInside = true,
    })
    actions:set_weight('enterBuilding', 2)

    -----------------------------------------------------------------
    --  lootBuilding
    --  (This action would be the GOAP equivalent of LootTask)
    --  Condition: We are inside and want to find supplies.
    --  Effect: Increases the number of supplies found.
    -----------------------------------------------------------------
    actions:add_condition('lootBuilding', {
        isInside = true,
        suppliesFound = 0
    })
    actions:add_reaction('lootBuilding', {
        suppliesFound = 5
    })
    actions:set_weight('lootBuilding', 8)

    return actions
end

return ScavengeTask