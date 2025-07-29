---@class DiceDatamineView
local DiceDatamineView = {}

--#region Dependencies

local CommonViewUtils = require("datamine_bubble.datamine_views.common")
local DiceSpriteUtils = require("datamine_bubble.sprites.dice_sprite")

--#endregion

---@class DiceDatamineViewComponent : DatamineView, DatamineViewComponent

local function UpdateView(view)
end

local RenderView = CommonViewUtils.RenderViewComponent

---@param diceFloorSubtype DiceFloorSubtype
---@return DiceDatamineViewComponent
local function CreateView(diceFloorSubtype)
    ---@type DiceDatamineViewComponent
    local view = {
        m_Sprite = DiceSpriteUtils.CreateSprite(),
        m_Position = Vector(0, 0),
        UpdateView = UpdateView,
        RenderView = RenderView,
    }

    DiceSpriteUtils.InitSprite(view.m_Sprite, diceFloorSubtype)

    return view
end

--#region Module

DiceDatamineView.CreateView = CreateView

--#endregion

return DiceDatamineView