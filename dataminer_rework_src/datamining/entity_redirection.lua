---@class EntityRedirection
local EntityRedirection = {}

local IsAfterbirthPlus = false
local STB_EFFECT = 999
local GRID_FIREPLACE = 1400
local GRID_FIREPLACE_RED = 1401
local RUNE_VARIANT = 301

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_ItemPool = g_Game:GetItemPool()
local g_Seeds = g_Game:GetSeeds()
local g_PersistentGameData = Isaac.GetPersistentGameData()
local g_ItemConfig = Isaac.GetItemConfig()

local Lib = {
    Table = require("lib.table"),
    Grid = require("lib.grid"),
    Level = require("lib.level"),
    PersistentGameData = require("lib.persistent_game_data"),
    EntityPickup = require("lib.entity_pickup"),
}

local CustomCallbacks = require("callbacks")

--#endregion

---@param roomData RoomConfigRoom
---@param flags integer
---@return boolean
local function has_room_config_flags(roomData, flags)
    return false
end

---@return integer
local function get_daily_special_run_id()
    return 0 -- can't access daily
end

local function switch_break()
end

--#region IsAvailable

local s_LockedPickupVariants = {
    [PickupVariant.PICKUP_WOODENCHEST] = Achievement.WOODEN_CHEST,
    [PickupVariant.PICKUP_MEGACHEST] = Achievement.MEGA_CHEST,
    [PickupVariant.PICKUP_HAUNTEDCHEST] = Achievement.HAUNTED_CHEST,
}

local s_LockedPickupSubTypes = {
    [PickupVariant.PICKUP_HEART] = {
        [HeartSubType.HEART_GOLDEN] = Achievement.GOLDEN_HEARTS,
        [HeartSubType.HEART_HALF_SOUL] = IsAfterbirthPlus and Achievement.SCARED_HEART or Achievement.EVERYTHING_IS_TERRIBLE,
        [HeartSubType.HEART_SCARED] = Achievement.SCARED_HEART,
        [HeartSubType.HEART_BONE] = Achievement.BONE_HEARTS,
        [HeartSubType.HEART_ROTTEN] = Achievement.ROTTEN_HEARTS,
    },
    [PickupVariant.PICKUP_COIN] = {
        [CoinSubType.COIN_LUCKYPENNY] = Achievement.LUCKY_PENNIES,
        [CoinSubType.COIN_STICKYNICKEL] = Achievement.STICKY_NICKELS,
        [CoinSubType.COIN_GOLDEN] = Achievement.GOLDEN_PENNY,
    },
    [PickupVariant.PICKUP_BOMB] = {
        [BombSubType.BOMB_GOLDEN] = Achievement.GOLDEN_BOMBS,
    },
    [PickupVariant.PICKUP_KEY] = {
        [KeySubType.KEY_CHARGED] = Achievement.CHARGED_KEY,
    },
    [PickupVariant.PICKUP_LIL_BATTERY] = {
        [BatterySubType.BATTERY_MICRO] = Achievement.EVERYTHING_IS_TERRIBLE,
        [BatterySubType.BATTERY_GOLDEN] = Achievement.GOLDEN_BATTERY,
    },
    [PickupVariant.PICKUP_GRAB_BAG] = {
        [SackSubType.SACK_BLACK] = Achievement.BLACK_SACK,
    }
}

---@param variant PickupVariant | integer
---@param subtype integer
---@return boolean
local function IsBasePickupAvailable(variant, subtype)
    local achievement = s_LockedPickupVariants[variant]
    if achievement and not g_PersistentGameData:Unlocked(achievement) then
        return false
    end

    local variantTable = s_LockedPickupSubTypes[variant]
    achievement = variantTable and variantTable[subtype]
    if achievement and not g_PersistentGameData:Unlocked(achievement) then
        return false
    end

    return true
end

---@param collectible CollectibleType | integer
---@return boolean
local function IsCollectibleAvailable(collectible)
    local collectibleConfig = g_ItemConfig:GetCollectible(collectible)
    return not not (collectibleConfig and collectibleConfig:IsAvailable())
end

---@param trinket TrinketType | integer
---@return boolean
local function IsTrinketAvailable(trinket)
    local trinketConfig = g_ItemConfig:GetTrinket(trinket)
    return not not (trinketConfig and trinketConfig:IsAvailable())
end

---@param card Card | integer
---@return boolean
local function IsCardAvailable(card)
    local cardConfig = g_ItemConfig:GetCard(card)
    return not not (cardConfig and cardConfig:IsAvailable())
end

---@param pillEffect PillEffect | integer
---@return boolean
local function IsPillEffectAvailable(pillEffect)
    local pillConfig = g_ItemConfig:GetPillEffect(pillEffect)
    return not not (pillConfig and pillConfig:IsAvailable())
end

---@param variant PickupVariant | integer
---@param subtype integer
---@return boolean
local function is_pickup_available(variant, subtype)
    if variant == PickupVariant.PICKUP_TAROTCARD then
        return IsCardAvailable(subtype)
    end

    return IsBasePickupAvailable(variant, subtype)
