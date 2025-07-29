---@class Lib.Room
local Lib_Room = {}

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_PlayerManager = PlayerManager
local g_EntityConfig = EntityConfig

local Lib = {
    Table = require("lib.table"),
    Math = require("lib.math"),
    Grid = require("lib.grid")
}

--#endregion

---@param gridIdx integer
---@param width integer
---@return Vector
local function GetGridPosition(gridIdx, width)
    local x = gridIdx % width * 40.0 + 40.0
    local y = gridIdx // width * 40.0 + 120.0
    return Vector(x, y)
end

local function get_left0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {4, startColumn}
end

local function get_up0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {startRow, 7}
end

local function get_right0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {4, finalColumn}
end

local function get_down0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {finalRow, 7}
end

local function get_left1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {11, startColumn}
end

local function get_up1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {startRow, 20}
end

local function get_right1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {11, finalColumn}
end

local function get_down1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {finalRow, 20}
end

local function get_ltl_left0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {4, 13}
end

local function get_ltl_up0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {7, 7}
end

local function get_ltr_right0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {4, 14}
end

local function get_lbl_down0_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {8, 7}
end

local function get_lbl_left1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {11, 13}
end

local function get_ltr_up1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {7, 20}
end

local function get_lbr_right1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {11, 14}
end

local function get_lbr_down1_door_coord(startRow, startColumn, finalRow, finalColumn)
    return {8, 20}
end

---Increasing by one so that we only occupy the array part in lua
local s_DoorSlotGridIndexMap = {
    [DoorSlot.LEFT0 + 1] = {RoomShape.ROOMSHAPE_LTL, get_left0_door_coord, get_ltl_left0_door_coord},
    [DoorSlot.UP0 + 1] = {RoomShape.ROOMSHAPE_LTL, get_up0_door_coord, get_ltl_up0_door_coord},
    [DoorSlot.RIGHT0 + 1] = {RoomShape.ROOMSHAPE_LTR, get_right0_door_coord, get_ltr_right0_door_coord},
    [DoorSlot.DOWN0 + 1] = {RoomShape.ROOMSHAPE_LBL, get_down0_door_coord, get_lbl_down0_door_coord},
    [DoorSlot.LEFT1 + 1] = {RoomShape.ROOMSHAPE_LBL, get_left1_door_coord, get_lbl_left1_door_coord},
    [DoorSlot.UP1 + 1] = {RoomShape.ROOMSHAPE_LTR, get_up1_door_coord, get_ltr_up1_door_coord},
    [DoorSlot.RIGHT1 + 1] = {RoomShape.ROOMSHAPE_LBR, get_right1_door_coord, get_lbr_right1_door_coord},
    [DoorSlot.DOWN1 + 1] = {RoomShape.ROOMSHAPE_LBR, get_down1_door_coord, get_lbr_down1_door_coord},
}

local function get_door_slot_coordinates(doorSlot, width, height, shape)
    if not (DoorSlot.LEFT0 <= doorSlot and doorSlot < DoorSlot.NUM_DOOR_SLOTS) then
        doorSlot = DoorSlot.LEFT0
    end

    local doorSlotInfo = s_DoorSlotGridIndexMap[doorSlot + 1]
    if doorSlotInfo[1] == shape then
        return doorSlotInfo[3]()
    end

    local startRow = 0
    local startColumn = 0
    local finalRow = height - 1
    local finalColumn = width - 1

    if shape == RoomShape.ROOMSHAPE_IH or shape == RoomShape.ROOMSHAPE_IIH then
        startRow = 3
        finalRow = height - 4
    elseif shape == RoomShape.ROOMSHAPE_IV or shape == RoomShape.ROOMSHAPE_IIV then
        startColumn = 4
        finalColumn = width - 5
    end

    return doorSlotInfo[2](startRow, startColumn, finalRow, finalColumn)
end

---@param doorSlot DoorSlot
---@param width integer
---@param height integer
---@param shape RoomShape
---@return integer
local function GetDoorGridIndex(doorSlot, width, height, shape)
    local coordinates = get_door_slot_coordinates(doorSlot, width, height, shape)
    return Lib.Grid.GetGridIdxFromCoordinates(Vector(coordinates[1], coordinates[2]), width)
end

--#region Entity Queries

local s_NonSavableBombs = Lib.Table.CreateDictionary({
    BombVariant.BOMB_THROWABLE, BombVariant.BOMB_ROCKET, BombVariant.BOMB_ROCKET_GIGA
})

local function is_storing_game_state()
    return false -- cannot be detected
end

local function should_save_bomb(variant)
    if s_NonSavableBombs[variant] then
        return false
    end

    return true
end

local function should_save_pickup(variant)
    return variant ~= PickupVariant.PICKUP_THROWABLEBOMB
