---@class SpawnReader
local SpawnReader = {}

---@class SpawnEntry
---@field Type EntityType | StbType | integer
---@field Variant integer
---@field Subtype integer

---@class SpawnDesc
---@field spawnType integer 0 for nothing 1 for entities, 2 for gridEntity
---@field entityDesc EntitySpawnDesc | GridSpawnDesc | nil
---@field addOutput boolean?
---@field initRail boolean?

---@class EntitySpawnDesc
---@field type EntityType | integer
---@field variant integer
---@field subType integer
---@field initSeed integer

---@class GridSpawnDesc
---@field type GridEntityType | integer
---@field variant integer
---@field varData integer
---@field spawnSeed integer
---@field spawnFissureSpawner boolean
---@field fissureSpawnerSeed integer -- Technically unneeded, but just in case
---@field increasePoopCount boolean
---@field increasePitCount boolean

local STB_EFFECT = 999
local GRID_FIREPLACE = 1400
local GRID_FIREPLACE_RED = 1401

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_PlayerManager = PlayerManager
local g_BossPool = BossPoolManager
local g_Seeds = g_Game:GetSeeds()
local g_PersistentGameData = Isaac.GetPersistentGameData()

local Lib = {
    Grid = require("dataminer_rework_src.lib.grid"),
    Level = require("dataminer_rework_src.lib.level"),
    Room = require("dataminer_rework_src.lib.room"),
    PlayerManager = require("dataminer_rework_src.lib.player_manager"),
}

local EntityRedirection = require("dataminer_rework_src.datamining.entity_redirection")

--#endregion

---@param roomData RoomConfigRoom
---@param flags integer
---@return boolean
local function has_room_config_flags(roomData, flags)
    return false -- inaccessible
end

--#region Fix SpawnEntry

--#region SpawnEntry Block

---@param roomData RoomConfigRoom
---@return boolean
local function is_knife_treasure_room(roomData)
    return roomData.Type == RoomType.ROOM_TREASURE and roomData.Subtype == RoomSubType.TREASURE_KNIFE_PIECE
end

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param respawning boolean
local function try_block_spawn(roomDesc, roomData, spawnEntry, respawning)
    if spawnEntry.Type == EntityType.ENTITY_PICKUP and spawnEntry.Variant == PickupVariant.PICKUP_COLLECTIBLE and
       roomDesc.SafeGridIndex == GridRooms.ROOM_GENESIS_IDX then
        return true
    end

    if spawnEntry.Type == EntityType.ENTITY_PICKUP and not respawning and
       g_Level:HasMirrorDimension() and roomDesc:GetDimension() == Dimension.KNIFE_PUZZLE and
       not is_knife_treasure_room(roomData) then
        return true
    end

    if spawnEntry.Type == EntityType.ENTITY_SLOT and spawnEntry.Variant == SlotVariant.DONATION_MACHINE and
       roomData.Type == RoomType.ROOM_SHOP and roomDesc.GridIndex < 0 then
        return true
    end

    return false
end

--#endregion

--#region SpawnEntry Morph

---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param rng RNG
local function try_rock_dangerous_morph(roomData, spawnEntry, rng)
    if not (g_Level:GetStageType() == StageType.STAGETYPE_AFTERBIRTH and roomData.Type == RoomType.ROOM_DEFAULT) then
        return
    end

    if rng:RandomInt(10) ~= 0 then
        return
    end

    local stage = g_Level:GetStage()

    if stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2 then
        spawnEntry.Type = EntityType.ENTITY_FIREPLACE
        spawnEntry.Variant = rng:RandomInt(40) == 0 and 1 or 0
        spawnEntry.Subtype = 0
    elseif stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2 then
        spawnEntry.Type = StbGridType.PIT
        spawnEntry.Variant = 0
        spawnEntry.Subtype = 0
    elseif stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2 then
        spawnEntry.Type = StbGridType.SPIKES
        spawnEntry.Variant = 0
        spawnEntry.Subtype = 0
    elseif stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2 then
        spawnEntry.Type = StbGridType.RED_POOP
        spawnEntry.Variant = 0
        spawnEntry.Subtype = 0
    end
