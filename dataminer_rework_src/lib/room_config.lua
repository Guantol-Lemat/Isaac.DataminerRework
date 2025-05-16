---@class Lib.RoomConfig
local Lib_RoomConfig = {}

---@param roomConfig RoomConfig
---@param seed integer
---@param reduceWeight boolean
---@param optionalStage StbType
---@param defaultStage StbType
---@param roomType RoomType
---@param shape RoomShape
---@param minVariant integer
---@param maxVariant integer
---@param minDifficulty integer
---@param maxDifficulty integer
---@param requiredDoors integer
---@param subType integer
---@return RoomConfigRoom?
local function GetRandomRoomFromOptionalStage(roomConfig, seed, reduceWeight, optionalStage, defaultStage, roomType, shape, minVariant, maxVariant, minDifficulty, maxDifficulty, requiredDoors, subType)
    local roomData = roomConfig.GetRandomRoom(seed, reduceWeight, optionalStage, roomType, shape, 0, -1, minDifficulty, maxDifficulty, requiredDoors, subType, -1)
    if not roomData then
        roomData = roomConfig.GetRandomRoom(seed, reduceWeight, defaultStage, roomType, shape, 0, -1, minDifficulty, maxDifficulty, requiredDoors, subType, -1)
    end
end

--#region Module

Lib_RoomConfig.GetRandomRoomFromOptionalStage = GetRandomRoomFromOptionalStage

--#endregion

return Lib_RoomConfig