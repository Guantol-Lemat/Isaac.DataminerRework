---@class DiceDataminerStrategy
local DiceDataminerStrategy = {}

--#region Dependencies

local Enums = require("enums")
local DiceView = require("datamine_bubble.datamine_views.dice_view")

--#endregion

---@class DiceStrategy : DataminerStrategy
---@field m_DiceFloor integer

---@param dataminerStrategy DiceStrategy
---@param virtualRoom VirtualRoom
---@param entityType integer
---@param variant integer
---@param subtype integer
---@param initSeed integer
local function DiceSpawnEntity(dataminerStrategy, virtualRoom, entityType, variant, subtype, initSeed)
    if entityType ~= EntityType.ENTITY_EFFECT and variant ~= EffectVariant.DICE_FLOOR then
        return
    end

    dataminerStrategy.m_DiceFloor = subtype
end

---@param dataminerStrategy DiceStrategy
---@return DataminerStrategy.BubbleData
local function DiceGetBubbleData(dataminerStrategy)
    local view = DiceView.CreateView(dataminerStrategy.m_DiceFloor)

    ---@type DataminerStrategy.BubbleData
    return {
        view = view,
        hostile = false,
    }
end

---@return DiceStrategy
local function CreateDiceStrategy()
    ---@type DiceStrategy
    local bedroomStrategy = {
        SpawnEntity = DiceSpawnEntity,
        GetBubbleData = DiceGetBubbleData,
        m_DiceFloor = Enums.eDiceFloorSubtype.DICE_6,
    }

    return bedroomStrategy
end

--#region Module

DiceDataminerStrategy.CreateStrategy = CreateDiceStrategy

--#endregion

return DiceDataminerStrategy