end

---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param seed integer
---@return boolean
local function try_dirty_mind_morph(roomData, spawnEntry, seed)
    if roomData.Type == RoomType.ROOM_DUNGEON then
        return false
    end

    local rng = RNG(seed, 2)
    local randomPlayer = Lib.PlayerManager.RandomCollectibleOwner(g_PlayerManager, CollectibleType.COLLECTIBLE_DIRTY_MIND, rng:Next())[1]
    if not randomPlayer then
        return false
    end

    local chance = math.min(randomPlayer.Luck * 0.005 + 0.0625, 0.1)
    if rng:RandomFloat() > chance then
        return false
    end

    spawnEntry.Type = StbGridType.POOP
    spawnEntry.Variant = 0
    spawnEntry.Subtype = 0
    return true
end

---@param roomDesc RoomDescriptor
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

---@param virtualRoom VirtualRoom
---@param spawnEntry SpawnEntry
---@param gridIdx integer
---@return boolean
local function can_morph_rock_entry(virtualRoom, spawnEntry, gridIdx)
    return ((spawnEntry.Type == StbGridType.ROCK and virtualRoom.tintedRockIdx ~= gridIdx)) or spawnEntry.Type == StbGridType.BOMB_ROCK or spawnEntry.Type == StbGridType.ALT_ROCK
end

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param rng RNG
---@param gridIdx integer
local function try_morph_spawn(virtualRoom, roomDesc, roomData, spawnEntry, gridIdx, rng)
    if spawnEntry.Type == StbGridType.ROCK and virtualRoom.tintedRockIdx == gridIdx then
        return
    end

    local rockSeed = rng:GetSeed()

    local dangerousGridMorph = has_room_config_flags(roomData, 1 << 3)
    if dangerousGridMorph and can_morph_rock_entry(virtualRoom, spawnEntry, gridIdx) then
        try_rock_dangerous_morph(roomData, spawnEntry, rng)
    end

    if can_morph_rock_entry(virtualRoom, spawnEntry, gridIdx) then
        if try_dirty_mind_morph(roomData, spawnEntry, rockSeed) then
            return
        end
    end

    if spawnEntry.Type == StbGridType.TNT and rng:RandomInt(10) == 0 then
        spawnEntry.Type = EntityType.ENTITY_MOVABLE_TNT
        spawnEntry.Variant = 0
        spawnEntry.Subtype = 0
        return
    end

    if (spawnEntry.Type == StbGridType.TRAP_DOOR or (spawnEntry.Type == STB_EFFECT and spawnEntry.Variant == EffectVariant.HEAVEN_LIGHT_DOOR)) then
        if not can_spawn_trapdoor(roomDesc, roomData) then
            spawnEntry.Type = StbGridType.COBWEB
            spawnEntry.Variant = 0
            spawnEntry.Subtype = 0
            return
        end

        if g_Level:HasMirrorDimension() and roomDesc:GetDimension() == Dimension.KNIFE_PUZZLE then
            spawnEntry.Type = StbGridType.DECORATION
            spawnEntry.Variant = 0
            spawnEntry.Subtype = 0
            return
        end
    end

    if spawnEntry.Type == EntityType.ENTITY_SHOPKEEPER then
        if spawnEntry.Variant == 0 and rng:RandomInt(4) == 0 and g_PersistentGameData:Unlocked(Achievement.SPECIAL_SHOPKEEPERS) then
            spawnEntry.Variant = 3
        end

        if spawnEntry.Variant == 1 and rng:RandomInt(4) == 0 and g_PersistentGameData:Unlocked(Achievement.SPECIAL_HANGING_SHOPKEEPERS) then
            spawnEntry.Variant = 4
        end
    end

    if spawnEntry.Type == StbGridType.DEVIL_STATUE and g_BossPool.GetRemovedBosses()[BossType.SATAN] then
        spawnEntry.Type = StbGridType.ROCK
        spawnEntry.Variant = 0
        spawnEntry.Subtype = 1
        return
    end
end

--#endregion

--#region Build SpawnDesc

