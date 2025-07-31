---@class BedroomDataminerStrategy
local BedroomDataminerStrategy = {}

--#region Dependencies

local BedroomView = require("datamine_bubble.datamine_views.bedroom_view")

--#endregion

---@class BedroomStrategy : DataminerStrategy
---@field m_IsBarren boolean

---@param dataminerStrategy BedroomStrategy
---@return DataminerStrategy.BubbleData
local function BedroomGetBubbleData(dataminerStrategy)
    local view = BedroomView.CreateView(dataminerStrategy.m_IsBarren)

    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

---@return BedroomStrategy
local function CreateIsaacsStrategy()
    ---@type BedroomStrategy
    local bedroomStrategy = {
        GetBubbleData = BedroomGetBubbleData,
        m_IsBarren = false,
    }

    return bedroomStrategy
end

---@return BedroomStrategy
local function CreateBarrenStrategy()
    ---@type BedroomStrategy
    local bedroomStrategy = {
        GetBubbleData = BedroomGetBubbleData,
        m_IsBarren = true,
    }

    return bedroomStrategy
end

--#region Module

BedroomDataminerStrategy.CreateIsaacsStrategy = CreateIsaacsStrategy
BedroomDataminerStrategy.CreateBarrenStrategy = CreateBarrenStrategy

--#endregion

return BedroomDataminerStrategy