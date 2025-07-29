---@class NothingDatamineView
local NothingDatamineView = {}

--#region Dependencies

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local PoopSpriteUtils = require("datamine_bubble.sprites.poop_sprite")

--#endregion

---@class NothingDatamineViewComponent : DatamineView, DatamineViewComponent

local function UpdateView(view)
end

local RenderView = CommonViewUtils.RenderViewComponent

---@return NothingDatamineViewComponent
local function CreateView()
    ---@type NothingDatamineViewComponent
    local view = {
        m_Sprite = PoopSpriteUtils.CreateSprite(),
        m_Position = Vector(0, 0),
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    return view
end

--#region Module

NothingDatamineView.CreateView = CreateView

--#endregion

return NothingDatamineView