--#region Build EntityDesc

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@return boolean cleared
local function consider_room_cleared(roomDesc, roomData, spawnEntry)
    if roomDesc.Flags & RoomDescriptor.FLAG_CLEAR ~= 0 then
        return true
    end

    if roomData == RoomType.ROOM_BOSS and (roomDesc.Flags & RoomDescriptor.FLAG_ROTGUT_CLEARED) ~= 0 then
        return spawnEntry.Type ~= EntityType.ENTITY_ROTGUT
    end

    return false
end

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param respawning boolean
---@return boolean
local function can_spawn_entity(roomDesc, roomData, spawnEntry, respawning)
    if not consider_room_cleared(roomDesc, roomData, spawnEntry) or respawning then
        return true
    end

    if Lib.Room.IsPersistentRoomEntity(spawnEntry.Type, spawnEntry.Variant) then
        return true
    end

    if Lib.Room.ShouldSaveEntity(spawnEntry.Type, spawnEntry.Variant, spawnEntry.Subtype, EntityType.ENTITY_NULL, true) then
        return true
    end

    if g_Seeds:HasSeedEffect(SeedEffect.SEED_PACIFIST) or g_Seeds:HasSeedEffect(SeedEffect.SEED_ENEMIES_RESPAWN) then
        return true
    end

    return false
end

---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param rng RNG
---@param respawning boolean
---@return SpawnDesc?
local function build_entity_spawn(roomDesc, roomData, spawnEntry, rng, respawning)
    if spawnEntry.Type == STB_EFFECT then
        spawnEntry.Type = EntityType.ENTITY_EFFECT
    end

    if spawnEntry.Type == EntityType.ENTITY_ENVIRONMENT then
        return
    end

    if spawnEntry.Type == EntityType.ENTITY_TRIGGER_OUTPUT then
        ---@type SpawnDesc
        return {spawnType = 0, entityDesc = nil, addOutput = true}
    end

    if spawnEntry.Type == EntityType.ENTITY_PICKUP and Lib.Level.IsCorpseEntrance(g_Level) then
        return
    end

    if spawnEntry.Type == EntityType.ENTITY_MINECART and (roomDesc.Flags & RoomDescriptor.FLAG_SACRIFICE_DONE ~= 0) then -- ???
        return
    end

    if not can_spawn_entity(roomDesc, roomData, spawnEntry, respawning) then
        return
    end

    ---@type EntitySpawnDesc
    local entityDesc = {type = spawnEntry.Type, variant = spawnEntry.Variant, subType = spawnEntry.Subtype, initSeed = rng:Next()}

    ---@type SpawnDesc
    return {spawnType = 1, entityDesc = entityDesc}
end

--#endregion

--#region Build GridSpawnDesc

