---@class TreasureDatamineStrategy
local TreasureDatamineStrategy = {}

--#region Dependencies

local Common = require("datamining.strategies.common")
local NothingView = require("datamine_bubble.datamine_views.nothing_view")
local CollectibleView = require("datamine_bubble.datamine_views.collectible_view")

--#endregion

---@class TreasureStrategy : DataminerStrategy
---@field m_Collectibles DataminedCollectible[]

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

    local virtualPickup = Common.InitPickup(virtualRoom, entityType, variant, subtype, initSeed)
    if not virtualPickup or virtualPickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        return
    end

    table.insert(dataminerStrategy.m_Collectibles, Common.ReadDataminedCollectible(virtualPickup))
end

---@param dataminerStrategy TreasureStrategy
---@return DatamineView
local function get_treasure_view(dataminerStrategy)
    if #dataminerStrategy.m_Collectibles <= 0 then
        local view = NothingView.CreateView()
        return view
    end

    local view = CollectibleView.CreateView(dataminerStrategy.m_Collectibles)
    return view
end

---@param dataminerStrategy TreasureStrategy
---@return DataminerStrategy.BubbleData
local function TreasureGetBubbleData(dataminerStrategy)
    local view = get_treasure_view(dataminerStrategy)
    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

local function CreateTreasureStrategy()
    ---@type TreasureStrategy
    local treasureStrategy = {
        SpawnEntity = TreasureSpawnEntity,
        GetBubbleData = TreasureGetBubbleData,
        m_Collectibles = {},
    }

    return treasureStrategy
end

--#region Module

TreasureDatamineStrategy.CreateStrategy = CreateTreasureStrategy

--#endregion

return TreasureDatamineStrategy