end

local s_LockedSlots = {
    [SlotVariant.HELL_GAME] = Achievement.HELL_GAME,
    [SlotVariant.CRANE_GAME] = Achievement.CRANE_GAME,
    [SlotVariant.CONFESSIONAL] = Achievement.CONFESSIONAL,
    [SlotVariant.ROTTEN_BEGGAR] = Achievement.ROTTEN_BEGGAR,
}

---@param player EntityPlayer
---@return boolean unlocked
local function has_unlocked_tainted_character(player)
    local completionEvents = Lib.PersistentGameData.GetCompletionEventsDef(player:GetPlayerType())
    if not completionEvents then
        return false
    end

    local taintedCharacterAchievement = completionEvents[Lib.PersistentGameData.eCompletionEvent.TAINTED_PLAYER].achievement
    if taintedCharacterAchievement < 0 then
        return false
    end

    return g_PersistentGameData:Unlocked(taintedCharacterAchievement)
end

---@param variant SlotVariant | integer
---@param subtype integer
---@return boolean
local function IsSlotAvailable(variant, subtype)
    if variant == SlotVariant.HOME_CLOSET_PLAYER then
        return not has_unlocked_tainted_character(Isaac.GetPlayer(0))
    end

    local achievement = s_LockedSlots[variant]
    return not achievement or g_PersistentGameData:Unlocked(achievement)
end

--#endregion

--#region Availability Redirection

local s_DefaultHearts = {
    [HeartSubType.HEART_HALF_SOUL] = HeartSubType.HEART_SOUL,
    [HeartSubType.HEART_SCARED] = HeartSubType.HEART_FULL,
    [HeartSubType.HEART_BONE] = HeartSubType.HEART_HALF,
    [HeartSubType.HEART_ROTTEN] = HeartSubType.HEART_HALF,
}

local s_DefaultChests = {
    [PickupVariant.PICKUP_MEGACHEST] = PickupVariant.PICKUP_LOCKEDCHEST
}

---@param variant integer
---@param subtype integer
---@param rng RNG
---@return integer entityType, integer variant, integer subtype
local function redirect_unavailable_pickup(variant, subtype, rng)
    local entityType = EntityType.ENTITY_PICKUP
    local seed = rng:Next()

    if Lib.EntityPickup.IsChest(variant) then
        variant = s_DefaultChests[variant] or PickupVariant.PICKUP_CHEST
        return entityType, variant, subtype
    end

    if variant == PickupVariant.PICKUP_HEART then
        subtype = s_DefaultHearts[subtype] or 0
        return entityType, variant, subtype
    end

    if variant == PickupVariant.PICKUP_TAROTCARD and subtype ~= 0 then
        subtype = g_ItemPool:GetCard(seed, true, true, false)
        return entityType, variant, subtype
    end

    return entityType, variant, 0
end

local s_DefaultSlots = {
    [SlotVariant.HELL_GAME] = {EntityType.ENTITY_SLOT, SlotVariant.DEVIL_BEGGAR, nil},
    [SlotVariant.CRANE_GAME] = {EntityType.ENTITY_SLOT, SlotVariant.SLOT_MACHINE, nil},
    [SlotVariant.CONFESSIONAL] = {EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL},
    [SlotVariant.ROTTEN_BEGGAR] = {EntityType.ENTITY_SLOT, SlotVariant.KEY_MASTER, nil},
}

---@param variant integer
---@param subtype integer
---@return integer entityType, integer variant, integer subtype
local function redirect_unavailable_slot(variant, subtype)
    local entityType = EntityType.ENTITY_SLOT

    if variant == SlotVariant.HOME_CLOSET_PLAYER then
        if g_PersistentGameData:Unlocked(Achievement.INNER_CHILD) then
            return EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_INNER_CHILD
        end

        return EntityType.ENTITY_SHOPKEEPER, 0, 0
    end

    local defaultEntry = s_DefaultSlots[variant] or {EntityType.ENTITY_SLOT, SlotVariant.SLOT_MACHINE, nil}
    entityType = defaultEntry[1] or entityType
    variant = defaultEntry[2] or variant
    subtype = defaultEntry[3] or subtype

    return entityType, variant, subtype
end

