---@class ChestDatamineStrategy
local ChestDatamineStrategy = {}

--#region Dependencies

local Common = require("datamining.strategies.common")
local NothingView = require("datamine_bubble.datamine_views.nothing_view")
local ChestView = require("datamine_bubble.datamine_views.chest_view")
local CollectibleView = require("datamine_bubble.datamine_views.collectible_view")

local Lib = {
    EntityPickup = require("lib.entity_pickup")
}

--#endregion

---@class ChestStrategy : DataminerStrategy
---@field m_Chests boolean[]

---@param dataminerStrategy ChestStrategy
---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
local function ChestSpawnEntity(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    if entityType ~= EntityType.ENTITY_PICKUP then
        return
    end

    local virtualPickup = Common.InitPickup(virtualRoom, entityType, variant, subtype, initSeed)
    if not virtualPickup then
        return
    end

    if Lib.EntityPickup.IsChest(virtualPickup.Variant) then
        local isMegaChest = virtualPickup.Variant == PickupVariant.PICKUP_MEGACHEST
        table.insert(dataminerStrategy.m_Chests, isMegaChest)
    end
end

---@param dataminerStrategy ChestStrategy
---@return DatamineView
local function get_chest_view(dataminerStrategy)
    if #dataminerStrategy.m_Chests > 0 then
        local view = ChestView.CreateView(dataminerStrategy.m_Chests)
        return view
    end

    local view = NothingView.CreateView()
    return view
end

---@param dataminerStrategy ChestStrategy
---@return DataminerStrategy.BubbleData
local function ChestGetBubbleData(dataminerStrategy)
    local view = get_chest_view(dataminerStrategy)
    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

---@return ChestStrategy
local function CreateChestStrategy()
    ---@type ChestStrategy
    local challengeStrategy = {
        SpawnEntity = ChestSpawnEntity,
        GetBubbleData = ChestGetBubbleData,
        m_Chests = {},
    }

    return challengeStrategy
end

--#region Module

ChestDatamineStrategy.CreateStrategy = CreateChestStrategy

--#endregion

return ChestDatamineStrategy