---@class VirtualRoomCore
local VirtualRoom = {}

--#region Dependencies

local Lib = {
    Room = require("lib.room"),
    ItemPool = require("lib.itempool")
}

local VirtualShop = require("datamining.virtual_shop")
local RoomLoader = require("datamining.room_loader")
local PickupInitializer = require("datamining.pickup_initializer")
local CustomCallbacks = require("callbacks")

--#endregion

---@class VirtualRoom
---@field m_IsInitialized boolean
---@field m_RoomDescriptor VirtualRoomDescriptor
---@field m_RoomType RoomType
---@field m_RoomIdx GridRooms | integer
---@field m_Width integer
---@field m_Height integer
---@field m_DoorGridIdx integer[]
---@field m_TintedRockIdx integer
---@field m_BossID BossType | integer
---@field m_SecondBossID BossType | integer
---@field m_LayoutData LayoutData
---@field m_DamoclesItemSpawned boolean
---@field m_DamoclesItems VirtualPickup[] -- List of damocles items specifically since we do not care of keeping track of all initialized entities in the virtual room
---@field m_Shop VirtualShop
---@field m_ItemPool ItemPoolType -- The item pool for this room, for compatibility with Repentogon's SetItemPool

---@class SpawnStrategy
---@field SpawnEntity fun(self: SpawnStrategy, virtualRoom: VirtualRoom, entityType: integer, variant: integer, subtype: integer, initSeed: integer) | nil
---@field SpawnGridEntity fun(self: SpawnStrategy, virtualRoom: VirtualRoom, spawn: GridSpawnDesc)?

---@param virtualRoom VirtualRoom
local function reset(virtualRoom)
    virtualRoom.m_IsInitialized = false
---@diagnostic disable-next-line: assign-type-mismatch
    virtualRoom.m_RoomDescriptor = nil
    virtualRoom.m_RoomType = RoomType.ROOM_DEFAULT
    virtualRoom.m_RoomIdx = 0
    virtualRoom.m_Width = 0
    virtualRoom.m_Height = 0
    virtualRoom.m_DoorGridIdx = {}
    virtualRoom.m_TintedRockIdx = -1
    virtualRoom.m_BossID = 0
    virtualRoom.m_SecondBossID = 0
    virtualRoom.m_LayoutData = {entities = {}, gridEntities = {}}
    virtualRoom.m_DamoclesItemSpawned = false
    virtualRoom.m_DamoclesItems = {}
    virtualRoom.m_Shop = VirtualShop.Create(virtualRoom)
    virtualRoom.m_ItemPool = ItemPoolType.POOL_NULL
end

---@return VirtualRoom
local function Create()
    local virtualRoom = {}
    reset(virtualRoom)

    return virtualRoom
end

local s_ActiveVirtualRooms = setmetatable({}, { __mode = "k" })
local function count_active_virtual_rooms()
    local count = 0
    for _ in pairs(s_ActiveVirtualRooms) do
        count = count + 1
    end
    return count
end

---Record created object to check for memory leaks
if DATAMINER_DEBUG_MODE then
    local old_create_virtual_room = Create
    ---@return VirtualRoom
    Create = function()
        local virtualRoom = old_create_virtual_room()
        s_ActiveVirtualRooms[virtualRoom] = true
        return virtualRoom
    end
end

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
local function init_room_metadata(virtualRoom, roomDesc, roomData)
    virtualRoom.m_Width = roomData.Width + 2
    virtualRoom.m_Height = roomData.Height + 2

    for i = 1, DoorSlot.NUM_DOOR_SLOTS, 1 do
        virtualRoom.m_DoorGridIdx[i] = Lib.Room.GetDoorGridIndex(i - 1, virtualRoom.m_Width, virtualRoom.m_Height, roomDesc.Data.Shape)
    end

    virtualRoom.m_RoomDescriptor = roomDesc
    virtualRoom.m_RoomType = roomDesc.Data.Type

    virtualRoom.m_BossID = 0
    virtualRoom.m_SecondBossID = 0
    if virtualRoom.m_RoomType == RoomType.ROOM_BOSS then
        virtualRoom.m_BossID, virtualRoom.m_SecondBossID = Lib.Room.GetBossID(roomDesc.Data)
    end

    virtualRoom.m_RoomIdx = roomDesc.SafeGridIndex