---@param virtualRoom VirtualRoom
---@param rng RNG
---@return boolean
local function is_heavens_trapdoor(virtualRoom, rng)
    if virtualRoom.m_RoomType == RoomType.ROOM_ANGEL then
        return true
    end

    local stage = Lib.Level.GetEffectiveStage(g_Level)
    if g_Game:IsGreedMode() then
        stage = Lib.Level.ConvertGreedStageToNormal(stage)
    end

    local forcedDevilPath = false
    local forcedAngelPath = false

    if g_Game.Challenge ~= Challenge.CHALLENGE_NULL then
        local challengeParams = g_Game:GetChallengeParams()
        forcedAngelPath = challengeParams.IsAltPath()
        forcedDevilPath = not forcedAngelPath
    end

    if virtualRoom.m_RoomType == RoomType.ROOM_ERROR and
       (stage == LevelStage.STAGE4_2 or stage == LevelStage.STAGE4_3) and
       ((rng:RandomInt(2) == 0 and not forcedDevilPath) or forcedAngelPath) then
        return true
    end

    if stage >= LevelStage.STAGE5 and g_Level:GetStageType() ~= StageType.STAGETYPE_ORIGINAL then
        return true
    end

    if virtualRoom.m_RoomIdx == GridRooms.ROOM_GENESIS_IDX then
        return true
    end

    return false
end

---@param entityType integer
---@param variant integer
---@param subtype integer
---@return integer entityType, integer variant, integer subtype
local function redirect_into_heavens_trapdoor(entityType, variant, subtype)
    if not g_Level:IsNextStageAvailable() then
        return StbGridType.CRAWLSPACE, 3, subtype
    end

    if g_Level:IsStageAvailable(LevelStage.STAGE5, StageType.STAGETYPE_WOTL) then
        return STB_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, subtype
    end

    return entityType, variant, subtype
end

---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param rng RNG
---@return integer entityType, integer variant, integer subtype
local function redirect_error_room_trapdoor(virtualRoom, entityType, variant, subtype, rng)
    local stage = Lib.Level.GetEffectiveStage(g_Level)
    if g_Game:IsGreedMode() then
        stage = Lib.Level.ConvertGreedStageToNormal(stage)
    end

    if stage == LevelStage.STAGE6 then
        local challengeParams = g_Game:GetChallengeParams()
        local challengeEndStage = challengeParams:GetEndStage()
        local endStage = g_PersistentGameData:Unlocked(Achievement.VOID_FLOOR) and LevelStage.STAGE7 or LevelStage.STAGE6
        endStage = challengeEndStage ~= LevelStage.STAGE_NULL and challengeEndStage or endStage

        if endStage >= LevelStage.STAGE7 then
            return entityType, 1, subtype
        end
    end

    if not g_Level:IsNextStageAvailable() then
        return StbGridType.CRAWLSPACE, 3, subtype
    end

    if is_heavens_trapdoor(virtualRoom, rng) then
        return redirect_into_heavens_trapdoor(entityType, variant, subtype)
    end

    return entityType, variant, subtype
end

---@param virtualRoom VirtualRoom
---@param variant integer
---@param subtype integer
---@param rng RNG
---@return integer entityType, integer variant, integer subtype
local function redirect_trapdoor(virtualRoom, variant, subtype, rng)
    local entityType = StbGridType.TRAP_DOOR

    if g_Game:IsGreedMode() then
        return entityType, variant, subtype
    end

    if Lib.Level.IsBackwardsPath(g_Level) then
        return STB_EFFECT, EffectVariant.HEAVEN_LIGHT_DOOR, subtype
    end

    if virtualRoom.m_RoomType == RoomType.ROOM_ERROR then
        return redirect_error_room_trapdoor(virtualRoom, entityType, variant, subtype, rng)
    end

    if is_heavens_trapdoor(virtualRoom, rng) then
        return redirect_into_heavens_trapdoor(entityType, variant, subtype)
    end

    return entityType, variant, subtype
end

---@param entityType EntityType | integer
---@param variant integer
---@return EntityType | integer redirectType
---@return integer redirectVariant
---@return boolean redirected
local function morph_into_easier_npc(entityType, variant)
    if entityType == EntityType.ENTITY_BLISTER then
        if g_Game:IsHardMode() then
            return EntityType.ENTITY_TICKING_SPIDER, 0, true
        end

        return EntityType.ENTITY_HOPPER, 1, true
    end

    if entityType == EntityType.ENTITY_MUSHROOM then
        return EntityType.ENTITY_HOST, 0, true
    end

    if entityType == EntityType.ENTITY_MINISTRO then
        return EntityType.ENTITY_HOPPER, 0, true
    end

    if entityType == EntityType.ENTITY_NERVE_ENDING then
        return EntityType.ENTITY_NERVE_ENDING, 0, true
    end

    if entityType == EntityType.ENTITY_POISON_MIND then
        return EntityType.ENTITY_BRAIN, 0, true
    end

    if entityType == EntityType.ENTITY_STONEY then
        if g_Game:IsHardMode() then
            return EntityType.ENTITY_CONJOINED_FATTY, 0, true
        end

        return EntityType.ENTITY_FATTY, 0, true
    end

    if entityType == EntityType.ENTITY_THE_THING then
        if g_Game:IsHardMode() then
            return EntityType.ENTITY_BLIND_CREEP, 0, true
        end

        return EntityType.ENTITY_WALL_CREEP, 0, true
    end

    return entityType, variant, false
end

