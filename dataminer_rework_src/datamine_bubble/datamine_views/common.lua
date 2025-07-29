---@class CommonViewUtils
local CommonViewUtils = {}

---@class DatamineViewComponent
---@field m_Sprite Sprite
---@field m_Position Vector

---@param viewComponent DatamineViewComponent
---@param frameData ViewFrameData
---@param position Vector
local function RenderViewComponent(viewComponent, frameData, position)
    local sprite = viewComponent.m_Sprite
    local scale = frameData.scale
    local relativePosition = frameData.position + ((viewComponent.m_Position) * scale)

    sprite.Color = frameData.color
    sprite.Scale = scale

    --print("Sprite FilePath", sprite:GetFilename())
    --print("Sprite Frame", sprite:GetFrame())
    --print("Sprite Color", sprite.Color)
    --print("Sprite Animation:", sprite:GetAnimation())
    sprite:Render(position + relativePosition)
end

--#region Module

CommonViewUtils.RenderViewComponent = RenderViewComponent

--#endregion

return CommonViewUtils