---@class Lib.EntityPickup
local Lib_EntityPickup = {}

local Lib = {
    Table = require("dataminer_rework_src.lib.table")
}

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

--#region Module

Lib_EntityPickup.IsChest = IsChest

--#endregion

return Lib_EntityPickup