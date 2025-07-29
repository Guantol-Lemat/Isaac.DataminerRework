---@class BossDatamineView
local BossDatamineView = {}

--#region Dependencies

local Log = require("log")

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local BossSpriteUtils = require("datamine_bubble.sprites.boss_sprite")
local LayoutData = require("datamine_bubble.layout_data")

--#endregion

---@class BossDatamineViewComponent : DatamineView
---@field m_Bosses DatamineViewComponent[]

---@param view BossDatamineViewComponent
local function UpdateView(view)
end

---@param view BossDatamineViewComponent
---@param frameData ViewFrameData
---@param position Vector
local function RenderView(view, frameData, position)
    for i = #view.m_Bosses, 1, -1 do
        local bossView = view.m_Bosses[i]
        CommonViewUtils.RenderViewComponent(bossView, frameData, position)
    end
end

---@param boss BossType
---@param position Vector
---@return DatamineViewComponent
local function create_boss_view(boss, position)
    ---@type DatamineViewComponent
    local bossView = {
        m_Sprite = Sprite(),
        m_Position = position,
    }

    BossSpriteUtils.InitSprite(bossView.m_Sprite, boss)
    return bossView
end

local s_BossCountToLayout = {
    [1] = LayoutData.BossLayout.BOSS_1,
    [2] = LayoutData.BossLayout.BOSS_2,
}

---@return BossDatamineViewComponent
---@param bosses BossType[]
local function CreateView(bosses)
    ---@type BossDatamineViewComponent
    local view = {
        m_Bosses = {},
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    local bossCount = math.min(#bosses, 2)
    local layout = LayoutData.GetBossLayoutData(s_BossCountToLayout[bossCount])

    if layout then
        for i = 1, bossCount, 1 do
            view.m_Bosses[i] = create_boss_view(bosses[i], layout[i])
        end
    else
        local plural = bossCount == 1 and "" or "es"
        Log.LogFull(Log.LogType.WARNING, "No boss layout for %d boss%s", bossCount, plural)
    end

    return view
end

--#region Module

BossDatamineView.CreateView = CreateView

--#endregion

return BossDatamineView