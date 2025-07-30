---@class Dataminer
local Dataminer = {}

--#region Dependencies

local g_Level = Game():GetLevel()

local VirtualRoom = require("datamining.room.virtual_room")
local RoomLoader = require("datamining.room.room_loader")
local DataminingStrategies = require("datamining.strategies")

--#region

---@class DataminerStrategy : SpawnStrategy
---@field PostRoomInit fun(self: DataminerStrategy, virtualRoom: VirtualRoom, roomDesc: VirtualRoomDescriptor, roomData: RoomConfigRoom) | nil
---@field Print fun(self: DataminerStrategy)

local s_DataminingFactories = {
    [RoomType.ROOM_TREASURE] = DataminingStrategies.CreateTreasureStrategy,
    [RoomType.ROOM_SHOP] = DataminingStrategies.CreateTreasureStrategy,
}

---@param roomType RoomType
---@return DataminerStrategy?
local function build_strategy(roomType)
    local Factory = s_DataminingFactories[roomType]
    if not Factory then
        return nil
    end
    return Factory()
end

---@param roomDesc VirtualRoomDescriptor
---@param roomData RoomConfigRoom
---@param dataminerStrategy DataminerStrategy
local function datamine_room(roomDesc, roomData, dataminerStrategy)
    local virtualRoom = VirtualRoom.CreateVirtualRoom()
    VirtualRoom.InitRoom(virtualRoom, roomDesc, roomData, dataminerStrategy)

    if dataminerStrategy.PostRoomInit then
        dataminerStrategy:PostRoomInit(virtualRoom, roomDesc, roomData)
    end

    VirtualRoom.Update(virtualRoom, dataminerStrategy)
end

---@param room Room
---@param doorSlot DoorSlot
---@return DataminerStrategy?
local function datamine_room_from_door(room, doorSlot)
    local door = room:GetDoor(doorSlot)
    if not door then
        return
    end

    local virtualRoomDesc = RoomLoader.ResolveDoorTarget(door)
    local roomData = RoomLoader.InitRoomData(virtualRoomDesc)
    if not roomData then
        return
    end

    local strategy = build_strategy(virtualRoomDesc.Data.Type)
    if not strategy then
        return
    end

    datamine_room(virtualRoomDesc, roomData, strategy)
    return strategy
end

---@param datamine DataminerStrategy
local function resolve_datamine(datamine)
    -- TODO
end

if DATAMINER_DEBUG_MODE then
    local old_resolve_datamine = resolve_datamine
    ---@param datamine DataminerStrategy
    resolve_datamine = function(datamine)
        old_resolve_datamine(datamine)
        datamine:Print()
    end
end

local function trigger_datamine()
    local room = g_Level:GetCurrentRoom()

    for i = 0, DoorSlot.NUM_DOOR_SLOTS - 1, 1 do
        local datamine = datamine_room_from_door(room, i)
        if datamine then
            resolve_datamine(datamine)
        end
    end
end

--#region Module

Dataminer.datamine_room_from_door = datamine_room_from_door
Dataminer.datamine_room = datamine_room
Dataminer.build_strategy = build_strategy
Dataminer.trigger_datamine = trigger_datamine

--#endregion

return Dataminer