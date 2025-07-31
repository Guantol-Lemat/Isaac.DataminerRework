---@class Lib.Entity
local Lib_Entity = {}

--#region Dependencies

local Lib = {
    Table = require("lib.table")
}

--#endregion

local s_NonEnemyNPCs = Lib.Table.CreateDictionary({
    EntityType.ENTITY_FIREPLACE, EntityType.ENTITY_SHOPKEEPER,
    EntityType.ENTITY_MOVABLE_TNT, EntityType.ENTITY_GENERIC_PROP,
    EntityType.ENTITY_MINECART, EntityType.ENTITY_POOP,
})

---@param entityType EntityType | integer
---@param variant integer
---@return boolean
local function IsEnemy(entityType, variant)
    if entityType < 10 or entityType >= 1000 then
        return false
    end

    if s_NonEnemyNPCs[entityType] then
        return false
    end

    if entityType == EntityType.ENTITY_CULTIST and variant == 10 then
        return false
    end

    return true
end

--#region Module

Lib_Entity.IsEnemy = IsEnemy

--#endregion

return Lib_Entity