local s_StagePortalDefault = {
    [StbType.SPECIAL_ROOMS] = {EntityType.ENTITY_SPIDER, EntityType.ENTITY_BIGSPIDER, 0, 0},
    [StbType.BASEMENT] = {EntityType.ENTITY_GAPER, EntityType.ENTITY_CYCLOPIA, 0, 0},
    [StbType.CELLAR] = {EntityType.ENTITY_SPIDER, EntityType.ENTITY_BIGSPIDER, 0, 0},
    [StbType.BURNING_BASEMENT] = {EntityType.ENTITY_GAPER, EntityType.ENTITY_CYCLOPIA, 0, 0},
    [StbType.CELLAR] = {EntityType.ENTITY_SPIDER, EntityType.ENTITY_BIGSPIDER, 0, 0},
    [StbType.CAVES] = {EntityType.ENTITY_MAGGOT, EntityType.ENTITY_CHARGER, 0, 0},
    [StbType.CATACOMBS] = {EntityType.ENTITY_MAW, EntityType.ENTITY_MAW, 0, 1},
    [StbType.FLOODED_CAVES] = {EntityType.ENTITY_CHARGER, EntityType.ENTITY_CHARGER, 0, 1},
    [StbType.DEPTHS] = {EntityType.ENTITY_FAT_SACK, EntityType.ENTITY_BONY, 0, 0},
    [StbType.NECROPOLIS] = {EntityType.ENTITY_BONY, EntityType.ENTITY_GLOBIN, 0, 1},
    [StbType.DANK_DEPTHS] = {EntityType.ENTITY_GLOBIN, EntityType.ENTITY_BLACK_BONY, 0, 0},
    [StbType.WOMB] = {EntityType.ENTITY_CLOTTY, EntityType.ENTITY_PARA_BITE, 0, 0},
    [StbType.UTERO] = {EntityType.ENTITY_PARA_BITE, EntityType.ENTITY_VIS, 0, 0},
    [StbType.SCARRED_WOMB] = {EntityType.ENTITY_VIS, EntityType.ENTITY_VIS, 0, 1},
    [StbType.BLUE_WOMB] = {EntityType.ENTITY_HUSH_GAPER, EntityType.ENTITY_HUSH_GAPER, 0, 0},
    [StbType.SHEOL] = {EntityType.ENTITY_GURGLE, EntityType.ENTITY_NULLS, 0, 0},
    [StbType.CATHEDRAL] = {EntityType.ENTITY_MAW, EntityType.ENTITY_LEECH, 2, 2},
    [StbType.DARK_ROOM] = {EntityType.ENTITY_WRATH, EntityType.ENTITY_GREED, 1, 1},
    [StbType.CHEST] = {EntityType.ENTITY_DARK_ONE, EntityType.ENTITY_SISTERS_VIS, 0, 0},
    [StbType.THE_VOID] = {EntityType.ENTITY_DELIRIUM, EntityType.ENTITY_DELIRIUM, 0, 0},
    default = nil
}

local s_GreedPortalDefault = {
    [LevelStage.STAGE1_GREED] = s_StagePortalDefault[StbType.BASEMENT],
    [LevelStage.STAGE2_GREED] = s_StagePortalDefault[StbType.CAVES],
    [LevelStage.STAGE3_GREED] = s_StagePortalDefault[StbType.DEPTHS],
    [LevelStage.STAGE4_GREED] = s_StagePortalDefault[StbType.UTERO],
    [LevelStage.STAGE5_GREED] = s_StagePortalDefault[StbType.SHEOL],
    [LevelStage.STAGE6_GREED] = {EntityType.ENTITY_GREED, EntityType.ENTITY_GREED, 0, 1},
    default = {EntityType.ENTITY_GREED_GAPER, EntityType.ENTITY_GREED_GAPER, 0, 0},
}

---@param virtualRoom VirtualRoom
---@return table? redirectedEntity
local function redirect_unavailable_portal(virtualRoom)
    local isHardMode = g_Game:IsHardMode()
    local morphTable = nil -- Forward Declaration

    if g_Game:IsGreedMode() then
        morphTable = s_GreedPortalDefault[g_Level:GetStage()] or s_GreedPortalDefault.default
    else
        morphTable = s_StagePortalDefault[virtualRoom.m_RoomDescriptor.Data.StageID] or s_StagePortalDefault.default
    end

    if not morphTable then
        return nil
    end

    local morphType = isHardMode and 2 or 1
    local morphVariant = isHardMode and 4 or 3
    return {morphTable[morphType], morphTable[morphVariant]}
end

---@param entityType EntityType | integer
---@param variant integer
---@return EntityType | integer redirectType
---@return integer redirectVariant
local function g_fuel_morph(entityType, variant)
    if entityType == EntityType.ENTITY_HOST then
        return EntityType.ENTITY_HOST, 1
    end

    if entityType == EntityType.ENTITY_MOBILE_HOST then
        return EntityType.ENTITY_FLESH_MOBILE_HOST, variant
    end

    if entityType == EntityType.ENTITY_FLOATING_HOST then
        return EntityType.ENTITY_BOOMFLY, 1
    end

    if entityType == EntityType.ENTITY_COD_WORM then
        return EntityType.ENTITY_PARA_BITE, variant
    end

    return entityType, variant
