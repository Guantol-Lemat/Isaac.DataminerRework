---@class CommonDatamineStrategyUtils
local CommonDatamineStrategyUtils = {}

--#region Dependencies

local g_ItemConfig = Isaac.GetItemConfig()

local Lib = {
    ItemConfig = require("lib.item_config"),
}
local PickupInitializer = require("datamining.entity.pickup_initializer")

--#endregion

---@class DataminedCollectibleData
---@field collectibleType CollectibleType | integer
---@field price PickupPrice | integer
---@field originalPrice PickupPrice | integer

---@class DataminedCollectible
---@field cycle DataminedCollectibleData[]
---@field corruptedData boolean

---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
---@return VirtualPickup?
local function InitPickup(virtualRoom, entityType, variant, subtype, initSeed)
    local virtualPickup = PickupInitializer.CreateVirtualPickup()
    local success = PickupInitializer.InitVirtualPickup(virtualPickup, entityType, variant, subtype, initSeed, virtualRoom)
    if not success then
        return nil
    end
    return  virtualPickup
end

if DATAMINER_DEBUG_MODE then
    local old_init_pickup = InitPickup
    ---@param virtualRoom VirtualRoom
    ---@param entityType integer
    ---@param variant integer
    ---@param subtype integer
    ---@param initSeed integer
    InitPickup = function(virtualRoom, entityType, variant, subtype, initSeed)
        assert(entityType == EntityType.ENTITY_PICKUP, "Expected a pickup entity")
        local pickup = old_init_pickup(virtualRoom, entityType, variant, subtype, initSeed)
        return pickup
    end
end

--#region Collectible Data

---@param virtualPickup VirtualPickup
---@return DataminedCollectibleData
local function read_collectible_data(virtualPickup)
    local price = virtualPickup.Price
    local originalPrice = virtualPickup.m_OriginalPrice
    -- Assuming AutoUpdatePrice is always enabled, might need to update this if we wanna have ultra specific mod compatibility
    if price ~= 0 then
        price, originalPrice = PickupInitializer.GetShopItemPrice(virtualPickup.m_Room.m_Shop, virtualPickup.Variant, virtualPickup.SubType, virtualPickup.ShopItemId)
    end

    ---@type DataminedCollectibleData
    local collectible = {
        collectibleType = virtualPickup.SubType,
        price = price,
        originalPrice = originalPrice,
    }

    return collectible
end

---@param virtualPickup VirtualPickup
---@return DataminedCollectible
local function ReadDataminedCollectible(virtualPickup)
    local cycle = {}
    table.insert(cycle, read_collectible_data(virtualPickup))
    local corruptedData = (virtualPickup.m_Flags & EntityFlag.FLAG_GLITCH) ~= 0

    local originalSubtype = virtualPickup.SubType
    -- I'm not going through the whole Morph procedure, since modifiers are ignored and such
    for _, collectibleCycle in ipairs(virtualPickup.m_OptionsCycles) do
        virtualPickup.SubType = collectibleCycle
        table.insert(cycle, read_collectible_data(virtualPickup))
    end
    virtualPickup.SubType = originalSubtype

    ---@type DataminedCollectible
    local collectible = {
        cycle = cycle,
        corruptedData = corruptedData,
    }

    return collectible
end

if DATAMINER_DEBUG_MODE then
    local old_read_collectible_data = read_collectible_data
    ---@param virtualPickup VirtualPickup
    ---@return DataminedCollectibleData
    read_collectible_data = function(virtualPickup)
        assert(virtualPickup.m_Type == EntityType.ENTITY_PICKUP, "Expected a pickup entity")
        assert(virtualPickup.Variant == PickupVariant.PICKUP_COLLECTIBLE, "Expected a collectible variant")
        return old_read_collectible_data(virtualPickup)
    end

    local old_read_datamined_collectible = ReadDataminedCollectible
    ---@param virtualPickup VirtualPickup
    ---@return DataminedCollectible
    ReadDataminedCollectible = function(virtualPickup)
        assert(virtualPickup.m_Type == EntityType.ENTITY_PICKUP, "Expected a pickup entity")
        assert(virtualPickup.Variant == PickupVariant.PICKUP_COLLECTIBLE, "Expected a collectible variant")
        return old_read_datamined_collectible(virtualPickup)
    end
end

--#region Module

CommonDatamineStrategyUtils.InitPickup = InitPickup
CommonDatamineStrategyUtils.ReadDataminedCollectible = ReadDataminedCollectible

--#endregion

return CommonDatamineStrategyUtils