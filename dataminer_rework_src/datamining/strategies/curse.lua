---@class ChallengeDatamineStrategy
local ChallengeDatamineStrategy = {}

--#region Dependencies

local Common = require("datamining.strategies.common")
local NothingView = require("datamine_bubble.datamine_views.nothing_view")
local ChestView = require("datamine_bubble.datamine_views.chest_view")
local CollectibleView = require("datamine_bubble.datamine_views.collectible_view")

local Lib = {
    Entity = require("lib.entity"),
    EntityPickup = require("lib.entity_pickup"),
}

--#endregion

---@class CurseStrategy : DataminerStrategy
---@field m_Collectibles DataminedCollectible[]
---@field m_Chests number
---@field m_Hostile boolean

---@param dataminerStrategy CurseStrategy
---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
local function init_pickup(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    local virtualPickup = Common.InitPickup(virtualRoom, entityType, variant, subtype, initSeed)
    if not virtualPickup then
        return
    end

    if virtualPickup.Variant == PickupVariant.PICKUP_COLLECTIBLE then
        table.insert(dataminerStrategy.m_Collectibles, Common.ReadDataminedCollectible(virtualPickup))
    elseif Lib.EntityPickup.IsChest(virtualPickup.Variant) then
        dataminerStrategy.m_Chests = dataminerStrategy.m_Chests + 1
    end
end

---@param dataminerStrategy CurseStrategy
---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
local function CurseSpawnEntity(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    if entityType == EntityType.ENTITY_PICKUP then
        init_pickup(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    elseif Lib.Entity.IsEnemy(entityType, variant) then
        dataminerStrategy.m_Hostile = true
    end
end

---@param dataminerStrategy CurseStrategy
---@return DatamineView
local function get_curse_view(dataminerStrategy)
    if #dataminerStrategy.m_Collectibles > 0 then
        local view = CollectibleView.CreateView(dataminerStrategy.m_Collectibles)
        return view
    end

    if dataminerStrategy.m_Chests > 0 then
        local chests = {}
        for i = 1, dataminerStrategy.m_Chests, 1 do
            local isMegaChest = false -- deliberately ignore type
            chests[i] = isMegaChest
        end

        local view = ChestView.CreateView(chests)
        return view
    end

    local view = NothingView.CreateView()
    return view
end

---@param dataminerStrategy CurseStrategy
---@return DataminerStrategy.BubbleData
local function CurseGetBubbleData(dataminerStrategy)
    local view = get_curse_view(dataminerStrategy)
    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = dataminerStrategy.m_Hostile,
    }
end

---@return CurseStrategy
local function CreateCurseStrategy()
    ---@type CurseStrategy
    local challengeStrategy = {
        SpawnEntity = CurseSpawnEntity,
        GetBubbleData = CurseGetBubbleData,
        m_Collectibles = {},
        m_Chests = 0,
        m_Hostile = false,
    }

    return challengeStrategy
end

--#region Module

ChallengeDatamineStrategy.CreateStrategy = CreateCurseStrategy

--#endregion

return ChallengeDatamineStrategy