end

---@param virtualRoom VirtualRoom
---@param entityType EntityType | integer
---@param variant integer
---@return EntityType | integer redirectType
---@return integer redirectVariant
---@return boolean
local function RedirectNPC(virtualRoom, entityType, variant)
    if entityType == EntityType.ENTITY_SUCKER and variant == 5 and not g_PersistentGameData:Unlocked(Achievement.EVERYTHING_IS_TERRIBLE) then
        entityType = EntityType.ENTITY_FLY
        variant = 0
    end

    if not g_PersistentGameData:Unlocked(Achievement.THE_GATE_IS_OPEN) then
        local redirected = false
        entityType, variant, redirected = morph_into_easier_npc(entityType, variant)
        if redirected then
            return entityType, variant, true
        end

        if entityType == EntityType.ENTITY_PORTAL then
            local redirectedEntity = redirect_unavailable_portal(virtualRoom)
            if redirectedEntity then
                return redirectedEntity[1], redirectedEntity[2], true
            end
        end
    end

    if g_Seeds:HasSeedEffect(SeedEffect.SEED_G_FUEL) then
        entityType, variant = g_fuel_morph(entityType, variant)
    end

    return entityType, variant, false
end

--#endregion

--#region Morphs

---@param virtualRoom VirtualRoom
---@param variant PickupVariant | integer
---@param subtype integer
---@return integer entityType, integer variant, integer subtype
local function morph_pickup_spawn(virtualRoom, variant, subtype)
    local entityType = EntityType.ENTITY_PICKUP

    if (virtualRoom.m_RoomDescriptor.Flags & RoomDescriptor.FLAG_DEVIL_TREASURE ~= 0) and variant == PickupVariant.PICKUP_COLLECTIBLE then
        return entityType, PickupVariant.PICKUP_SHOPITEM, subtype
    end

    return entityType, variant, subtype
end

---@param variant SlotVariant | integer
---@param subtype integer
---@param seed integer
---@return integer entityType, integer variant, integer subtype
local function morph_slot_spawn(variant, subtype, seed)
    local entityType = EntityType.ENTITY_SLOT
    local rng = RNG(seed, 68)

    if variant == SlotVariant.SHELL_GAME and IsSlotAvailable(SlotVariant.HELL_GAME, subtype) and
       g_Game:GetDevilRoomDeals() > 0 and rng:RandomInt(4) == 0 then
        return entityType, SlotVariant.HELL_GAME, subtype
    end

    if variant == SlotVariant.BEGGAR and IsSlotAvailable(SlotVariant.ROTTEN_BEGGAR, subtype) and
       rng:RandomInt(15) == 0 then
        return entityType, SlotVariant.ROTTEN_BEGGAR, subtype
    end

    return entityType, variant, subtype
end

---@class Switch.TryStageSpawnModifiersIO
---@field virtualRoom VirtualRoom
---@field type integer
---@field variant integer
---@field gridIdx integer
---@field rng RNG
---@field isBurningBasement boolean
---@field isFloodedCaves boolean
---@field isDankDepths boolean
---@field isScarredWomb boolean
---@field isAltBasement boolean
---@field isAltCaves boolean
---@field gateOpen boolean

---@param io Switch.TryStageSpawnModifiersIO
local function gaper_stage_modifier(io)
    if io.isBurningBasement and io.rng:RandomInt(5) < 3 then
        io.variant = 2
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function horf_stage_modifier(io)
    if io.rng:RandomInt(60) == 0 then
        io.type = EntityType.ENTITY_SUB_HORF
        io.variant = 0
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function hive_stage_modifier(io)
    if io.isFloodedCaves and io.rng:RandomInt(2) == 0 then
        io.variant = 1
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function charger_stage_modifier(io)
    if io.isFloodedCaves and io.rng:RandomInt(2) == 0 then
        io.type = EntityType.ENTITY_CHARGER -- Don't know why but it does this
        io.variant = 1
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function globin_stage_modifier(io)
    if io.isDankDepths and io.rng:RandomInt(2) == 0 then
        io.variant = 2
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function boomfly_stage_modifier(io)
    if io.isFloodedCaves and io.rng:RandomInt(2) == 0 then
        io.variant = 2
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function host_stage_modifier(io)
    if not io.isAltCaves and io.rng:RandomInt(5) == 0 and io.gateOpen then
        io.type = EntityType.ENTITY_MUSHROOM
        io.variant = 0
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function hopper_stage_modifier(io)
    if io.variant == 0 and io.isBurningBasement and io.rng:RandomInt(5) < 3 then
        io.type = EntityType.ENTITY_FLAMINGHOPPER
        io.variant = 0
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function mrmaw_stage_modifier(io)
    if io.rng:RandomInt(15) == 0 then
        io.variant = 2
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function vis_stage_modifier(io)
    if io.variant ~= 2 and io.isScarredWomb and io.rng:RandomInt(2) == 0 then
        io.variant = 3
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function guts_stage_modifier(io)
    if io.isScarredWomb and io.rng:RandomInt(2) == 0 then
        io.variant = 1
        return true
    end

    return false
