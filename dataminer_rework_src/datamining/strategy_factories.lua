---@class DataminerStrategyFactory
local DataminerStrategyFactory = {}

---@class DataminerStrategy : SpawnStrategy
---@field PostRoomInit fun(self: DataminerStrategy, virtualRoom: VirtualRoom, roomDesc: VirtualRoomDescriptor, roomData: RoomConfigRoom) | nil
---@field GetBubbleData fun(self: DataminerStrategy): DataminerStrategy.BubbleData

---@class DataminerStrategy.BubbleData
---@field view DatamineView
---@field hostile boolean

---@alias DataminerStrategyFactory.Factory fun(): DataminerStrategy

---@type table<RoomType | integer, DataminerStrategyFactory.Factory>
local s_Strategies = {}

---@param roomType RoomType | integer
---@param strategyFactory DataminerStrategyFactory.Factory
local function AddStrategyFactory(roomType, strategyFactory)
    s_Strategies[roomType] = strategyFactory
end

---@param roomType RoomType | integer
---@return DataminerStrategyFactory.Factory?
local function GetStrategyFactory(roomType)
    return s_Strategies[roomType]
end

---Looks up the factory function and executes it,
---return nil if no factory function was registered
---@return DataminerStrategy?
local function GetStrategy(roomType)
    local strategyFactory = s_Strategies[roomType]
    if strategyFactory then
        return strategyFactory()
    end
end

--#region Module

DataminerStrategyFactory.AddStrategyFactory = AddStrategyFactory
DataminerStrategyFactory.GetStrategyFactory = GetStrategyFactory
DataminerStrategyFactory.GetStrategy = GetStrategy

--#endregion

return DataminerStrategyFactory