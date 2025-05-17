---@class CustomCallbacks
local CustomCallbacks = {}

---@enum CustomCallbacks.Callbacks
local Callbacks = {
    DATAMINER_POST_PICKUP_SELECTION = "DATAMINER_POST_PICKUP_SELECTION",
    DATAMINER_POST_PICKUP_INIT = "DATAMINER_POST_PICKUP_INIT",
}

---@param virtualPickup VirtualPickup
---@param variant integer
---@param subtype integer
---@param requestedVariant integer
---@param requestedSubtype integer
---@param seed integer
---@return PickupVariant | integer newVariant, integer newSubType
local function RunPostPickupSelection(virtualPickup, variant, subtype, requestedVariant, requestedSubtype, seed)
    local result = Isaac.RunCallback(Callbacks.DATAMINER_POST_PICKUP_SELECTION, virtualPickup, variant, subtype, requestedVariant, requestedSubtype, RNG(seed, 35))
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

CustomCallbacks.RunPostPickupSelection = RunPostPickupSelection
CustomCallbacks.RunPostPickupInit = RunPostPickupInit

--#endregion

return CustomCallbacks