end

local para_bite_stage_modifier = guts_stage_modifier

---@param io Switch.TryStageSpawnModifiersIO
local function knight_stage_modifier(io)
    if io.variant == 0 and io.rng:RandomInt(60) == 0 then
        io.variant = 2
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function spider_stage_modifier(io)
    if io.isAltBasement then
        io.type = EntityType.ENTITY_STRIDER
        io.variant = 0
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function fatty_stage_modifier(io)
    if io.gateOpen and io.variant == 1 and io.rng:RandomInt(10) == 0 then
        io.type = EntityType.ENTITY_STONEY
        io.variant = 0
        return true
    end

    if io.isBurningBasement and io.rng:RandomInt(5) < 3 then
        io.variant = 2
        return true
    end

    return false
end

---@param io Switch.TryStageSpawnModifiersIO
local function deaths_head_stage_modifier(io)
    if io.isDankDepths and io.rng:RandomInt(2) == 0 then
        io.variant = 1
        return true
    end

    return false
end

local squirt_stage_modifier = deaths_head_stage_modifier

---@param io Switch.TryStageSpawnModifiersIO
local function skinny_stage_modifier(io)
    if io.isBurningBasement and io.rng:RandomInt(5) < 2 then
        io.variant = 2
        return true
    end

    return false
end

---@param roomDescriptor VirtualRoomDescriptor
---@param doorSlot DoorSlot
---@return boolean
local function is_door_slot_allowed(roomDescriptor, doorSlot)
    if doorSlot >= DoorSlot.NUM_DOOR_SLOTS then
        return false
    end

    local door = roomDescriptor.Doors[doorSlot]
    return not (door == -1 or door == 0)
end

---@param virtualRoom VirtualRoom
---@param doorSlot DoorSlot
---@param spawnCoordinates Vector
local function is_nerve_close_to_door_slot(virtualRoom, doorSlot, spawnCoordinates)
    if not is_door_slot_allowed(virtualRoom.m_RoomDescriptor, doorSlot) then
        return false
    end

    local doorGridCoordinates = Lib.Grid.GetCoordinatesFromGridIdx(virtualRoom.m_DoorGridIdx[doorSlot + 1], virtualRoom.m_Width)
    return Lib.Grid.ManhattanDistance(doorGridCoordinates, spawnCoordinates) < 4
end

---@param io Switch.TryStageSpawnModifiersIO
local function nerve_ending_stage_modifier(io)
    if not (io.gateOpen and io.rng:RandomInt(5) == 0) then
        return false
    end

    local spawnCoordinates = Lib.Grid.GetCoordinatesFromGridIdx(io.gridIdx, io.virtualRoom.m_Width)

    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1, 1 do
        if is_nerve_close_to_door_slot(io.virtualRoom, i, spawnCoordinates) then
            return false
        end
    end

    io.variant = 1
    return true
end

local switch_TryStageSpawnModifiers = {
    [EntityType.ENTITY_GAPER] = gaper_stage_modifier,
    [EntityType.ENTITY_HORF] = horf_stage_modifier,
    [EntityType.ENTITY_HIVE] = hive_stage_modifier,
    [EntityType.ENTITY_CHARGER] = charger_stage_modifier,
    [EntityType.ENTITY_GLOBIN] = globin_stage_modifier,
    [EntityType.ENTITY_BOOMFLY] = boomfly_stage_modifier,
    [EntityType.ENTITY_HOST] = host_stage_modifier,
    [EntityType.ENTITY_HOPPER] = hopper_stage_modifier,
    [EntityType.ENTITY_MRMAW] = mrmaw_stage_modifier,
    [EntityType.ENTITY_VIS] = vis_stage_modifier,
    [EntityType.ENTITY_GUTS] = guts_stage_modifier,
    [EntityType.ENTITY_PARA_BITE] = para_bite_stage_modifier,
    [EntityType.ENTITY_KNIGHT] = knight_stage_modifier,
    [EntityType.ENTITY_SPIDER] = spider_stage_modifier,
    [EntityType.ENTITY_FATTY] = fatty_stage_modifier,
    [EntityType.ENTITY_DEATHS_HEAD] = deaths_head_stage_modifier,
    [EntityType.ENTITY_SQUIRT] = squirt_stage_modifier,
    [EntityType.ENTITY_SKINNY] = skinny_stage_modifier,
    [EntityType.ENTITY_NERVE_ENDING] = nerve_ending_stage_modifier,
    default = switch_break,
}

