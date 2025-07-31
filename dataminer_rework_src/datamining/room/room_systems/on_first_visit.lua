---@class Room.OnFirstRoomVisit
local OnRoomFirstVisit = {}

--#region Dependencies

local SpawnCommands = require("datamining.entity.spawn_commands")
local VirtualRoomQueries = require("datamining.room.virtual_room_queries")

--#endregion

---@param room VirtualRoom
---@param spawnCommands SpawnCommands
local function SpawnDiceFloor(room, spawnCommands)
    local rng = RNG(room.m_RoomDescriptor.SpawnSeed, 35)
    local diceFloorSubtype = rng:RandomInt(6)
    local position = VirtualRoomQueries.GetCenterPos(room)

    SpawnCommands.SpawnEntity(spawnCommands, EntityType.ENTITY_EFFECT, EffectVariant.DICE_FLOOR, diceFloorSubtype, Random(), position, Vector(0, 0), nil)
end

--#region Module

OnRoomFirstVisit.SpawnDiceFloor = SpawnDiceFloor

--#endregion

return OnRoomFirstVisit