end

---@param variant integer
---@param subType integer
---@param spawnerType EntityType
---@return boolean
local function should_save_effect(variant, subType, spawnerType)
    if variant == EffectVariant.SMOKE_CLOUD then
        return spawnerType == EntityType.ENTITY_NULL
    end

    if variant == EffectVariant.PORTAL_TELEPORT then
        return subType > 899 or is_storing_game_state()
    end

    if variant == EffectVariant.TALL_LADDER then
        return subType == 1 and is_storing_game_state()
    end

    return false
end

---@param entityType EntityType | integer
---@param variant integer
---@param subType integer
---@param spawnerType EntityType | integer
---@param clearedRoom boolean
---@return boolean
local function should_save_npc(entityType, variant, subType, spawnerType, clearedRoom)
    if entityType == EntityType.ENTITY_SHOPKEEPER then
        return true
    end

    if entityType == EntityType.ENTITY_FIREPLACE then
        return variant ~= 10
    end

    if entityType == EntityType.ENTITY_MOVABLE_TNT then
        return true
    end

    if entityType == EntityType.ENTITY_PITFALL then
        return spawnerType == EntityType.ENTITY_NULL
    end

    if entityType == EntityType.ENTITY_MINECART then
        return variant ~= 10
    end

    if entityType == EntityType.ENTITY_GIDEON then
        return subType ~= 1 and clearedRoom
    end

    if entityType == EntityType.ENTITY_GENERIC_PROP then
        return true
    end

    return false
end

---@param entityType EntityType | integer
---@param variant integer
---@param subType integer
---@param spawnerType EntityType | integer
---@param clearedRoom boolean
---@return boolean
local function ShouldSaveEntity(entityType, variant, subType, spawnerType, clearedRoom)
    if entityType == EntityType.ENTITY_BOMB then
        return should_save_bomb(variant)
    end

    if entityType == EntityType.ENTITY_SLOT then
        return true
    end

    if entityType == EntityType.ENTITY_PICKUP then
        return should_save_pickup(variant)
    end

    if entityType == EntityType.ENTITY_EFFECT then
        return should_save_effect(variant, subType, spawnerType)
    end

    return should_save_npc(entityType, variant, subType, spawnerType, clearedRoom)
end

local function return_true()
    return true
end

local function return_false()
    return false
end

---@param variant integer
---@return boolean
local function is_poky_persistent(variant)
    return variant ~= 0
end

local s_PersistentRoomEntity = {
    [EntityType.ENTITY_STONEHEAD] = return_true,
    [EntityType.ENTITY_GAPING_MAW] = return_true,
    [EntityType.ENTITY_BROKEN_GAPING_MAW] = return_true,
    [EntityType.ENTITY_CONSTANT_STONE_SHOOTER] = return_true,
    [EntityType.ENTITY_BRIMSTONE_HEAD] = return_true,
    [EntityType.ENTITY_POKY] = is_poky_persistent,
    [EntityType.ENTITY_WALL_HUGGER] = return_true,
    [EntityType.ENTITY_QUAKE_GRIMACE] = return_true,
    [EntityType.ENTITY_BOMB_GRIMACE] = return_true,
    [EntityType.ENTITY_GRUDGE] = return_true,
    [EntityType.ENTITY_BALL_AND_CHAIN] = return_true,
    [EntityType.ENTITY_SPIKEBALL] = return_true,
    [EntityType.ENTITY_MINECART] = return_true,
    default = return_false,
}

---@param entityType EntityType | integer
---@param variant integer
---@return boolean
function IsPersistentRoomEntity(entityType, variant)
    local PersistentRoomEntity = s_PersistentRoomEntity[entityType] or s_PersistentRoomEntity.default
    return PersistentRoomEntity(variant)
end

--#endregion

--#region RoomType Behavior

local s_VariantToHeartType = {
    [0] = HeartSubType.HEART_FULL,
    [1] = HeartSubType.HEART_ETERNAL,
    [16] = HeartSubType.HEART_ETERNAL,
    [6] = HeartSubType.HEART_BLACK,
    [13] = HeartSubType.HEART_BLACK,
    [12] = HeartSubType.HEART_SOUL,
    [23] = HeartSubType.HEART_BONE,
}

local s_VariantToHeartType_Greed = {
    [0] = HeartSubType.HEART_FULL,
    [4] = HeartSubType.HEART_SOUL,
    [5] = HeartSubType.HEART_BLACK,
    [24] = HeartSubType.HEART_ETERNAL,
    [25] = HeartSubType.HEART_HALF
}

