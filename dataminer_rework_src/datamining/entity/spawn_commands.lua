---@class SpawnCommandsUtil
local SpawnCommandsUtil = {}

---@class SpawnCommands
---@field entities EntitySpawnCommand[]
---@field gridEntities GridEntitySpawnCommand[]
---@field outputs OutputSpawnCommand[]
---@field rails RailSpawnCommand[]

---@class EntitySpawnCommand
---@field type EntityType | integer
---@field variant integer
---@field subtype integer
---@field seed integer
---@field position Vector
---@field velocity Vector
---@field spawner Entity?

---@class GridEntitySpawnCommand
---@field gridIdx integer
---@field type GridEntityType | integer
---@field variant integer
---@field seed integer
---@field varData integer

---@class OutputSpawnCommand
---@field variant integer
---@field position Vector

---@class RailSpawnCommand
---@field gridIdx integer
---@field variant StbRailVariant

---@param spawnCommands SpawnCommands
local function Init(spawnCommands)
    spawnCommands.entities = {}
    spawnCommands.gridEntities = {}
    spawnCommands.outputs = {}
    spawnCommands.rails = {}
end

---@return SpawnCommands
local function Create()
    local spawnCommands = {}
    Init(spawnCommands)
    return spawnCommands
end

---@param spawnCommands SpawnCommands
---@param type EntityType | integer
---@param variant integer
---@param subtype integer
---@param seed integer
---@param position Vector
---@param velocity Vector
---@param spawner Entity?
local function SpawnEntity(spawnCommands, type, variant, subtype, seed, position, velocity, spawner)
    table.insert(spawnCommands.entities, {type = type, variant = variant, subtype = subtype, seed = seed, position = position, velocity = velocity, spawner = spawner})
end

---@param spawnCommands SpawnCommands
---@param gridIdx integer
---@param type GridEntityType | integer
---@param variant integer
---@param seed integer
---@param varData integer
local function SpawnGridEntity(spawnCommands, gridIdx, type, variant, seed, varData)
    table.insert(spawnCommands.gridEntities, {gridIdx = gridIdx, type = type, variant = variant, seed = seed, varData = varData})
end

---@param spawnCommands SpawnCommands
---@param variant integer
---@param position Vector
local function AddOutput(spawnCommands, variant, position)
    table.insert(spawnCommands.outputs, {variant = variant, position = position})
end

---@param spawnCommands SpawnCommands
---@param gridIdx integer
---@param variant StbRailVariant
local function SetRail(spawnCommands, gridIdx, variant)
    table.insert(spawnCommands.rails, {gridIdx = gridIdx, variant = variant})
end

---@param spawnCommands SpawnCommands
---@return EntitySpawnCommand[]
local function GetEntitiesSpawnCommands(spawnCommands)
    return spawnCommands.entities
end

---@param spawnCommands SpawnCommands
---@return GridEntitySpawnCommand[]
local function GetGridEntitiesSpawnCommands(spawnCommands)
    return spawnCommands.gridEntities
end

--#region Module

SpawnCommandsUtil.Create = Create
SpawnCommandsUtil.Init = Init
SpawnCommandsUtil.SpawnEntity = SpawnEntity
SpawnCommandsUtil.SpawnGridEntity = SpawnGridEntity
SpawnCommandsUtil.AddOutput = AddOutput
SpawnCommandsUtil.SetRail = SetRail
SpawnCommandsUtil.GetEntitiesSpawnCommands = GetEntitiesSpawnCommands
SpawnCommandsUtil.GetGridEntitiesSpawnCommands = GetGridEntitiesSpawnCommands

--#endregion

return SpawnCommandsUtil