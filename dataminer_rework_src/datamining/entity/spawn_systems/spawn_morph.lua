---@class SpawnMorphSystem
local SpawnMorph = {}

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_PlayerManager = PlayerManager
local g_BossPool = BossPoolManager
local g_PersistentGameData = Isaac.GetPersistentGameData()

local Lib = {
    Grid = require("lib.grid"),
    Level = require("lib.level"),
    Room = require("lib.room"),
    PlayerManager = require("lib.player_manager"),
}

--#endregion

STB_EFFECT = 999

---@param roomData RoomConfigRoom
---@param rng RNG
---@return MorphEntry?
local function DangerousRockMorph(roomData, rng)
    if not (g_Level:GetStageType() == StageType.STAGETYPE_AFTERBIRTH and roomData.Type == RoomType.ROOM_DEFAULT) then
        return
    end

    if rng:RandomInt(10) ~= 0 then
        return
    end

    local stage = g_Level:GetStage()

    if stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2 then
        ---@class MorphEntry
        return {
            Type = EntityType.ENTITY_FIREPLACE,
            Variant = rng:RandomInt(40) == 0 and 1 or 0,
            Subtype = 0,
        }
    elseif stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2 then
        ---@class MorphEntry
        return {
            Type = StbGridType.PIT,
            Variant = 0,
            Subtype = 0,
        }
    elseif stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2 then
        ---@class MorphEntry
        return {
            Type = StbGridType.SPIKES,
            Variant = 0,
            Subtype = 0,
        }
    elseif stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2 then
        ---@class MorphEntry
        return {
            Type = StbGridType.RED_POOP,
            Variant = 0,
            Subtype = 0,
        }
    end
end

---@param roomData RoomConfigRoom
---@param seed integer
---@return MorphEntry?
local function DirtyMindMorph(roomData, seed)
    if roomData.Type == RoomType.ROOM_DUNGEON then
        return
    end

    local rng = RNG(seed, 2)
    local randomPlayer = Lib.PlayerManager.RandomCollectibleOwner(g_PlayerManager, CollectibleType.COLLECTIBLE_DIRTY_MIND, rng:Next())[1]
    if not randomPlayer then
        return
    end

    local chance = math.min(randomPlayer.Luck * 0.005 + 0.0625, 0.1)
    if rng:RandomFloat() > chance then
        return
    end

    ---@class MorphEntry
    return {
        Type = StbGridType.POOP,
        Variant = 0,
        Subtype = 0,
    }
end

---@param rng RNG
---@return MorphEntry?
local function TntMorph(rng)
    if rng:RandomInt(10) ~= 0 then
        return
    end

    ---@class MorphEntry
    local morphEntry = {
        Type = EntityType.ENTITY_MOVABLE_TNT,
        Variant = 0,
        Subtype = 0,
    }
    return morphEntry
end

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@return boolean canSpawn
local function can_spawn_trapdoor(roomDesc, roomData)
    if g_Level:IsNextStageAvailable() then
        return true
    end

    local roomType = roomData.Type
    if roomType == RoomType.ROOM_ERROR or roomType == RoomType.ROOM_SECRET_EXIT then
        return true
    end

    if roomDesc.SafeGridIndex == GridRooms.ROOM_GENESIS_IDX then
        return true
    end

    if (roomType == RoomType.ROOM_BOSS and roomData.Subtype == BossType.MOTHER) then
        return true
    end

    return false
end

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@return MorphEntry?
local function TrapdoorMorph(roomDesc, roomData)
    if not can_spawn_trapdoor(roomDesc, roomData) then
        ---@class MorphEntry
        return {
            Type = StbGridType.COBWEB,
            Variant = 0,
            Subtype = 0,
        }
    end

    if g_Level:HasMirrorDimension() and roomDesc.m_Dimension == Dimension.KNIFE_PUZZLE then
        ---@class MorphEntry
        return {
            Type = StbGridType.DECORATION,
            Variant = 0,
            Subtype = 0,
        }
    end
end

---@param rng RNG
---@return MorphEntry?
local function ShopkeeperMorph(rng)
    if rng:RandomInt(4) == 0 and g_PersistentGameData:Unlocked(Achievement.SPECIAL_SHOPKEEPERS) then
        ---@class MorphEntry
        return {
            Variant = 3,
        }
    end
end

---@param rng RNG
---@return MorphEntry?
local function HangingShopkeeperMorph(rng)
    if rng:RandomInt(4) == 0 and g_PersistentGameData:Unlocked(Achievement.SPECIAL_HANGING_SHOPKEEPERS) then
        ---@class MorphEntry
        return {
            Variant = 4,
        }
    end
end

---@return MorphEntry?
local function DevilStatueMorph()
    if g_BossPool.GetRemovedBosses()[BossType.SATAN] then
        ---@class MorphEntry
        return {
            Type = StbGridType.ROCK,
            Variant = 0,
            Subtype = 1,
        }
    end
end

