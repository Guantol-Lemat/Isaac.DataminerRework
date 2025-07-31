---@class VirtualRoomQueries
local VirtualRoomQueries = {}

--#region Dependencies

local g_ItemPool = Game():GetItemPool()

local Lib = {
    ItemPool = require("lib.itempool"),
}

local CustomCallbacks = require("callbacks")

--#endregion

---@param virtualRoom VirtualRoom
---@param itemPool ItemPoolType
local function SetItemPool(virtualRoom, itemPool)
    virtualRoom.m_ItemPool = itemPool
end

if DATAMINER_DEBUG_MODE then
    local oldSetItemPool = SetItemPool
    ---@param virtualRoom VirtualRoom
    ---@param itemPool ItemPoolType
    SetItemPool = function(virtualRoom, itemPool)
        assert(ItemPoolType.POOL_NULL <= itemPool and itemPool < g_ItemPool:GetNumItemPools(), "Invalid item pool type")
        return oldSetItemPool(virtualRoom, itemPool)
    end
end

---@param virtualRoom VirtualRoom
---@param seed integer
local function GetPoolForRoom(virtualRoom, seed)
    if virtualRoom.m_ItemPool ~= ItemPoolType.POOL_NULL then
        return virtualRoom.m_ItemPool
    end

    local roomDesc = virtualRoom.m_RoomDescriptor
    local pool = Lib.ItemPool.GetPoolForRoomData(seed, roomDesc.Data, roomDesc.Flags, roomDesc.GridIndex, 0)
    pool = pool ~= ItemPoolType.POOL_NULL and pool or ItemPoolType.POOL_TREASURE
    return pool
end

---@param virtualRoom VirtualRoom
---@param seed integer
---@param advanceRNG boolean
---@return CollectibleType | integer
local function GetSeededCollectible(virtualRoom, seed, advanceRNG)
    local pool = GetPoolForRoom(virtualRoom, seed)
    return g_ItemPool:GetCollectible(pool, false, seed, CollectibleType.COLLECTIBLE_NULL)
end

---@param virtualRoom VirtualRoom
---@return integer
local function GetFrameCount(virtualRoom)
    return 0
end

---@param virtualRoom VirtualRoom
---@return Vector
local function GetCenterPos(virtualRoom)
    return Vector(0, 0)
end

--#region Module

VirtualRoomQueries.SetItemPool = SetItemPool
VirtualRoomQueries.GetPoolForRoom = GetPoolForRoom
VirtualRoomQueries.GetSeededCollectible = GetSeededCollectible
VirtualRoomQueries.GetFrameCount = GetFrameCount
VirtualRoomQueries.GetCenterPos = GetCenterPos

--#endregion

return VirtualRoomQueries