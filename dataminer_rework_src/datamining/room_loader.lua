---@class RoomLoader
local RoomLoader = {}

---@class LayoutData
---@field entities EntitySpawnDesc[]
---@field gridEntities GridSpawnDesc[]

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_PlayerManager = PlayerManager
local g_RoomConfig = RoomConfig
local g_PersistentGameData = Isaac.GetPersistentGameData()

local Lib = {
    Level = require("lib.level"),
    Room = require("lib.room"),
    RoomConfig = require("lib.room_config")
}

local SpawnReader = require("datamining.spawn_reader")

--#endregion

---Used Pascal case to match the game's userdata fields
---@class VirtualRoomDescriptor
---@field GridIndex GridRooms | integer
---@field SafeGridIndex GridRooms | integer
---@field m_Dimension Dimension
---@field Data RoomConfigRoom?
---@field OverrideData RoomConfigRoom?
---@field Flags integer
---@field Doors integer[]
---@field VisitedCount integer
---@field DecorationSeed integer
---@field SpawnSeed integer
---@field AwardSeed integer
---@field BossDeathSeed integer
---@field m_GreedSubtype integer
---@field m_RestrictedGridIndexes table<integer, boolean>

---@param roomDesc RoomDescriptor
local function CreateVirtualRoomDescriptor(roomDesc)
    ---@type VirtualRoomDescriptor
    local virtualRoomDesc = {
        GridIndex = roomDesc.GridIndex,
        SafeGridIndex = roomDesc.SafeGridIndex,
        m_Dimension = roomDesc:GetDimension(),
        Data = roomDesc.Data,
        OverrideData = roomDesc.OverrideData,
        Flags = roomDesc.Flags,
        Doors = {},
        VisitedCount = roomDesc.VisitedCount,
        DecorationSeed = roomDesc.DecorationSeed,
        SpawnSeed = roomDesc.SpawnSeed,
        AwardSeed = roomDesc.AwardSeed,
        BossDeathSeed = roomDesc.BossDeathSeed,
        m_GreedSubtype = 0,
        m_RestrictedGridIndexes = {}
    }

    local doors = roomDesc.Doors
    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1, 1 do
        virtualRoomDesc.Doors[i] = doors[i]
    end

    for _, gridIdx in ipairs(roomDesc:GetRestrictedGridIndexes()) do
        virtualRoomDesc.m_RestrictedGridIndexes[gridIdx] = true
    end

    return virtualRoomDesc
end

---@param roomDesc VirtualRoomDescriptor
---@param rng RNG
local function InitSeeds(roomDesc, rng)
    roomDesc.DecorationSeed = rng:Next()
    roomDesc.SpawnSeed = rng:Next()
    roomDesc.AwardSeed = rng:Next()
    local bossRNG = RNG(rng:GetSeed(), 66)
    roomDesc.BossDeathSeed = bossRNG:Next()
end

--#region InitRoomData

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
    local subType = roomData.Subtype == 2 and 3 or 1

    local reduceWeight = false -- this would normally be true but since we are predicting we cannot reduce the weight
    local optionalStage = Isaac.GetCurrentStageConfigId()

    return Lib.RoomConfig.GetRandomRoomFromOptionalStage(g_RoomConfig, rng:Next(), reduceWeight, optionalStage, StbType.SPECIAL_ROOMS, RoomType.ROOM_TREASURE, roomData.Shape, 0, -1, 1, 10, roomData.Doors, subType)
end

if DATAMINER_DEBUG_MODE then
    local old_get_more_options_room_data = get_more_options_room_data
    ---@param roomData RoomConfigRoom
    ---@param seed integer
    ---@return RoomConfigRoom?
    get_more_options_room_data = function(roomData, seed)
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
local function get_random_surprise_miniboss_data(roomDesc, roomData, seed)
    local rng = RNG(seed, 1)
    local roomSubType = get_surprise_miniboss_id(roomDesc, roomData)

    local reduceWeight = false -- this would normally be true but since we are predicting we cannot reduce the weight
---@diagnostic disable-next-line: undefined-field
    return g_RoomConfig.GetRandomRoom(rng:Next(), reduceWeight, StbType.SPECIAL_ROOMS, RoomType.ROOM_MINIBOSS, roomData.Shape, 0, -1, 1, 1, roomData.Doors, roomSubType, 0)
end

---@param roomDesc VirtualRoomDescriptor
---@return RoomConfigRoom?
local function get_surprise_miniboss_data(roomDesc)
    local overrideData = roomDesc.OverrideData
    if overrideData and overrideData.StageID == StbType.SPECIAL_ROOMS and overrideData.Type == RoomType.ROOM_MINIBOSS then
        return overrideData
    end

    return get_random_surprise_miniboss_data(roomDesc, roomDesc.Data, roomDesc.SpawnSeed)
