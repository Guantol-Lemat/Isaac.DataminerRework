---@class CustomCallbacks
local CustomCallbacks = {}

---@enum CustomCallbacks.Callbacks
local Callbacks = {
    DATAMINER_PRE_ROOM_ENTITY_SPAWN = "DATAMINER_PRE_ROOM_ENTITY_SPAWN",
    DATAMINER_PRE_ENTITY_SPAWN = "DATAMINER_PRE_ENTITY_SPAWN",
    DATAMINER_POST_PICKUP_SELECTION = "DATAMINER_POST_PICKUP_SELECTION",
    DATAMINER_POST_PICKUP_INIT = "DATAMINER_POST_PICKUP_INIT",
}

---@param entityType integer
---@param variant integer
---@param subtype integer
---@param gridIdx integer
---@param seed integer
---@param virtualRoom VirtualRoom
---@return integer entityType, integer variant, integer subtype, boolean overridden
local function RunPreRoomEntitySpawn(entityType, variant, subtype, gridIdx, seed, virtualRoom)
    local overridden = false
    local callbackReturn = Isaac.RunCallback(Callbacks.DATAMINER_PRE_ROOM_ENTITY_SPAWN, entityType, variant, subtype, gridIdx, seed, virtualRoom)

    if type(callbackReturn) == "table" then
        if callbackReturn[1] then
            overridden = true
            entityType = callbackReturn[1]
        end

        if callbackReturn[2] then
            overridden = true
            variant = callbackReturn[2]
        end

        if callbackReturn[3] then
            overridden = true
            subtype = callbackReturn[3]
        end
    end

    return entityType, variant, subtype, overridden
end

---@param entityType any
---@param variant any
---@param subType any
---@param position any
---@param velocity any
---@param spawner any
---@param seed any
---@param virtualRoom any
---@return integer entityType, integer variant, integer subType, integer seed
local function RunPreEntitySpawn(entityType, variant, subType, position, velocity, spawner, seed, virtualRoom)
    local callbackReturn = Isaac.RunCallback(Callbacks.DATAMINER_PRE_ENTITY_SPAWN, entityType, variant, subType, position, velocity, spawner, seed, virtualRoom)

    if type(callbackReturn) == "table" then
        if callbackReturn[1] then
            entityType = callbackReturn[1]
        end

        if callbackReturn[2] then
            variant = callbackReturn[2]
        end

        if callbackReturn[3] then
            subType = callbackReturn[3]
        end

        if callbackReturn[4] then
            seed = callbackReturn[4]
        end
    end

    return entityType, variant, subType, seed
end

---@param virtualPickup VirtualPickup
---@param variant integer
---@param subtype integer
---@param requestedVariant integer
---@param requestedSubtype integer
---@param seed integer
---@return PickupVariant | integer newVariant, integer newSubType
local function RunPostPickupSelection(virtualPickup, variant, subtype, requestedVariant, requestedSubtype, seed)
    local result = Isaac.RunCallback(Callbacks.DATAMINER_POST_PICKUP_SELECTION, virtualPickup, variant, subtype, requestedVariant, requestedSubtype, RNG(seed, 35), virtualPickup.m_Room)
    if type(result) ~= "table" then
        return variant, subtype
    end

    if type(result[1]) == "number" then
        variant = result[1]
    end

    if type(result[2]) == "number" then
        subtype = result[2]
    end

    return variant, subtype
end

---@param virtualPickup VirtualPickup
local function RunPostPickupInit(virtualPickup)
    Isaac.RunCallback(Callbacks.DATAMINER_POST_PICKUP_INIT, virtualPickup)
end

--#region Module

CustomCallbacks.RunPreRoomEntitySpawn = RunPreRoomEntitySpawn
CustomCallbacks.RunPreEntitySpawn = RunPreEntitySpawn
CustomCallbacks.RunPostPickupSelection = RunPostPickupSelection
CustomCallbacks.RunPostPickupInit = RunPostPickupInit

--#endregion

return CustomCallbacks