---@class RoomDataMorph
local RoomDataMorph = {}

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_PlayerManager = PlayerManager
local g_RoomConfig = RoomConfig

local Lib = {
    Level = require("lib.level"),
    RoomConfig = require("lib.room_config"),
}

--#endregion

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

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@return boolean
local function ShouldForceMoreOptions(roomDesc, roomData)
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
local function GetMoreOptionsRoomData(roomData, seed)
    local rng = RNG(seed, 1)
    local subType = roomData.Subtype == 2 and 3 or 1

    local reduceWeight = false -- this would normally be true but since we are predicting we cannot reduce the weight
    local optionalStage = Isaac.GetCurrentStageConfigId()

    return Lib.RoomConfig.GetRandomRoomFromOptionalStage(g_RoomConfig, rng:Next(), reduceWeight, optionalStage, StbType.SPECIAL_ROOMS, RoomType.ROOM_TREASURE, roomData.Shape, 0, -1, 1, 10, roomData.Doors, subType)
end

if DATAMINER_DEBUG_MODE then
    local old_get_more_options_room_data = GetMoreOptionsRoomData
    ---@param roomData RoomConfigRoom
    ---@param seed integer
    ---@return RoomConfigRoom?
    GetMoreOptionsRoomData = function(roomData, seed)
        assert(roomData.Subtype == 0 or roomData.Subtype == 2, "attempted to get more option room on invalid room subtype")
        return old_get_more_options_room_data(roomData, seed)
    end
end

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@return integer
local function get_surprise_miniboss_id(roomDesc, roomData)
    if roomData.Type == RoomType.ROOM_DEVIL then
        return RoomSubType.MINIBOSS_KRAMPUS
    end

    local greedSubtype = roomDesc.m_GreedSubtype
    if greedSubtype ~= 0 then
        return greedSubtype
    end

    greedSubtype = g_Game:GetStateFlag(GameStateFlag.STATE_GREED_SPAWNED) and RoomSubType.MINIBOSS_SUPER_GREED or RoomSubType.MINIBOSS_GREED
    return greedSubtype
end

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param seed integer
---@return RoomConfigRoom?
local function GetSurpriseMinibossData(roomDesc, roomData, seed)
    local rng = RNG(seed, 1)
    local roomSubType = get_surprise_miniboss_id(roomDesc, roomData)

    local reduceWeight = false -- this would normally be true but since we are predicting we cannot reduce the weight
    return g_RoomConfig.GetRandomRoom(rng:Next(), reduceWeight, StbType.SPECIAL_ROOMS, RoomType.ROOM_MINIBOSS, roomData.Shape, 0, -1, 1, 1, roomData.Doors, roomSubType, 0)
end

--#region Module

RoomDataMorph.ShouldForceMoreOptions = ShouldForceMoreOptions
RoomDataMorph.GetMoreOptionsRoomData = GetMoreOptionsRoomData
RoomDataMorph.GetSurpriseMinibossData = GetSurpriseMinibossData

--#endregion

return RoomDataMorph