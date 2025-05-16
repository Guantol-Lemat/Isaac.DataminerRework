---@class RoomLoader
local RoomLoader = {}

---@class VirtualRoom
---@field roomDescriptor RoomDescriptor
---@field roomType RoomType
---@field roomIdx GridRooms | integer
---@field width integer
---@field height integer
---@field doorGridIdx integer[]
---@field tintedRockIdx integer
---@field layoutData LayoutData

---@class LayoutData
---@field entities EntitySpawnDesc[]
---@field gridEntities GridSpawnDesc[]

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_PlayerManager = PlayerManager
local g_RoomConfig = RoomConfig

local Lib = {
    Level = require("dataminer_rework_src.lib.level"),
    Room = require("dataminer_rework_src.lib.room"),
    RoomConfig = require("dataminer_rework_src.lib.room_config")
}

--#endregion

local function NewVirtualRoom()
    ---@type VirtualRoom
    local virtualRoom = {
---@diagnostic disable-next-line: assign-type-mismatch
        roomDescriptor = nil,
        roomType = RoomType.ROOM_DEFAULT,
        roomIdx = 0,
        width = 0,
        height = 0,
        doorGridIdx = {},
        tintedRockIdx = -1,
        layoutData = {entities = {}, gridEntities = {}}
    }
end

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
local function InitRoomData(virtualRoom, roomDesc, roomData)
    virtualRoom.width = roomData.Width + 2
    virtualRoom.height = roomData.Height + 2

    for i = 1, DoorSlot.NUM_DOOR_SLOTS, 1 do
        virtualRoom.doorGridIdx[i] = Lib.Room.GetDoorGridIndex(i - 1, virtualRoom.width, virtualRoom.height, roomDesc.Data.Shape)
    end

    virtualRoom.roomDescriptor = roomDesc
    virtualRoom.roomType = roomDesc.Data.Type
    virtualRoom.roomIdx = roomDesc.SafeGridIndex
end

--#region GetRoomData

---@return boolean
local function should_clear_surprise_miniboss()
    return g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_RIB_OF_GREED)
end

---@param seed integer
---@return boolean
local function should_apply_broken_glasses_effect(seed)
    local rng = RNG(seed, 61)
    return rng:RandomInt(2) < g_PlayerManager.GetTotalTrinketMultiplier(TrinketType.TRINKET_BROKEN_GLASSES)
end

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@return boolean
local function should_force_more_options(roomDesc, roomData)
    if not (roomData.Type == RoomType.ROOM_TREASURE and roomDesc.VisitedCount == 0) then
        return false
    end

    local roomSubType = roomData.Subtype
    if not (roomSubType == 0 or roomSubType == 2) then
        return false
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_MORE_OPTIONS) then
        return true
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_BROKEN_GLASSES) and not Lib.Level.IsAltPath(g_Level) then
        if should_apply_broken_glasses_effect(roomDesc.SpawnSeed) then
            return true
        end
    end

    return false
end

---@param roomData RoomConfigRoom
---@param seed integer
---@return RoomConfigRoom?
local function get_more_options_room_data(roomData, seed)
    local rng = RNG(seed, 1)
    local roomSubType = roomData.Subtype

    assert(roomSubType == 0 or roomSubType == 2, "attempted to get more option room on invalid room subtype")
    local subType = roomSubType == 2 and 3 or 1

    local reduceWeight = false -- this would normally be true but since we are predicting we cannot reduce the weight
    local optionalStage = Isaac.GetCurrentStageConfigId()

    return Lib.RoomConfig.GetRandomRoomFromOptionalStage(g_RoomConfig, rng:Next(), reduceWeight, optionalStage, StbType.SPECIAL_ROOMS, RoomType.ROOM_TREASURE, roomData.Shape, 0, -1, 1, 10, roomData.Doors, subType)