local s_StbGridConversion = {
    [StbGridType.ROCK] = {GridEntityType.GRID_ROCK},
    [StbGridType.BOMB_ROCK] = {GridEntityType.GRID_ROCK_BOMB},
    [StbGridType.ALT_ROCK] = {GridEntityType.GRID_ROCK_ALT},
    [StbGridType.TINTED_ROCK] = {GridEntityType.GRID_ROCKT},
    [StbGridType.MARKED_SKULL] = {GridEntityType.GRID_ROCK_ALT2},
    [StbGridType.EVENT_ROCK] = {GridEntityType.GRID_ROCK, 10000},
    [StbGridType.SPIKE_ROCK] = {GridEntityType.GRID_ROCK_SPIKED},
    [StbGridType.FOOLS_GOLD_ROCK] = {GridEntityType.GRID_ROCK_GOLD},
    [StbGridType.TNT] = {GridEntityType.GRID_TNT},
    [GRID_FIREPLACE] = {GridEntityType.GRID_FIREPLACE, 0},
    [GRID_FIREPLACE_RED] = {GridEntityType.GRID_FIREPLACE, 1},
    [StbGridType.RED_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.RED},
    [StbGridType.RAINBOW_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.RAINBOW},
    [StbGridType.CORN_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.CORN},
    [StbGridType.GOLDEN_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.GOLDEN},
    [StbGridType.BLACK_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.BLACK},
    [StbGridType.HOLY_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.HOLY},
    [StbGridType.GIANT_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.GIANT_TL},
    [StbGridType.POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.NORMAL},
    [StbGridType.CHARMING_POOP] = {GridEntityType.GRID_POOP, GridPoopVariant.CHARMING},
    [StbGridType.BLOCK] = {GridEntityType.GRID_ROCKB},
    [StbGridType.PILLAR] = {GridEntityType.GRID_PILLAR},
    [StbGridType.SPIKES] = {GridEntityType.GRID_SPIKES},
    [StbGridType.RETRACTING_SPIKES] = {GridEntityType.GRID_SPIKES_ONOFF},
    [StbGridType.COBWEB] = {GridEntityType.GRID_SPIDERWEB},
    [StbGridType.INVISIBLE_BLOCK] = {GridEntityType.GRID_WALL},
    [StbGridType.PIT] = {GridEntityType.GRID_PIT},
    [3001] = {GridEntityType.GRID_PIT},
    [StbGridType.EVENT_RAIL] = {GridEntityType.GRID_PIT},
    [StbGridType.EVENT_PIT] = {GridEntityType.GRID_PIT, 128},
    [StbGridType.KEY_BLOCK] = {GridEntityType.GRID_LOCK},
    [StbGridType.PRESSURE_PLATE] = {GridEntityType.GRID_PRESSURE_PLATE},
    [StbGridType.DEVIL_STATUE] = {GridEntityType.GRID_STATUE, 0},
    [StbGridType.ANGEL_STATUE] = {GridEntityType.GRID_STATUE, 1},
    [StbGridType.RAIL_PIT] = {GridEntityType.GRID_PIT},
    [StbGridType.TELEPORTER] = {GridEntityType.GRID_TELEPORTER},
    [StbGridType.TRAP_DOOR] = {GridEntityType.GRID_TRAPDOOR, 0},
    [StbGridType.CRAWLSPACE] = {GridEntityType.GRID_STAIRS},
    [StbGridType.GRAVITY] = {GridEntityType.GRID_GRAVITY},
}

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

    local roomWidth = virtualRoom.width
    local roomHeight = virtualRoom.height

    local goldVeinPosition = Vector(rng:RandomFloat() * roomHeight, rng:RandomFloat() * roomHeight)
    local gridToVeinPosition = goldVeinPosition - Lib.Grid.GetCoordinatesFromGridIdx(gridIdx, roomWidth)
    local veinSize = get_gold_vein_size(rng)
    gridToVeinPosition = gridToVeinPosition:Rotated(rng:RandomFloat() * 360.0)
    gridToVeinPosition = gridToVeinPosition / veinSize

    return gridToVeinPosition:LengthSquared() <= 1.0
end

---@param rng RNG
---@return GridEntityType
local function init_tinted_rock(rng)
    if rng:RandomInt(20) == 0 and g_PersistentGameData:Unlocked(Achievement.SUPER_SPECIAL_ROCKS) then
        return GridEntityType.GRID_ROCK_SS
    end

    return GridEntityType.GRID_ROCKT
end

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param spawnEntry SpawnEntry
---@param gridIdx integer
---@param rng RNG
---@return GridEntityType
local function do_rock_morph(virtualRoom, roomDesc, spawnEntry, gridIdx, rng)
    assert(spawnEntry.Type == StbGridType.ROCK)

    local foolsRockMorph = g_PersistentGameData:Unlocked(Achievement.FOOLS_GOLD) and is_grid_idx_in_gold_vein(virtualRoom, gridIdx, roomDesc.DecorationSeed)

    local randomNumber = rng:RandomInt(1001)
    if virtualRoom.tintedRockIdx == gridIdx then
        return init_tinted_rock(rng)
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

