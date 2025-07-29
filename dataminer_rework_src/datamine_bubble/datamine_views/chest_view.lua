---@class ChestDatamineView
local ChestDatamineView = {}

--#region Dependencies

local Log = require("log")

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local ChestSpriteUtils = require("datamine_bubble.sprites.chest_sprite")
local LayoutData = require("datamine_bubble.layout_data")

--#endregion

---@class ChestDatamineViewComponent : DatamineView
---@field m_Chests DatamineViewComponent[]

---@param view ChestDatamineViewComponent
local function UpdateView(view)
end

---@param view ChestDatamineViewComponent
---@param frameData ViewFrameData
---@param position Vector
local function RenderView(view, frameData, position)
    for i = 1, #view.m_Chests, 1 do
        local chestView = view.m_Chests[i]
        CommonViewUtils.RenderViewComponent(chestView, frameData, position)
    end
end

---@param position Vector
---@return DatamineViewComponent
local function create_chest_view(isMega, position)
    ---@type DatamineViewComponent
    local chestView = {
        m_Sprite = ChestSpriteUtils.CreateSprite(),
        m_Position = position,
    }

    ChestSpriteUtils.InitSprite(chestView.m_Sprite, isMega)
    return chestView
end

local s_ChestCountToLayout = {
    [1] = LayoutData.ChestLayout.CHEST_1,
    [2] = LayoutData.ChestLayout.CHEST_2,
    [3] = LayoutData.ChestLayout.CHEST_3,
    [4] = LayoutData.ChestLayout.CHEST_4,
}

---@return ChestDatamineViewComponent
---@param chests boolean[]
local function CreateView(chests)
    ---@type ChestDatamineViewComponent
    local view = {
        m_Chests = {},
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    local chestCount = math.min(#chests, 4)
    local layout = LayoutData.GetChestLayoutData(s_ChestCountToLayout[chestCount])

    if layout then
        for i = 1, chestCount, 1 do
            view.m_Chests[i] = create_chest_view(chests[i], layout[i])
        end
    else
        local plural = chestCount == 1 and "" or "s"
        Log.LogFull(Log.LogType.WARNING, "No chest layout for %d chest%s", chestCount, plural)
    end

    return view
end

--#region Module

ChestDatamineView.CreateView = CreateView

--#endregion

return ChestDatamineView