---@class Lib.EntityPickup
local Lib_EntityPickup = {}

--#region Dependencies

local g_Seeds = Game():GetSeeds()

local Lib = {
    Table = require("dataminer_rework_src.lib.table")
}

--#endregion

local s_Chests = Lib.Table.CreateDictionary({
    PickupVariant.PICKUP_CHEST, PickupVariant.PICKUP_LOCKEDCHEST, PickupVariant.PICKUP_REDCHEST, PickupVariant.PICKUP_BOMBCHEST,
    PickupVariant.PICKUP_ETERNALCHEST, PickupVariant.PICKUP_SPIKEDCHEST, PickupVariant.PICKUP_MIMICCHEST, PickupVariant.PICKUP_MOMSCHEST,
    PickupVariant.PICKUP_OLDCHEST, PickupVariant.PICKUP_WOODENCHEST, PickupVariant.PICKUP_MEGACHEST, PickupVariant.PICKUP_HAUNTEDCHEST,
})

---@param variant PickupVariant | integer
---@return boolean isChest
local function IsChest(variant)
    return not not s_Chests[variant]
end

local s_UnrerollablePickups = Lib.Table.CreateDictionary({
    PickupVariant.PICKUP_BED, PickupVariant.PICKUP_TROPHY, PickupVariant.PICKUP_BIGCHEST,
    PickupVariant.PICKUP_THROWABLEBOMB, PickupVariant.PICKUP_MOMSCHEST,
})

---@param variant PickupVariant
---@param subtype integer
---@return boolean
local function CanReroll(variant, subtype)
    if s_UnrerollablePickups[variant] then
        return false
    end

    if variant == PickupVariant.PICKUP_COLLECTIBLE then
        if subtype == CollectibleType.COLLECTIBLE_DADS_NOTE then
            return false
        end

        if subtype == -1 and g_Seeds:HasSeedEffect(SeedEffect.SEED_G_FUEL) then
            return false
        end
    end

    if IsChest(variant) and subtype == 0 then
        return false
    end

    return true
end

--#region Module

Lib_EntityPickup.IsChest = IsChest
Lib_EntityPickup.CanReroll = CanReroll

--#endregion

return Lib_EntityPickup