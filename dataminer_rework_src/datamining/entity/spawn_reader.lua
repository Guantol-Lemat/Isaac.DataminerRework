---@class SpawnReader
local SpawnReader = {}

---@class SpawnEntry
---@field Type EntityType | StbType | integer
---@field Variant integer
---@field Subtype integer

local STB_EFFECT = 999
local GRID_FIREPLACE = 1400
local GRID_FIREPLACE_RED = 1401

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_Seeds = g_Game:GetSeeds()
local g_PersistentGameData = Isaac.GetPersistentGameData()

local Lib = {
    Level = require("lib.level"),
    Room = require("lib.room"),
}

local EntityRedirection = require("datamining.entity.entity_redirection")
local SpawnMorph = require("datamining.spawn_systems.spawn_morph")
local SpawnCommandsUtils = require("datamining.entity.spawn_commands")

--#endregion

---@param roomData RoomConfigRoom
---@param flags integer
---@return boolean
local function has_room_config_flags(roomData, flags)
    return false -- inaccessible
end

---@param spawnEntry SpawnEntry
---@param morphEntry MorphEntry?
---@return boolean
local function try_morph(spawnEntry, morphEntry)
    if not morphEntry then
        return false
    end

    spawnEntry.Type = morphEntry.Type or spawnEntry.Type
    spawnEntry.Variant = morphEntry.Variant or spawnEntry.Variant
    spawnEntry.Subtype = morphEntry.Subtype or spawnEntry.Subtype

    return true
end

--#region SpawnEntry Block

---@param roomData RoomConfigRoom
---@return boolean
local function is_knife_treasure_room(roomData)
    return roomData.Type == RoomType.ROOM_TREASURE and roomData.Subtype == RoomSubType.TREASURE_KNIFE_PIECE
end

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param respawning boolean
local function block_spawn(roomDesc, roomData, spawnEntry, respawning)
    if spawnEntry.Type == EntityType.ENTITY_PICKUP and spawnEntry.Variant == PickupVariant.PICKUP_COLLECTIBLE and
       roomDesc.SafeGridIndex == GridRooms.ROOM_GENESIS_IDX then
        return true
    end

    if spawnEntry.Type == EntityType.ENTITY_PICKUP and not respawning and
       g_Level:HasMirrorDimension() and roomDesc.m_Dimension == Dimension.KNIFE_PUZZLE and
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

--#region Morph Spawn

---@param virtualRoom VirtualRoom
---@param spawnEntry SpawnEntry
---@param gridIdx integer
---@return boolean
local function can_morph_rock_entry(virtualRoom, spawnEntry, gridIdx)
    return ((spawnEntry.Type == StbGridType.ROCK and virtualRoom.m_TintedRockIdx ~= gridIdx)) or spawnEntry.Type == StbGridType.BOMB_ROCK or spawnEntry.Type == StbGridType.ALT_ROCK
end

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param rng RNG
---@param gridIdx integer
local function morph_spawn(virtualRoom, roomDesc, roomData, spawnEntry, gridIdx, rng)
    if spawnEntry.Type == StbGridType.ROCK and virtualRoom.m_TintedRockIdx == gridIdx then
        return
    end

    local rockSeed = rng:GetSeed()

    local dangerousGridMorph = has_room_config_flags(roomData, 1 << 3)
    if dangerousGridMorph and can_morph_rock_entry(virtualRoom, spawnEntry, gridIdx) then
        try_morph(spawnEntry, SpawnMorph.DangerousRockMorph(roomData, rng))
    end

    if can_morph_rock_entry(virtualRoom, spawnEntry, gridIdx) then
        try_morph(spawnEntry, SpawnMorph.DirtyMindMorph(roomData, rockSeed))
    end

    if spawnEntry.Type == StbGridType.TNT then
        try_morph(spawnEntry, SpawnMorph.TntMorph(rng))
    end

    if (spawnEntry.Type == StbGridType.TRAP_DOOR or (spawnEntry.Type == STB_EFFECT and spawnEntry.Variant == EffectVariant.HEAVEN_LIGHT_DOOR)) then
        try_morph(spawnEntry, SpawnMorph.TrapdoorMorph(roomDesc, roomData))
    end

    if spawnEntry.Type == EntityType.ENTITY_SHOPKEEPER and spawnEntry.Variant == 0 then
        if spawnEntry.Variant == 0 then
            try_morph(spawnEntry, SpawnMorph.ShopkeeperMorph(rng))
        end

        if spawnEntry.Variant == 1 then
            try_morph(spawnEntry, SpawnMorph.HangingShopkeeperMorph(rng))
        end
    end

    if spawnEntry.Type == StbGridType.DEVIL_STATUE then
        try_morph(spawnEntry, SpawnMorph.DevilStatueMorph())
    end
end

--#endregion

--#region Resolve Entity Spawn

---@param roomDesc VirtualRoomDescriptor
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

