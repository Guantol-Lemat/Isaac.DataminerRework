---@class ChallengeDatamineStrategy
local ChallengeDatamineStrategy = {}

--#region Dependencies

local Common = require("datamining.strategies.common")
local NothingView = require("datamine_bubble.datamine_views.nothing_view")
local ChestView = require("datamine_bubble.datamine_views.chest_view")
local CollectibleView = require("datamine_bubble.datamine_views.collectible_view")

local Lib = {
    EntityPickup = require("lib.entity_pickup")
}

--#endregion

---@class ChallengeStrategy : DataminerStrategy
---@field m_Collectibles DataminedCollectible[]
---@field m_Chests number

---@param dataminerStrategy ChallengeStrategy
---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
local function ChallengeSpawnEntity(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    if entityType ~= EntityType.ENTITY_PICKUP then
        return
    end

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

---@param dataminerStrategy ChallengeStrategy
---@return DatamineView
local function get_challenge_view(dataminerStrategy)
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

---@param dataminerStrategy ChallengeStrategy
---@return DataminerStrategy.BubbleData
local function ChallengeGetBubbleData(dataminerStrategy)
    local view = get_challenge_view(dataminerStrategy)
    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

---@return ChallengeStrategy
local function CreateChallengeStrategy()
    ---@type ChallengeStrategy
    local challengeStrategy = {
        SpawnEntity = ChallengeSpawnEntity,
        GetBubbleData = ChallengeGetBubbleData,
        m_Collectibles = {},
        m_Chests = 0,
    }

    return challengeStrategy
end

--#region Module

ChallengeDatamineStrategy.CreateStrategy = CreateChallengeStrategy

--#endregion

return ChallengeDatamineStrategy