---@class BedroomDatamineView
local BedroomDatamineView = {}

--#region Dependencies

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local BedroomSpriteUtils = require("datamine_bubble.sprites.bedroom_sprite")

--#endregion

---@class BedroomDatamineViewComponent : DatamineView, DatamineViewComponent

local function UpdateView(view)
end

local RenderView = CommonViewUtils.RenderViewComponent

---@param isIsaacsBedroom boolean
---@return BedroomDatamineViewComponent
local function CreateView(isIsaacsBedroom)
    ---@type BedroomDatamineViewComponent
    local view = {
        m_Sprite = BedroomSpriteUtils.CreateSprite(),
        m_Position = Vector(0, 0),
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    BedroomSpriteUtils.InitSprite(view.m_Sprite, isIsaacsBedroom)

    return view
end

--#region Module

BedroomDatamineView.CreateView = CreateView

--#endregion

return BedroomDatamineView