---@class MinibossDataminerStrategy
local MinibossDataminerStrategy = {}

--#region Dependencies

local MinibossView = require("datamine_bubble.datamine_views.miniboss_view")

--#endregion

---@class MinibossStrategy : DataminerStrategy
---@field m_Miniboss integer

---@param dataminerStrategy MinibossStrategy
---@param virtualRoom VirtualRoom
---@param virtualRoomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
local function MinibossPostRoomInit(dataminerStrategy, virtualRoom, virtualRoomDesc, roomData)
    dataminerStrategy.m_Miniboss = roomData.Subtype
end

---@param dataminerStrategy MinibossStrategy
---@return DatamineView
local function get_miniboss_view(dataminerStrategy)
    local view = MinibossView.CreateView(dataminerStrategy.m_Miniboss)
    return view
end

---@param dataminerStrategy MinibossStrategy
---@return DataminerStrategy.BubbleData
local function MinibossGetBubbleData(dataminerStrategy)
    local view = get_miniboss_view(dataminerStrategy)
    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

---@return MinibossStrategy
local function CreateMinibossStrategy()
    ---@type MinibossStrategy
    local bossStrategy = {
        PostRoomInit = MinibossPostRoomInit,
        GetBubbleData = MinibossGetBubbleData,
        m_Miniboss = 0,
    }

    return bossStrategy
end

--#region Module

MinibossDataminerStrategy.CreateStrategy = CreateMinibossStrategy

--#endregion

return MinibossDataminerStrategy