---@param variant GridPoopVariant
---@param rng RNG
---@return GridPoopVariant
local function do_poop_morph(variant, rng)
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

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param gridIdx integer
---@param rng RNG
---@param seed integer
---@param respawning boolean
---@return SpawnDesc?
local function build_grid_entity_spawn(virtualRoom, roomDesc, roomData, spawnEntry, gridIdx, rng, seed, respawning)
    if respawning then
        return
    end

    if spawnEntry.Type == StbGridType.RAIL then
        ---@type SpawnDesc
        return {spawnType = 0, entityDesc = nil, initRail = true}
    end

    local initRail = false
    if spawnEntry.Type == StbGridType.RAIL_PIT then
        initRail = true
        spawnEntry.Type = StbGridType.PIT
    end

    ---@type GridSpawnDesc
    local gridEntityDesc = {
        type = 0,
        variant = 0,
        varData = 0,
        spawnSeed = 0,
        spawnFissureSpawner = false,
        fissureSpawnerSeed = 0,
        increasePitCount = false,
        increasePoopCount = false,
    }

    local convertedGrid = s_StbGridConversion[spawnEntry.Type] or {GridEntityType.GRID_DECORATION}
    gridEntityDesc.type = convertedGrid[1]
    gridEntityDesc.variant = convertedGrid[2] or spawnEntry.Variant
    gridEntityDesc.varData = spawnEntry.Type == StbGridType.TRAP_DOOR and spawnEntry.Variant or 0

    if spawnEntry.Type == 3001 then
        gridEntityDesc.spawnFissureSpawner = true
        gridEntityDesc.fissureSpawnerSeed = rng:Next()
    end

    gridEntityDesc.increasePitCount = gridEntityDesc.type == GridEntityType.GRID_PIT
    gridEntityDesc.increasePoopCount = gridEntityDesc.type == GridEntityType.GRID_POOP

    if gridEntityDesc.type == GridEntityType.GRID_ROCK_GOLD and not g_PersistentGameData:Unlocked(Achievement.FOOLS_GOLD) then
        gridEntityDesc.type = GridEntityType.GRID_ROCK
    end

    local mineshaftChase = has_room_config_flags(roomData, 1 << 1)

    if spawnEntry.Type == StbGridType.ROCK and not mineshaftChase and spawnEntry.Subtype == 0 then
        gridEntityDesc.type = do_rock_morph(virtualRoom, roomDesc, spawnEntry, gridIdx, rng)
    end

    if gridEntityDesc.type == GridEntityType.GRID_POOP and not mineshaftChase and spawnEntry.Subtype == 0 then
        gridEntityDesc.variant = do_poop_morph(gridEntityDesc.variant, rng)
    end

    gridEntityDesc.spawnSeed = seed
    ---@type SpawnDesc
    return {spawnType = 2, entityDesc = gridEntityDesc, initRail = initRail}
end

--#endregion

--#endregion

---Virtual Room needs to be partially initialized (InitRoomData from room_loader module + tintedRockIdx)
---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry RoomConfig_Entry
---@param seed integer
---@param respawning boolean
---@return SpawnDesc?
local function BuildSpawnDesc(virtualRoom, roomDesc, roomData, gridIdx, spawnEntry, seed, respawning)
    local rng = RNG(seed, 35)
    local type, variant, subtype = EntityRedirection.FixSpawnEntry(virtualRoom, spawnEntry.Type, spawnEntry.Variant, spawnEntry.Subtype, gridIdx, seed)

    ---@type SpawnEntry
    local fixedSpawnEntry = {Type = type, Variant = variant, Subtype = subtype}

    if try_block_spawn(roomDesc, roomData, fixedSpawnEntry, respawning) then
        return
    end

    try_morph_spawn(virtualRoom, roomDesc, roomData, fixedSpawnEntry, gridIdx, rng)

    if fixedSpawnEntry.Type == EntityType.ENTITY_ENVIRONMENT then
        return
    end

    if 1 <= fixedSpawnEntry.Type and fixedSpawnEntry.Type <= 999 then
        return build_entity_spawn(roomDesc, roomData, fixedSpawnEntry, rng, respawning)
    else
        return build_grid_entity_spawn(virtualRoom, roomDesc, roomData, fixedSpawnEntry, gridIdx, rng, seed, respawning)
    end
end

--#region Module

SpawnReader.BuildSpawnDesc = BuildSpawnDesc

--#endregion

return SpawnReader