---@param roomData RoomConfigRoom
---@return HeartSubType? heartType
local function GetSuperSecretHeartType(roomData)
    local roomVariant = roomData.Variant

    local switchTable = g_Game:IsGreedMode() and s_VariantToHeartType_Greed or s_VariantToHeartType
    ---@type HeartSubType?
    local heartSubType = switchTable[roomVariant]

    if heartSubType and not Lib.EntityPickup.IsAvailable(PickupVariant.PICKUP_HEART, heartSubType) then
        heartSubType = nil
    end

    return heartSubType
end

--#endregion

---@return boolean
local function should_ignore_angel_chance_penalty()
    if g_Level:GetAngelRoomChance() > 0.0 then
        return true
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_ACT_OF_CONTRITION) and g_Game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_SPAWNED) then
        return true
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) then
        return true
    end

    return false
end

local function should_apply_angel_chance_penalty()
    return not g_Game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_SPAWNED) or g_Game:GetDevilRoomDeals() ~= 0
end

---@return number
local function GetAngelRoomChance()
    local chance = 0.5
    if not g_Game:GetStateFlag(GameStateFlag.STATE_DEVILROOM_VISITED) and not g_Game:GetStateFlag(GameStateFlag.STATE_FAMINE_SPAWNED) then
        chance = 1.0
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_1) then
        chance = chance + (1.0 - chance) * 0.25
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_2) then
        chance = chance + (1.0 - chance) * 0.25
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BOOK_OF_VIRTUES) then
        chance = chance + (1.0 - chance) * 0.25
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_ROSARY_BEAD) then
        chance = chance + (1.0 - chance) * 0.5
    end

    if g_Game:GetDonationModAngel() > 9 then
        chance = chance + (1.0 - chance) * 0.5
    end

    if g_Level:GetStateFlag(LevelStateFlag.STATE_EVIL_BUM_KILLED) then
        chance = chance + (1.0 - chance) * 0.25
    end

    if g_Level:GetStateFlag(LevelStateFlag.STATE_BUM_LEFT) ~= g_Level:GetStateFlag(LevelStateFlag.STATE_EVIL_BUM_LEFT) then
        if g_Level:GetStateFlag(LevelStateFlag.STATE_BUM_LEFT) then
            chance = chance + (1.0 - chance) * 0.1
        end

        if g_Level:GetStateFlag(LevelStateFlag.STATE_EVIL_BUM_LEFT) then
            chance = chance - (1.0 - chance) * 0.1
        end
    end

    if should_ignore_angel_chance_penalty() then
        chance = chance + (1.0 - chance) * g_Level:GetAngelRoomChance()
    elseif should_apply_angel_chance_penalty() then
        chance = 0.0
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_EUCHARIST) then
        chance = 77.0
    end

    return Lib.Math.Clamp(chance, 0.0, 1.0)
end

---@param spawn RoomConfig_Spawn
---@return RoomConfig_Entry?
local function get_highest_weight_entry(spawn)
    local bestWeight = 0.0
    local highestEntry = nil

    local entries = spawn.Entries
    for i = 0, spawn.EntryCount - 1, 1 do
        ---@type RoomConfig_Entry
---@diagnostic disable-next-line: assign-type-mismatch
        local entry = entries:Get(i)
        if entry.Weight >= bestWeight then
            bestWeight = entry.Weight
            highestEntry = entry
        end
    end

    return highestEntry
end

---@param spawn RoomConfig_Spawn
---@return BossType | integer
local function get_spawn_boss_id(spawn)
    local entry = get_highest_weight_entry(spawn)
    if not entry then
        return 0
    end

    local entityConfig = g_EntityConfig.GetEntity(entry.Type, entry.Variant, entry.Subtype)
    if not entityConfig then
        return 0
    end

    return entityConfig:GetBossID()
end

---@param roomData RoomConfigRoom
---@return integer|BossType
---@return integer|BossType
local function GetBossID(roomData)
    local bossId = 0
    local secondBossId = 0

    local spawns = roomData.Spawns
    for i = roomData.SpawnCount - 1, 0, -1 do
        local currentBossId = get_spawn_boss_id(spawns:Get(i))
        if currentBossId == 0 then
            goto continue
        end

        if bossId == 0 then
            bossId = currentBossId
        elseif currentBossId ~= bossId then
            secondBossId = currentBossId
        end
        ::continue::
    end

    return bossId, secondBossId
end

--#region Module

Lib_Room.GetGridPosition = GetGridPosition
Lib_Room.GetDoorGridIndex = GetDoorGridIndex
Lib_Room.ShouldSaveEntity = ShouldSaveEntity
Lib_Room.IsPersistentRoomEntity = IsPersistentRoomEntity
Lib_Room.GetSuperSecretHeartType = GetSuperSecretHeartType
Lib_Room.GetAngelRoomChance = GetAngelRoomChance
Lib_Room.GetBossID = GetBossID

--#endregion

return Lib_Room