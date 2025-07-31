---@class BossDataminerStrategy
local BossDataminerStrategy = {}

--#region Dependencies

local BossView = require("datamine_bubble.datamine_views.boss_view")

--#endregion

---@class BossStrategy : DataminerStrategy
---@field m_Bosses BossType[]

---@param dataminerStrategy BossStrategy
---@param virtualRoom VirtualRoom
---@param virtualRoomDesc VirtualRoomDescriptor
---@param roomConfig RoomConfigRoom
local function BossPostRoomInit(dataminerStrategy, virtualRoom, virtualRoomDesc, roomConfig)
    dataminerStrategy.m_Bosses = {virtualRoom.m_BossID, virtualRoom.m_SecondBossID}
end

---@param dataminerStrategy BossStrategy
---@return DatamineView
local function get_boss_view(dataminerStrategy)
    local view = BossView.CreateView(dataminerStrategy.m_Bosses)
    return view
end

---@param dataminerStrategy BossStrategy
---@return DataminerStrategy.BubbleData
local function BossGetBubbleData(dataminerStrategy)
    local view = get_boss_view(dataminerStrategy)
    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

---@return BossStrategy
local function CreateBossStrategy()
    ---@type BossStrategy
    local bossStrategy = {
        PostRoomInit = BossPostRoomInit,
        GetBubbleData = BossGetBubbleData,
        m_Bosses = {},
    }

    return bossStrategy
end

--#region Module

BossDataminerStrategy.CreateStrategy = CreateBossStrategy

--#endregion

return BossDataminerStrategy