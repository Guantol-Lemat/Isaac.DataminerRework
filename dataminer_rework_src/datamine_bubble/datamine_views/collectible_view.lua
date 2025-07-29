---@class CollectibleDatamineView
local CollectibleDatamineView = {}

--#region Dependencies

local Log = require("log")

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local PedestalSpriteUtils = require("datamine_bubble.sprites.pedestal_sprite")
local CollectibleSpriteUtils = require("datamine_bubble.sprites.collectible_sprite")
local LayoutData = require("datamine_bubble.layout_data")

--#endregion

---@class CollectibleView
---@field m_Collectible DatamineViewComponent
---@field m_Pedestal DatamineViewComponent
---@field m_Frames integer
---@field m_CurrentCycle integer
---@field m_Model DataminedCollectible

---@class CollectibleDatamineViewComponent : DatamineView
---@field m_Collectibles CollectibleView[]

---@param collectibleView CollectibleView
---@param collectibleModel DataminedCollectibleData
local function init_collectible_sprite(collectibleView, collectibleModel)
    CollectibleSpriteUtils.InitSprite(collectibleView.m_Collectible.m_Sprite, collectibleModel.collectibleType)
    PedestalSpriteUtils.InitSprite(collectibleView.m_Pedestal.m_Sprite, collectibleModel.price, collectibleModel.originalPrice)
end

---@param collectibleView CollectibleView
local function cycle_collectible(collectibleView)
    local model = collectibleView.m_Model
    collectibleView.m_CurrentCycle = (collectibleView.m_CurrentCycle + 1) % #model.cycle
    local currentCycle = model.cycle[collectibleView.m_CurrentCycle + 1]
    init_collectible_sprite(collectibleView, currentCycle)
end

---@param view CollectibleDatamineViewComponent
local function UpdateView(view)
    for i = 1, #view.m_Collectibles, 1 do
        local collectibleView = view.m_Collectibles[i]
        collectibleView.m_Frames = collectibleView.m_Frames + 1
        local cycles = #collectibleView.m_Model.cycle
        if (cycles > 1 and not collectibleView.m_Model.corruptedData) and collectibleView.m_Frames % 30 == 0 then
            cycle_collectible(collectibleView)
        end
    end
end

---@param view CollectibleDatamineViewComponent
---@param frameData ViewFrameData
---@param position Vector
local function RenderView(view, frameData, position)
    for i = 1, #view.m_Collectibles, 1 do
        local collectibleView = view.m_Collectibles[i]
        CommonViewUtils.RenderViewComponent(collectibleView.m_Collectible, frameData, position)
        CommonViewUtils.RenderViewComponent(collectibleView.m_Pedestal, frameData, position)
    end
end

---@param model DataminedCollectible
---@param position Vector
---@return CollectibleView
local function create_collectible_view(model, position)
    ---@type CollectibleView
    local collectibleView = {
        m_Collectible = {
            m_Sprite = Sprite(),
            m_Position = position + LayoutData.GetCollectiblePositionOffset(),
        },
        m_Pedestal = {
            m_Sprite = PedestalSpriteUtils.CreateSprite(),
            m_Position = position,
        },
        m_Position = position,
        m_OriginalPosition = position,
        m_Frames = 0,
        m_CurrentCycle = 1,
        m_Model = model,
    }

    init_collectible_sprite(collectibleView, model.cycle[1])
    return collectibleView
end

local s_CollectiblesCountToLayout = {
    [1] = LayoutData.CollectibleLayout.COLLECTIBLE_1,
    [2] = LayoutData.CollectibleLayout.COLLECTIBLE_2,
    [3] = LayoutData.CollectibleLayout.COLLECTIBLE_3,
    [4] = LayoutData.CollectibleLayout.COLLECTIBLE_4,
}

---@return CollectibleDatamineViewComponent
---@param model DataminedCollectible[]
local function CreateView(model)
    ---@type CollectibleDatamineViewComponent
    local view = {
        m_Collectibles = {},
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    local collectibleCount = math.min(#model, 4)
    local layout = LayoutData.GetCollectibleLayoutData(s_CollectiblesCountToLayout[collectibleCount])

    if layout then
        for i = 1, collectibleCount, 1 do
            view.m_Collectibles[i] = create_collectible_view(model[i], layout[i])
        end
    else
        local plural = collectibleCount == 1 and "" or "s"
        Log.LogFull(Log.LogType.WARNING, "No collectible layout for %d collectible%s", collectibleCount, plural)
    end

    return view
end

--#region Module

CollectibleDatamineView.CreateView = CreateView

--#endregion

return CollectibleDatamineView