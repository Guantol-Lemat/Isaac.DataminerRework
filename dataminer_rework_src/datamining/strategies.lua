---@class DataminingEffects
local DataminingStrategies = {}

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
local function init_pickup(virtualRoom, entityType, variant, subtype, initSeed)
    local virtualPickup = PickupInitializer.CreateVirtualPickup()
    local success = PickupInitializer.InitVirtualPickup(virtualPickup, entityType, variant, subtype, initSeed, virtualRoom)
    if not success then
        return nil
    end
    return  virtualPickup
end

if DATAMINER_DEBUG_MODE then
    local old_init_pickup = init_pickup
    ---@param virtualRoom VirtualRoom
    ---@param entityType integer
    ---@param variant integer
    ---@param subtype integer
    ---@param initSeed integer
    init_pickup = function(virtualRoom, entityType, variant, subtype, initSeed)
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
local function read_datamined_collectible(virtualPickup)
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

    local old_read_datamined_collectible = read_datamined_collectible
    ---@param virtualPickup VirtualPickup
    ---@return DataminedCollectible
    read_datamined_collectible = function(virtualPickup)
        assert(virtualPickup.m_Type == EntityType.ENTITY_PICKUP, "Expected a pickup entity")
        assert(virtualPickup.Variant == PickupVariant.PICKUP_COLLECTIBLE, "Expected a collectible variant")
        return old_read_datamined_collectible(virtualPickup)
    end
end

---@param collectible DataminedCollectibleData
---@param name string
local function print_collectible_data(collectible, name)
    print(string.format("%s: %s, Price: %d", name, Lib.ItemConfig.GetCollectibleDisplayName(g_ItemConfig, collectible.collectibleType), collectible.price))
end

---@param collectibles DataminedCollectible[]
local function print_collectibles(collectibles)
    print("Collectibles:")
    for _, collectible in ipairs(collectibles) do
        print(string.format("Data: Num Cycles: %d, Corrupted Data: %s", #collectible.cycle, tostring(collectible.corruptedData)))
        for _, optionCycle in ipairs(collectible.cycle) do
            print_collectible_data(optionCycle, "Collectible")
        end
    end
end

--#endregion

--#region Treasure Datamining

---@class TreasureStrategy : DataminerStrategy
---@field collectibles DataminedCollectible[]

---@param dataminerStrategy TreasureStrategy
---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
local function TreasureSpawnEntity(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    if entityType ~= EntityType.ENTITY_PICKUP then
        return
    end

    local virtualPickup = init_pickup(virtualRoom, entityType, variant, subtype, initSeed)
    if not virtualPickup or virtualPickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        return
    end

    table.insert(dataminerStrategy.collectibles, read_datamined_collectible(virtualPickup))
end

---@param dataminerStrategy TreasureStrategy
local function PrintTreasureDatamine(dataminerStrategy)
    print_collectibles(dataminerStrategy.collectibles)
end

local function CreateTreasureStrategy()
    ---@type TreasureStrategy
    local treasureStrategy = {
        SpawnEntity = TreasureSpawnEntity,
        Print = PrintTreasureDatamine,
        collectibles = {},
    }

    return treasureStrategy
end

--#endregion

--#region Module

DataminingStrategies.CreateTreasureStrategy = CreateTreasureStrategy

--#endregion

return DataminingStrategies