---@param roomDesc VirtualRoomDescriptor
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

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param rng RNG
---@param respawning boolean
---@param spawnCommands SpawnCommands
local function resolve_entity(virtualRoom, roomDesc, roomData, spawnEntry, gridIdx, rng, respawning, spawnCommands)
    if spawnEntry.Type == STB_EFFECT then
        spawnEntry.Type = EntityType.ENTITY_EFFECT
    end

    if spawnEntry.Type == EntityType.ENTITY_ENVIRONMENT then
        return
    end

    if spawnEntry.Type == EntityType.ENTITY_TRIGGER_OUTPUT then
        local gridPosition = Lib.Room.GetGridPosition(gridIdx, virtualRoom.m_Width)
        SpawnCommandsUtils.AddOutput(spawnCommands, spawnEntry.Variant, Vector(gridPosition.X - 1, gridPosition.Y))
        SpawnCommandsUtils.AddOutput(spawnCommands, spawnEntry.Variant, Vector(gridPosition.X + 1, gridPosition.Y))
        SpawnCommandsUtils.AddOutput(spawnCommands, spawnEntry.Variant, Vector(gridPosition.X, gridPosition.Y - 1))
        SpawnCommandsUtils.AddOutput(spawnCommands, spawnEntry.Variant, Vector(gridPosition.X, gridPosition.Y + 1))
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

    SpawnCommandsUtils.SpawnEntity(spawnCommands, spawnEntry.Type, spawnEntry.Variant, spawnEntry.Subtype, rng:Next(), Lib.Room.GetGridPosition(gridIdx, virtualRoom.m_Width), Vector.Zero, nil)
end

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

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry SpawnEntry
---@param gridIdx integer
---@param rng RNG
---@param seed integer
---@param respawning boolean
---@param spawnCommands SpawnCommands
local function resolve_grid_entity(virtualRoom, roomDesc, roomData, spawnEntry, gridIdx, rng, seed, respawning, spawnCommands)
    if respawning then
        return
    end

    if spawnEntry.Type == StbGridType.RAIL then
        SpawnCommandsUtils.SetRail(spawnCommands, gridIdx, spawnEntry.Variant)
        return
    end

    if spawnEntry.Type == StbGridType.RAIL_PIT then
        SpawnCommandsUtils.SetRail(spawnCommands, gridIdx, spawnEntry.Variant)
        spawnEntry.Type = StbGridType.PIT
        spawnEntry.Variant = 0
    end

    local gridType = 0
    local variant = 0
    local varData = 0

    local convertedGrid = s_StbGridConversion[spawnEntry.Type] or {GridEntityType.GRID_DECORATION}
    gridType = convertedGrid[1]
    variant = convertedGrid[2] or spawnEntry.Variant
    varData = spawnEntry.Type == StbGridType.TRAP_DOOR and spawnEntry.Variant or 0

    if spawnEntry.Type == 3001 then
        local gridPosition = Lib.Room.GetGridPosition(gridIdx, virtualRoom.m_Width)
        SpawnCommandsUtils.SpawnEntity(spawnCommands, EntityType.ENTITY_EFFECT, EffectVariant.FISSURE_SPAWNER, spawnEntry.Subtype, rng:Next(), gridPosition, Vector.Zero, nil)
    end

    if gridType == GridEntityType.GRID_ROCK_GOLD and not g_PersistentGameData:Unlocked(Achievement.FOOLS_GOLD) then
        gridType = GridEntityType.GRID_ROCK
    end

    local mineshaftChase = has_room_config_flags(roomData, 1 << 1)

    if spawnEntry.Type == StbGridType.ROCK and not mineshaftChase and spawnEntry.Subtype == 0 then
        gridType = SpawnMorph.RockMorph(virtualRoom, roomDesc, gridIdx, rng)
    end

    if gridType == GridEntityType.GRID_POOP and not mineshaftChase and spawnEntry.Subtype == 0 then
        variant = SpawnMorph.PoopMorph(variant, rng)
    end

    SpawnCommandsUtils.SpawnGridEntity(spawnCommands, gridIdx, gridType, variant, seed, varData)
end

--#endregion

---@param virtualRoom VirtualRoom -- Metadata + tintedRockIdx needs to be initialized to behave correctly
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnEntry RoomConfig_Entry
---@param seed integer
---@param respawning boolean
---@param spawnCommands SpawnCommands
local function SpawnEntity(virtualRoom, roomDesc, roomData, gridIdx, spawnEntry, seed, respawning, spawnCommands)
    local rng = RNG(seed, 35)
    local entityType, variant, subtype = EntityRedirection.FixSpawnEntry(virtualRoom, spawnEntry.Type, spawnEntry.Variant, spawnEntry.Subtype, gridIdx, seed)

    ---@type SpawnEntry
    local fixedSpawnEntry = {Type = entityType, Variant = variant, Subtype = subtype}

    if block_spawn(roomDesc, roomData, fixedSpawnEntry, respawning) then
        return
    end

    morph_spawn(virtualRoom, roomDesc, roomData, fixedSpawnEntry, gridIdx, rng)

    if fixedSpawnEntry.Type == EntityType.ENTITY_ENVIRONMENT then
        return
    end

    if 1 <= fixedSpawnEntry.Type and fixedSpawnEntry.Type <= 999 then
        resolve_entity(virtualRoom, roomDesc, roomData, fixedSpawnEntry, gridIdx, rng, respawning, spawnCommands)
    else
        resolve_grid_entity(virtualRoom, roomDesc, roomData, fixedSpawnEntry, gridIdx, rng, seed, respawning, spawnCommands)
    end
end

--#region Module

SpawnReader.SpawnEntity = SpawnEntity

--#endregion

return SpawnReader