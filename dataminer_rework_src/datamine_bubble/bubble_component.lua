---@class DatamineBubble
local DatamineBubble = {}

---@class DatamineBubbleComponent
---@field m_BubbleSprite Sprite
---@field m_View DatamineView
---@field m_Position Vector

--#region Dependencies

local BubbleSpriteUtils = require("datamine_bubble.sprites.bubble_sprite")

--#endregion

---@param view DatamineView
---@return DatamineBubbleComponent
local function CreateBubble(view)
    ---@type DatamineBubbleComponent
    local bubble = {
        m_BubbleSprite = BubbleSpriteUtils.CreateSprite(),
        m_View = view,
        m_Position = Vector(0, 0)
    }

    return bubble
end

---@param bubble DatamineBubbleComponent
---@param position Vector
---@param direction Direction
---@param hostile boolean
local function InitBubble(bubble, position, direction, hostile)
    BubbleSpriteUtils.InitSprite(bubble.m_BubbleSprite, direction, hostile)
    bubble.m_Position = position
end

---@param bubble DatamineBubbleComponent
local function UpdateBubble(bubble)
    BubbleSpriteUtils.UpdateSprite(bubble.m_BubbleSprite)
    bubble.m_View:UpdateView()
end

---@param bubble DatamineBubbleComponent
local function RenderBubble(bubble)
    local renderPosition = Isaac.WorldToScreen(bubble.m_Position)

    local frameData = BubbleSpriteUtils.GetViewFrameData(bubble.m_BubbleSprite)
    bubble.m_BubbleSprite:Render(renderPosition)
    bubble.m_View:RenderView(frameData, renderPosition)
end

--#region Module

DatamineBubble.CreateBubble = CreateBubble
DatamineBubble.InitBubble = InitBubble
DatamineBubble.UpdateBubble = UpdateBubble
DatamineBubble.RenderBubble = RenderBubble

--#endregion

return DatamineBubble