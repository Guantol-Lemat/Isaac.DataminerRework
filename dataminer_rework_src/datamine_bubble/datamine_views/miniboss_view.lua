---@class MinibossDatamineView
local MinibossDatamineView = {}

--#region Dependencies

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local MinibossSpriteUtils = require("datamine_bubble.sprites.miniboss_sprite")

--#endregion

---@class MinibossDatamineViewComponent : DatamineView, DatamineViewComponent

---@param view MinibossDatamineViewComponent
local function UpdateView(view)
end

local RenderView = CommonViewUtils.RenderViewComponent

---@return MinibossDatamineViewComponent
---@param miniboss integer
local function CreateView(miniboss)
    ---@type MinibossDatamineViewComponent
    local view = {
        m_Sprite = Sprite(),
        m_Position = Vector(0, 0),
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    MinibossSpriteUtils.InitSprite(view.m_Sprite, miniboss)

    return view
end

--#region Module

MinibossDatamineView.CreateView = CreateView

--#endregion

return MinibossDatamineView