---@param rng RNG
---@return Vector
local function get_gold_vein_size(rng)
    local stageID = Isaac.GetCurrentStageConfigId()

    local veinWidthScale = 1.25
    local veinHeightScale = 0.3
    if stageID == StbType.MINES or stageID == StbType.ASHPIT then
        veinWidthScale = 1.80
        veinHeightScale = 0.5
    end

    local sizeX = ((rng:RandomFloat() + rng:RandomFloat()) * veinWidthScale) + 0.5
    local sizeY = ((rng:RandomFloat() + rng:RandomFloat()) * veinHeightScale) + 0.3

    return Vector(sizeX, sizeY)
end

---@param virtualRoom VirtualRoom
---@param gridIdx integer
---@param seed integer
---@return boolean
local function is_grid_idx_in_gold_vein(virtualRoom, gridIdx, seed)
    local rng = RNG(); rng:SetSeed(seed, 19)

    if rng:RandomInt(10) ~= 0 then
        return false
    end

    local roomWidth = virtualRoom.m_Width
    local roomHeight = virtualRoom.m_Height

    local goldVeinPosition = Vector(rng:RandomFloat() * roomHeight, rng:RandomFloat() * roomHeight)
    local gridToVeinPosition = goldVeinPosition - Lib.Grid.GetCoordinatesFromGridIdx(gridIdx, roomWidth)
    local veinSize = get_gold_vein_size(rng)
    gridToVeinPosition = gridToVeinPosition:Rotated(rng:RandomFloat() * 360.0)
    gridToVeinPosition = gridToVeinPosition / veinSize

    return gridToVeinPosition:LengthSquared() <= 1.0
end

---@param rng RNG
---@return GridEntityType
local function select_tinted_rock(rng)
    if rng:RandomInt(20) == 0 and g_PersistentGameData:Unlocked(Achievement.SUPER_SPECIAL_ROCKS) then
        return GridEntityType.GRID_ROCK_SS
    end

    return GridEntityType.GRID_ROCKT
end

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param gridIdx integer
---@param rng RNG
---@return GridEntityType
local function RockMorph(virtualRoom, roomDesc, gridIdx, rng)
    local foolsRockMorph = g_PersistentGameData:Unlocked(Achievement.FOOLS_GOLD) and is_grid_idx_in_gold_vein(virtualRoom, gridIdx, roomDesc.DecorationSeed)

    local randomNumber = rng:RandomInt(1001)
    if virtualRoom.m_TintedRockIdx == gridIdx then
        return select_tinted_rock(rng)
    end

    if randomNumber < 10 then
        return GridEntityType.GRID_ROCK_BOMB
    end

    if foolsRockMorph then
        return GridEntityType.GRID_ROCK_GOLD
    end

    return randomNumber < 16 and GridEntityType.GRID_ROCK_ALT or GridEntityType.GRID_ROCK
end

---@param rng RNG
---@return GridPoopVariant?
local function try_normal_poop_morph(rng)
    if rng:RandomInt(40) == 0 then
        return GridPoopVariant.CORN
    end

    if rng:RandomInt(100) == 0 and g_PersistentGameData:Unlocked(Achievement.CHARMING_POOP) then
        return GridPoopVariant.CHARMING
    end
end

local s_CornPoopOutcomes = {
    [1] = GridPoopVariant.GOLDEN,
    [2] = GridPoopVariant.GOLDEN,
    [5] = GridPoopVariant.RAINBOW,
    [6] = GridPoopVariant.RAINBOW,
    [7] = GridPoopVariant.RAINBOW,
}

---@param rng RNG
---@return GridPoopVariant?
local function try_corn_poop_morph(rng)
    local randomNumber = rng:RandomInt(40)
    return s_CornPoopOutcomes[randomNumber]
end

---@param seed integer
---@return GridPoopVariant?
local function try_meconium_morph(seed)
    local rng = RNG(); rng:SetSeed(seed, 13)
    local randomNumber = rng:RandomInt(100)

    if randomNumber <= 32 then
        return GridPoopVariant.BLACK
    end
end

---@param variant GridPoopVariant | integer
---@param rng RNG
---@return GridPoopVariant
local function PoopMorph(variant, rng)
    if variant == GridPoopVariant.NORMAL then
        variant = try_normal_poop_morph(rng) or variant
    end

    if variant == GridPoopVariant.CORN then
        variant = try_corn_poop_morph(rng) or variant
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_MECONIUM) then
        variant = try_meconium_morph(rng:GetSeed()) or variant
    end

    return variant
end

--#region Module

SpawnMorph.DangerousRockMorph = DangerousRockMorph
SpawnMorph.DirtyMindMorph = DirtyMindMorph
SpawnMorph.TntMorph = TntMorph
SpawnMorph.TrapdoorMorph = TrapdoorMorph
SpawnMorph.ShopkeeperMorph = ShopkeeperMorph
SpawnMorph.HangingShopkeeperMorph = HangingShopkeeperMorph
SpawnMorph.DevilStatueMorph = DevilStatueMorph
SpawnMorph.RockMorph = RockMorph
SpawnMorph.PoopMorph = PoopMorph

--#endregion

return SpawnMorph