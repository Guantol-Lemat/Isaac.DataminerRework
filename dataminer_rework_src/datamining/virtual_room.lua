---@class VirtualRoomModule
local VirtualRoom = {}

--#region Dependencies

local Lib = {
    Room = require("dataminer_rework_src.lib.room"),
    ItemPool = require("dataminer_rework_src.lib.itempool")
}

local VirtualShop = require("dataminer_rework_src.datamining.virtual_shop")

--#endregion

---@class VirtualRoom
---@field isInitialized boolean
---@field roomDescriptor RoomDescriptor
---@field roomType RoomType
---@field roomIdx GridRooms | integer
---@field width integer
---@field height integer
---@field doorGridIdx integer[]
---@field awardSeed integer
---@field tintedRockIdx integer
---@field layoutData LayoutData
---@field damoclesItemSpawned boolean
---@field shop VirtualShop

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
        awardSeed = 0,
        tintedRockIdx = -1,
        layoutData = {entities = {}, gridEntities = {}},
        damoclesItemSpawned = false,
---@diagnostic disable-next-line: assign-type-mismatch
        shop = nil
    }

    virtualRoom.shop = VirtualShop.NewVirtualShop(virtualRoom)

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
    virtualRoom.awardSeed = roomDesc.AwardSeed
    virtualRoom.shop = VirtualShop.NewVirtualShop(virtualRoom)
end

---@param virtualRoom VirtualRoom
---@param seed integer
---@param advanceRNG boolean
---@return CollectibleType | integer
local function GetSeededCollectible(virtualRoom, seed, advanceRNG)
    return Lib.ItemPool.GetSeededCollectible(virtualRoom.roomDescriptor, seed, advanceRNG)
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