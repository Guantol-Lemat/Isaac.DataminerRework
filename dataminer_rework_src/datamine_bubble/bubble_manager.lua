---@class BubbleManager
local BubbleManager = {}

---@class BubbleManagerComponent
---@field m_Bubbles DatamineBubbleComponent[]

--#region Dependencies

local DatamineBubbleComponent = require("datamine_bubble.bubble_component")

--#endregion

---@return BubbleManagerComponent
local function CreateBubbleManager()
    ---@type BubbleManagerComponent
    local manager = {
        m_Bubbles = {}
    }

    return manager
end

---@param bubbleManager BubbleManagerComponent
---@param bubble DatamineBubbleComponent
local function AddBubble(bubbleManager, bubble)
    table.insert(bubbleManager.m_Bubbles, bubble)
end

---@param bubbleManager BubbleManagerComponent
local function Reset(bubbleManager)
    bubbleManager.m_Bubbles = {}
end

---@param bubbleManager BubbleManagerComponent
local function Update(bubbleManager)
    for i = 1, #bubbleManager.m_Bubbles, 1 do
        DatamineBubbleComponent.UpdateBubble(bubbleManager.m_Bubbles[i])
    end
end

---@param bubbleManager BubbleManagerComponent
local function Render(bubbleManager)
    for i = 1, #bubbleManager.m_Bubbles, 1 do
        DatamineBubbleComponent.RenderBubble(bubbleManager.m_Bubbles[i])
    end
end

--#region Module

BubbleManager.CreateBubbleManager = CreateBubbleManager
BubbleManager.AddBubble = AddBubble
BubbleManager.Reset = Reset
BubbleManager.Update = Update
BubbleManager.Render = Render

--#endregion

return BubbleManager