end

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@return integer
local function get_surprise_miniboss_id(roomDesc, roomData)
    if roomData.Type == RoomType.ROOM_DEVIL then
        return RoomSubType.MINIBOSS_KRAMPUS
    end

    local greedSubType = 0 -- this field is inaccessible so we assume it is 0 and proceed to the next check
    if greedSubType ~= 0 then
        return greedSubType
    end

    greedSubType = g_Game:GetStateFlag(GameStateFlag.STATE_GREED_SPAWNED) and RoomSubType.MINIBOSS_SUPER_GREED or RoomSubType.MINIBOSS_GREED
    return greedSubType
end

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param seed integer
---@return RoomConfigRoom?
local function get_random_surprise_miniboss_data(roomDesc, roomData, seed)
    local rng = RNG(seed, 1)
    local roomSubType = get_surprise_miniboss_id(roomDesc, roomData)

    local reduceWeight = false -- this would normally be true but since we are predicting we cannot reduce the weight
    return g_RoomConfig.GetRandomRoom(rng:Next(), reduceWeight, StbType.SPECIAL_ROOMS, RoomType.ROOM_MINIBOSS, roomData.Shape, 0, -1, 1, 1, roomData.Doors, roomSubType, 0)
end

---@param roomDesc RoomDescriptor
---@return RoomConfigRoom?
local function get_surprise_miniboss_data(roomDesc)
    local overrideData = roomDesc.OverrideData
    if overrideData and overrideData.StageID == StbType.SPECIAL_ROOMS and overrideData.Type == RoomType.ROOM_MINIBOSS then
        return overrideData
    end

    return get_random_surprise_miniboss_data(roomDesc, roomDesc.Data, roomDesc.SpawnSeed)
end

---@param roomDesc RoomDescriptor
---@return RoomConfigRoom
local function GetRoomData(roomDesc)
    local roomData = roomDesc.Data
    local flags = roomDesc.Flags

    if should_clear_surprise_miniboss() then
        flags = flags & ~RoomDescriptor.FLAG_SURPRISE_MINIBOSS
    end

    if should_force_more_options(roomDesc, roomData) then
        roomData = get_more_options_room_data(roomData, roomDesc.SpawnSeed) or roomData
    end

    if flags & RoomDescriptor.FLAG_SURPRISE_MINIBOSS ~= 0 then
        roomData = get_surprise_miniboss_data(roomDesc) or roomData
    end

    return roomData
end

--#endregion

--#region GetLayoutData

---@param position Vector
---@param gridWidth integer
---@return integer gridIdx
local function get_grid_idx(position, gridWidth)
    return position.X + position.Y * gridWidth
end

---@param roomDesc RoomDescriptor
---@param gridIdx integer
local function is_restricted_grid_idx(roomDesc, gridIdx)
    local restrictedGrids = roomDesc:GetRestrictedGridIndexes()
    for _, value in ipairs(restrictedGrids) do
        if value == gridIdx then
            return true
        end
    end

    return false
end

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawn RoomConfig_Spawn
---@param rng RNG
---@return SpawnDesc?
local function get_spawn_desc(virtualRoom, roomDesc, roomData, spawn, rng)
    local randomFloat = rng:RandomFloat()
    if spawn.EntryCount == 0 then
        return
    end

    local spawnEntry = spawn:PickEntry(randomFloat)
    local gridIdx = get_grid_idx(Vector(spawn.X + 1, spawn.Y + 1), roomData.Width + 2)
    if is_restricted_grid_idx(roomDesc, gridIdx) then
        return
    end

    return -- TODO
end

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@return LayoutData
local function GetRoomLayoutData(virtualRoom, roomDesc, roomData)
    ---@type LayoutData
    local layoutData = {entities = {}, gridEntities = {}}

    local rng = RNG(roomDesc.SpawnSeed, 11)
    local spawns = roomData.Spawns

    for i = 0, roomData.SpawnCount, 1 do
        local spawnDesc = get_spawn_desc(virtualRoom, roomDesc, roomData, spawns:Get(i), rng)
    end

    return layoutData
end

--#endregion

--#region Module

RoomLoader.GetRoomData = GetRoomData


--#endregion

return RoomLoader