---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param gridIdx integer
---@param rng RNG
---@return integer entityType, integer variant, boolean appliedModifier
local function try_stage_npc_morph(virtualRoom, entityType, variant, gridIdx, rng)
    local stage = Lib.Level.GetEffectiveStage(g_Level)
    if g_Game:IsGreedMode() then
        stage = Lib.Level.ConvertGreedStageToNormal(stage)
    end
    local stageType = g_Level:GetStageType()
    local isAltPath = Lib.Level.IsAltPath(g_Level)

    ---@type Switch.TryStageSpawnModifiersIO
    local switchIO = {
        virtualRoom = virtualRoom,
        type = entityType,
        variant = variant,
        gridIdx = gridIdx,
        rng = rng,
        isBurningBasement = stageType == StageType.STAGETYPE_AFTERBIRTH and (stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2),
        isFloodedCaves = stageType == StageType.STAGETYPE_AFTERBIRTH and (stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2),
        isDankDepths = stageType == StageType.STAGETYPE_AFTERBIRTH and (stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2),
        isScarredWomb = stageType == StageType.STAGETYPE_AFTERBIRTH and (stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2),
        isAltBasement = isAltPath and (stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2),
        isAltCaves = isAltPath and (stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2),
        gateOpen = g_PersistentGameData:Unlocked(Achievement.THE_GATE_IS_OPEN),
    }

    local TryStageSpawnModifiers = switch_TryStageSpawnModifiers[entityType] or switch_TryStageSpawnModifiers.default
    local appliedModifier = TryStageSpawnModifiers(switchIO)
    return switchIO.type, switchIO.variant, appliedModifier
end

local s_HasHardRareSpawnVariant = Lib.Table.CreateDictionary({
    EntityType.ENTITY_CLOTTY, EntityType.ENTITY_MULLIGAN, EntityType.ENTITY_MAW,
    EntityType.ENTITY_BOIL, EntityType.ENTITY_VIS, EntityType.ENTITY_LEECH,
    EntityType.ENTITY_WALKINGBOIL
})

---@param entityType integer
---@param variant integer
---@param rng RNG
---@return integer entityType, integer variant
local function try_rare_hard_npc_variant(entityType, variant, rng)
    if s_HasHardRareSpawnVariant[entityType] and rng:RandomInt(100) == 0 then
        variant = 2
    end

    return entityType, variant
end

---@class Switch.TryAltNpcVariantIO
---@field has21Chance boolean
---@field has25Chance boolean

---@param io Switch.TryAltNpcVariantIO
local function set_21_chance(io)
    io.has21Chance = true
end

---@param io Switch.TryAltNpcVariantIO
local function set_25_chance(io)
    io.has25Chance = true
end

---@param io Switch.TryAltNpcVariantIO
local function set_all_tries(io)
    io.has21Chance = true
    io.has25Chance = true
end

---@param io Switch.TryAltNpcVariantIO
local function try_boomfly_alt_variant(io)
    local stage = Lib.Level.GetEffectiveStage(g_Level)
    if g_Game:IsGreedMode() then
        stage = Lib.Level.ConvertGreedStageToNormal(stage)
    end

    if stage >= LevelStage.STAGE2_1 then
        set_all_tries(io)
    end
end

---@param io Switch.TryAltNpcVariantIO
local function try_vis_alt_variant(io)
    local stage = Lib.Level.GetEffectiveStage(g_Level)
    if g_Game:IsGreedMode() then
        stage = Lib.Level.ConvertGreedStageToNormal(stage)
    end

    if (stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2) and g_Level:GetStageType() == StageType.STAGETYPE_WOTL then
        set_21_chance(io)
    end
end

local switch_TryAltNpcVariant = {
    [EntityType.ENTITY_POOTER] = set_all_tries,
    [EntityType.ENTITY_MULLIGAN] = set_all_tries,
    [EntityType.ENTITY_GLOBIN] = set_all_tries,
    [EntityType.ENTITY_MAW] = set_all_tries,
    [EntityType.ENTITY_HOST] = set_all_tries,
    [EntityType.ENTITY_BOOMFLY] = try_boomfly_alt_variant,
    [EntityType.ENTITY_HOPPER] = set_21_chance,
    [EntityType.ENTITY_BOIL] = set_21_chance,
    [EntityType.ENTITY_BABY] = set_21_chance,
    [EntityType.ENTITY_STONEHEAD] = set_21_chance,
    [EntityType.ENTITY_MEMBRAIN] = set_21_chance,
    [EntityType.ENTITY_SUCKER] = set_21_chance,
    [EntityType.ENTITY_WALKINGBOIL] = set_21_chance,
    [EntityType.ENTITY_VIS] = try_vis_alt_variant,
    [EntityType.ENTITY_KNIGHT] = set_25_chance,
    [EntityType.ENTITY_LEECH] = set_25_chance,
    [EntityType.ENTITY_EYE] = set_25_chance,
    default = switch_break,
}