end

---@param virtualRoom VirtualRoom
---@param spawnStrategy SpawnStrategy
local function spawn_entities(virtualRoom, spawnStrategy)
    if not spawnStrategy.SpawnEntity then
        return
    end

    for _, spawn in ipairs(virtualRoom.m_LayoutData.entities) do
        local entityType, variant, subtype, initSeed = CustomCallbacks.RunPreEntitySpawn(spawn.type, spawn.variant, spawn.subType, spawn.position, Vector(0, 0), nil, spawn.initSeed, virtualRoom)
        spawnStrategy:SpawnEntity(virtualRoom, entityType, variant, subtype, initSeed)
    end
end

---@param virtualRoom VirtualRoom
---@param spawnStrategy SpawnStrategy
local function spawn_grid_entities(virtualRoom, spawnStrategy)
    if not spawnStrategy.SpawnGridEntity then
        return
    end

    for _, spawn in ipairs(virtualRoom.m_LayoutData.gridEntities) do
        spawnStrategy:SpawnGridEntity(virtualRoom, spawn)
    end
end

---@param virtualPickup VirtualPickup
---@param spawnStrategy SpawnStrategy
local function handle_damocles_item(virtualPickup, spawnStrategy)
    virtualPickup.m_Flags = virtualPickup.m_Flags & ~EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE

    local rng = RNG(virtualPickup.InitSeed, 21)
    rng:RandomFloat() -- unused but ultimately modifies the seed
    rng:RandomFloat() -- unused but ultimately modifies the seed

    local entityType, variant, subtype, initSeed = CustomCallbacks.RunPreEntitySpawn(virtualPickup.m_Type, virtualPickup.Variant, 0, Vector(0, 0), Vector(0, 0), nil, rng:Next(), virtualPickup.m_Room)
    spawnStrategy:SpawnEntity(virtualPickup.m_Room, entityType, variant, subtype, initSeed)
end

---@param virtualRoom VirtualRoom
---@param spawnStrategy SpawnStrategy
local function handle_damocles_items(virtualRoom, spawnStrategy)
    if not spawnStrategy.SpawnEntity then
        return
    end

    for _, item in ipairs(virtualRoom.m_DamoclesItems) do
        handle_damocles_item(item, spawnStrategy)
    end
end

---@param virtualRoom VirtualRoom
---@param spawnResolver SpawnStrategy
local function spawn_layout(virtualRoom, spawnResolver)
    spawn_entities(virtualRoom, spawnResolver)
    spawn_grid_entities(virtualRoom, spawnResolver)
end

---@param virtualRoom VirtualRoom
---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param spawnStrategy SpawnStrategy
local function InitRoom(virtualRoom, roomDesc, roomData, spawnStrategy)
    reset(virtualRoom)
    init_room_metadata(virtualRoom, roomDesc, roomData)
    virtualRoom.m_LayoutData = RoomLoader.LoadRoomLayoutData(virtualRoom, roomDesc, roomData)
    spawn_layout(virtualRoom, spawnStrategy)
    virtualRoom.m_IsInitialized = true
end

---@param virtualRoom VirtualRoom
---@param spawnStrategy SpawnStrategy
local function Update(virtualRoom, spawnStrategy)
    if virtualRoom.m_DamoclesItemSpawned then
        PickupInitializer.BeginIgnoreModifiers()
        handle_damocles_items(virtualRoom, spawnStrategy)
        PickupInitializer.EndIgnoreModifiers()
    end
    virtualRoom.m_DamoclesItems = {}
    virtualRoom.m_DamoclesItemSpawned = false
end

--#region Module

VirtualRoom.CreateVirtualRoom = Create
VirtualRoom.InitRoom = InitRoom
VirtualRoom.Update = Update

if DATAMINER_DEBUG_MODE then
    VirtualRoom.count_active_virtual_rooms = count_active_virtual_rooms
end

--#endregion

return VirtualRoom