end

---@param roomDesc VirtualRoomDescriptor
---@return RoomConfigRoom?
local function InitRoomData(roomDesc)
    if should_clear_surprise_miniboss() then
        roomDesc.Flags = roomDesc.Flags & ~RoomDescriptor.FLAG_SURPRISE_MINIBOSS
    end

    local roomData = roomDesc.Data
    if roomData and should_force_more_options(roomDesc, roomData) then
        roomData = get_more_options_room_data(roomData, roomDesc.SpawnSeed) or roomData
        roomDesc.Data = roomData
    end

    if roomDesc.Flags & RoomDescriptor.FLAG_SURPRISE_MINIBOSS ~= 0 then
        local overrideData = get_surprise_miniboss_data(roomDesc)
        if not overrideData then
            roomDesc.Flags = roomDesc.Flags & ~RoomDescriptor.FLAG_SURPRISE_MINIBOSS
        end

        roomDesc.OverrideData = overrideData
        roomData = overrideData or roomData
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

---@param roomDesc VirtualRoomDescriptor
---@param gridIdx integer
local function is_restricted_grid_idx(roomDesc, gridIdx)
    return not not roomDesc.m_RestrictedGridIndexes[gridIdx]
end

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
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

    return SpawnReader.BuildSpawnDesc(virtualRoom, roomDesc, roomData, gridIdx, spawnEntry, rng:GetSeed(), false)
end

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@return LayoutData
local function LoadRoomLayoutData(virtualRoom, roomDesc, roomData)
    ---@type LayoutData
    local layoutData = {entities = {}, gridEntities = {}}

    local rng = RNG(roomDesc.SpawnSeed, 11)
    local spawns = roomData.Spawns

    for i = 0, roomData.SpawnCount - 1, 1 do
        local spawnDesc = get_spawn_desc(virtualRoom, roomDesc, roomData, spawns:Get(i), rng)
        if not spawnDesc then
            goto continue
        end

        if spawnDesc.spawnType == 1 then
            table.insert(layoutData.entities, spawnDesc.entityDesc)
        elseif spawnDesc.spawnType == 2 then
            table.insert(layoutData.gridEntities, spawnDesc.entityDesc)
        end
        ::continue::
    end

    return layoutData
end

--#endregion

---@param rng RNG
---@param forceAngel boolean
---@param forceDevil boolean
---@return RoomType | integer
local function get_devil_angel_room_type(rng, forceAngel, forceDevil)
    local randomFloat = rng:RandomFloat()

    if forceDevil then
        return RoomType.ROOM_DEVIL
    end

    if forceAngel then
        return RoomType.ROOM_ANGEL
    end

    local roomType = randomFloat < Lib.Room.GetAngelRoomChance() and RoomType.ROOM_ANGEL or RoomType.ROOM_DEVIL
    return roomType
end

---@param roomType RoomType
---@return integer minVariant, integer maxVariant, integer subtype
local function get_devil_angel_room_filter(roomType)
    local minVariant = 0
    local maxVariant = 99

    local curses = g_Level:GetCurses()
    local stage = g_Level:GetStage()
    if curses & LevelCurse.CURSE_OF_LABYRINTH ~= 0 then
        stage = stage + 1
    end

    local stageType = roomType == RoomType.ROOM_ANGEL and 1 or 0
    if stage == LevelStage.STAGE4_2 and g_Level:IsStageAvailable(LevelStage.STAGE5, stageType) and not g_PersistentGameData:Unlocked(Achievement.IT_LIVES) then
        minVariant = 100
        maxVariant = 100
    end

    local subtype = 0
    if roomType == RoomType.ROOM_DEVIL and g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_NUMBER_MAGNET) then
        subtype = RoomSubType.DEVIL_NUMBER_MAGNET
    end

    return minVariant, maxVariant, subtype
end

if REPENTOGON then
    local old_get_devil_angel_room_filter = get_devil_angel_room_filter
    ---@param roomType RoomType
    ---@return integer minVariant, integer maxVariant, integer subType
    get_devil_angel_room_filter = function(roomType)
        local minVariant, maxVariant, subtype = old_get_devil_angel_room_filter(roomType)
        if minVariant == 100 and maxVariant == 100 then
            return 100, 100, 666
        end

        return 0, -1, subtype
    end
end

---@param roomData RoomConfigRoom
---@param other RoomConfigRoom
---@param doorSlot DoorSlot
---@return boolean
local function is_valid_entrance(roomData, other, doorSlot)
    if (roomData.Doors & (doorSlot << 1)) == 0 then
        return false
    end

    local oppositeDoorSlot = doorSlot - 2 & 3
    if (other.Doors & (oppositeDoorSlot << 1)) == 0 then
        return false
    end

    return true
end

