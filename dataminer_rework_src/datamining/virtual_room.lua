---@class VirtualRoomModule
local VirtualRoom = {}

--#region Dependencies

local g_ItemPool = Game():GetItemPool()

local Lib = {
    Room = require("dataminer_rework_src.lib.room"),
    ItemPool = require("dataminer_rework_src.lib.itempool")
}

--#endregion

---@class VirtualRoom
---@field isInitialized boolean
---@field roomDescriptor RoomDescriptor
---@field roomType RoomType
---@field roomIdx GridRooms | integer
---@field width integer
---@field height integer
---@field doorGridIdx integer[]
---@field tintedRockIdx integer
---@field layoutData LayoutData
---@field damoclesItemSpawned boolean

---@return VirtualRoom
local function NewVirtualRoom()
    ---@type VirtualRoom
    local virtualRoom = {
        isInitialized = false,
---@diagnostic disable-next-line: assign-type-mismatch
        roomDescriptor = nil,
        roomType = RoomType.ROOM_DEFAULT,
        roomIdx = 0,
        width = 0,
        height = 0,
        doorGridIdx = {},
        tintedRockIdx = -1,
        layoutData = {entities = {}, gridEntities = {}},
        damoclesItemSpawned = false
    }

    return virtualRoom
end

---@param virtualRoom VirtualRoom
---@param roomDesc RoomDescriptor
---@param roomData RoomConfigRoom
local function InitRoomData(virtualRoom, roomDesc, roomData)
    virtualRoom.isInitialized = false
    virtualRoom.tintedRockIdx = -1
    virtualRoom.layoutData = {entities = {}, gridEntities = {}}
    virtualRoom.damoclesItemSpawned = false

    virtualRoom.width = roomData.Width + 2
    virtualRoom.height = roomData.Height + 2

    for i = 1, DoorSlot.NUM_DOOR_SLOTS, 1 do
        virtualRoom.doorGridIdx[i] = Lib.Room.GetDoorGridIndex(i - 1, virtualRoom.width, virtualRoom.height, roomDesc.Data.Shape)
    end

    virtualRoom.roomDescriptor = roomDesc
    virtualRoom.roomType = roomDesc.Data.Type
    virtualRoom.roomIdx = roomDesc.SafeGridIndex
end

---@param virtualRoom VirtualRoom
---@param seed integer
---@param advanceRNG boolean
---@return CollectibleType | integer
local function GetSeededCollectible(virtualRoom, seed, advanceRNG)
    local poolType = Lib.ItemPool.GetPoolForRoom(seed, virtualRoom.roomDescriptor, 0)
    if poolType == ItemPoolType.POOL_NULL then
        poolType = ItemPoolType.POOL_TREASURE
    end

    return g_ItemPool:GetCollectible(poolType, not advanceRNG, seed, CollectibleType.COLLECTIBLE_NULL)
end

local function GetFrameCount(virtualRoom)
    return 0
end

--#region Module

VirtualRoom.NewVirtualRoom = NewVirtualRoom
VirtualRoom.InitRoomData = InitRoomData
VirtualRoom.GetFrameCount = GetFrameCount
VirtualRoom.GetSeededCollectible = GetSeededCollectible

--#endregion

return VirtualRoom