---@param entityType integer
---@param variant integer
---@param rng RNG
---@return integer entityType, integer variant
local function try_alt_npc_variant(entityType, variant, rng)
    ---@type Switch.TryAltNpcVariantIO
    local switchIO = {
        has21Chance = false,
        has25Chance = false,
    }

    local TryAltNpcVariant = switch_TryAltNpcVariant[entityType] or switch_TryAltNpcVariant.default
    TryAltNpcVariant(switchIO)

    if not switchIO.has21Chance and not switchIO.has25Chance then
        return entityType, variant
    end

    if (switchIO.has21Chance and rng:RandomInt(21) == 0) or (switchIO.has25Chance and rng:RandomInt(25) == 0) or rng:RandomInt(100) == 0 then
        variant = 1
    end

    return entityType, variant
end

---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param gridIdx integer
---@param rng RNG
---@return integer entityType, integer variant, integer subtype
local function morph_npc_spawn(virtualRoom, entityType, variant, subtype, gridIdx, rng)
    if entityType == EntityType.ENTITY_STONEY then
        if (g_Game.Challenge == Challenge.CHALLENGE_APRILS_FOOL or get_daily_special_run_id() == 7) and rng:RandomInt(5) == 0 then
            return entityType, 10, subtype
        end
    end

    local modifierApplied = false
    entityType, variant, modifierApplied = try_stage_npc_morph(virtualRoom, entityType, variant, gridIdx, rng)

    if modifierApplied then
        return entityType, variant, subtype
    end

    entityType, variant = try_rare_hard_npc_variant(entityType, variant, rng)
    entityType, variant = try_alt_npc_variant(entityType, variant, rng)

    if entityType == EntityType.ENTITY_BOOMFLY and variant == 3 and subtype == 100 then
        subtype = rng:RandomInt(2)
    end

    return entityType, variant, subtype
end

---@param virtualRoom VirtualRoom
---@param entityType EntityType | integer
---@param variant integer
---@param subtype integer
---@param gridIdx integer
---@param seed integer
---@return integer entityType, integer variant, integer subtype
local function FixSpawnEntry(virtualRoom, entityType, variant, subtype, gridIdx, seed)
    local rng = RNG(seed, 7)

    if entityType == GRID_FIREPLACE then
        entityType = EntityType.ENTITY_FIREPLACE
        variant = rng:RandomInt(40) == 0 and 1 or 0
    end

    if entityType == GRID_FIREPLACE_RED then
        entityType = EntityType.ENTITY_FIREPLACE
        variant = 1
    end

    local overridden = false
    entityType, variant, subtype, overridden = CustomCallbacks.RunPreRoomEntitySpawn(entityType, variant, subtype, gridIdx, seed, virtualRoom)

    if entityType == EntityType.ENTITY_PICKUP and variant == RUNE_VARIANT then
        variant = PickupVariant.PICKUP_TAROTCARD
        subtype = g_ItemPool:GetCard(rng:Next(), false, true, true)
    end

    if overridden then
        return entityType, variant, subtype
    end

    if entityType == EntityType.ENTITY_PICKUP and not is_pickup_available(variant, subtype) then
        entityType, variant, subtype = redirect_unavailable_pickup(variant, subtype, rng)
    end

    if entityType == EntityType.ENTITY_SLOT and not IsSlotAvailable(variant, subtype) then
        entityType, variant, subtype = redirect_unavailable_slot(variant, subtype)
    end

    if entityType == StbGridType.TRAP_DOOR then
        entityType, variant, subtype = redirect_trapdoor(virtualRoom, variant, subtype, rng)
    end

    if entityType == EntityType.ENTITY_PICKUP then
        entityType, variant, subtype = morph_pickup_spawn(virtualRoom, variant, subtype)
    end

    if entityType == EntityType.ENTITY_SLOT then
        entityType, variant, subtype = morph_slot_spawn(variant, subtype, seed)
    end

    if 1 <= entityType and entityType <= 999 then
        entityType, variant = RedirectNPC(virtualRoom, entityType, variant)
    end

    if virtualRoom.m_RoomType == RoomType.ROOM_SECRET_EXIT or not has_room_config_flags(virtualRoom.m_RoomDescriptor.Data, 1 << 0) then
        return entityType, variant, subtype
    end

    entityType, variant, subtype = morph_npc_spawn(virtualRoom, entityType, variant, subtype, gridIdx, rng)
    return entityType, variant, subtype
end

--#endregion

--#region Module

EntityRedirection.IsBasePickupAvailable = IsBasePickupAvailable
EntityRedirection.IsCollectibleAvailable = IsCollectibleAvailable
EntityRedirection.IsTrinketAvailable = IsTrinketAvailable
EntityRedirection.IsCardAvailable = IsCardAvailable
EntityRedirection.IsPillEffectAvailable = IsPillEffectAvailable
EntityRedirection.IsSlotAvailable = IsSlotAvailable
EntityRedirection.RedirectNPC = RedirectNPC
EntityRedirection.FixSpawnEntry = FixSpawnEntry

--#endregion

return EntityRedirection