---@param roomData RoomConfigRoom
---@param other RoomConfigRoom
---@return integer
local function count_devil_angel_room_entrances(roomData, other)
    local validEntrances = 0
    -- Game picks a random room from which to start from, but it uses Random() and it ultimately still counts them all so it's useless
    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1, 1 do
        if is_valid_entrance(roomData, other, i) then
            validEntrances = validEntrances + 1
        end
    end

    return validEntrances
end

---@param rng RNG
---@param roomType RoomType
---@param minVariant integer
---@param maxVariant integer
---@param subtype integer
---@param entrance RoomDescriptor
---@return RoomConfigRoom?
local function get_devil_angel_room_data(rng, roomType, minVariant, maxVariant, subtype, entrance)
    local reduceWeight = false -- this one is actually false in the game
    local roomData = nil

    for i = 1, 10, 1 do
---@diagnostic disable-next-line: undefined-field
        local newRoomData = g_RoomConfig.GetRandomRoom(rng:Next(), reduceWeight, StbType.SPECIAL_ROOMS, roomType, RoomShape.NUM_ROOMSHAPES, minVariant, maxVariant, 1, 10, 0, subtype)
        if not newRoomData then
            goto continue
        end

        roomData = newRoomData
        local entrances = count_devil_angel_room_entrances(entrance.Data, roomData)
        if entrances >= 2 then -- Pick this room if it has more at least 2 valid entrances
            break
        end
        ::continue::
    end

    return roomData
end


local function get_krampus_chance()
    local chance = 0
    if g_Game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_VISITED) then
        chance = 1
        if g_Game:GetDevilRoomDeals() > 0 then
            chance = 3
        end
    end

    return chance
end

---@param rng RNG
---@param minVariant integer
---@param subtype integer
---@return boolean
local function should_force_krampus(rng, roomType, minVariant, subtype)
    if roomType ~= RoomType.ROOM_DEVIL then
        return false
    end

    if not g_PersistentGameData:Unlocked(Achievement.KRAMPUS) then
        return false
    end

    if g_Game:GetStateFlag(GameStateFlag.STATE_KRAMPUS_SPAWNED) or (minVariant == 0 and subtype ~= 0) then -- Only subtype is actually checked but due to how it is changed in Repentogon we also check the minVariant
        return false
    end

    return rng:RandomInt(20) < get_krampus_chance() and minVariant < 100
end

---@param virtualRoomDesc VirtualRoomDescriptor
---@param forceAngel boolean
---@param forceDevil boolean
---@param rng RNG
---@return VirtualRoomDescriptor
local function InitializeDevilAngelRoom(virtualRoomDesc, forceAngel, forceDevil, rng)
    if virtualRoomDesc.Data then
        return virtualRoomDesc
    end

    local roomType = get_devil_angel_room_type(rng, forceAngel, forceDevil)
    local minVariant, maxVariant, subtype = get_devil_angel_room_filter(roomType)

    InitSeeds(virtualRoomDesc, rng)
    local bossRoom = g_Level:GetRooms():Get(g_Level:GetLastBossRoomListIndex())
    virtualRoomDesc.Data = get_devil_angel_room_data(rng, roomType, minVariant, maxVariant, subtype, bossRoom)

    if should_force_krampus(rng, roomType, minVariant, subtype) then
        virtualRoomDesc.Flags = virtualRoomDesc.Flags | RoomDescriptor.FLAG_SURPRISE_MINIBOSS
    end

    return virtualRoomDesc
end

---@param door GridEntityDoor
---@return VirtualRoomDescriptor
local function ResolveDoorTarget(door)
    local virtualRoomDesc = CreateVirtualRoomDescriptor(g_Level:GetRoomByIdx(door.TargetRoomIndex, Dimension.CURRENT))

    if door.TargetRoomIndex == GridRooms.ROOM_DEVIL_IDX then
        local targetRoomType = door.TargetRoomType
        local devilAngelRNG = g_Level:GetDevilAngelRoomRNG()
        local rng = RNG(devilAngelRNG:GetSeed(), devilAngelRNG:GetShiftIdx())
        InitializeDevilAngelRoom(virtualRoomDesc, targetRoomType == RoomType.ROOM_ANGEL, targetRoomType == RoomType.ROOM_DEVIL, rng)
    end

    return virtualRoomDesc
end

--#region Module

RoomLoader.CreateVirtualRoomDescriptor = CreateVirtualRoomDescriptor
RoomLoader.InitSeeds = InitSeeds
RoomLoader.InitRoomData = InitRoomData
RoomLoader.InitializeDevilAngelRoom = InitializeDevilAngelRoom
RoomLoader.LoadRoomLayoutData = LoadRoomLayoutData
RoomLoader.ResolveDoorTarget = ResolveDoorTarget

--#endregion

return RoomLoader