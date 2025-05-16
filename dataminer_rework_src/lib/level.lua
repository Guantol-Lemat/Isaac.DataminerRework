---@class Lib.Level
local Lib_Level = {}

--#region Dependencies

local g_Game = Game()

--#endregion

---@param level Level
local function GetEffectiveStage(level)
    local curses = level:GetCurses()
    local stage = level:GetStage()

    if curses & LevelCurse.CURSE_OF_LABYRINTH ~= 0 then
        stage = stage + 1
    end

    return stage
end

---@param stage LevelStage
---@return LevelStage
local function ConvertGreedStageToNormal(stage)
    if stage < LevelStage.STAGE5_GREED then
        return stage * 2 - 1
    end

    if stage == LevelStage.STAGE5_GREED then
        return LevelStage.STAGE5
    end

    return LevelStage.STAGE_NULL
end

---@param level Level
---@return boolean
local function IsAltPath(level)
    local stageType = level:GetStageType()
    return stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B
end

---@param level Level
---@return boolean
local function IsBackwardsPath(level)
    local stage = level:GetStage()
    if not (LevelStage.STAGE1_1 <= stage and stage <= LevelStage.STAGE3_2) then
        return false
    end

    return g_Game:GetStateFlag(GameStateFlag.STATE_BACKWARDS_PATH)
end

---@param level Level
---@return boolean
local function IsCorpseEntrance(level)
    if g_Game:IsGreedMode() or IsBackwardsPath(level) then
        return false
    end

    local stage = level:GetStage()
    local curses = level:GetCurses()
    if curses & LevelCurse.CURSE_OF_LABYRINTH == 0 then
        stage = stage + 1
    end

    return stage == LevelStage.STAGE3_2 and g_Game:GetStateFlag(GameStateFlag.STATE_MAUSOLEUM_HEART_KILLED)
end

--#region Module

Lib_Level.GetEffectiveStage = GetEffectiveStage
Lib_Level.ConvertGreedStageToNormal = ConvertGreedStageToNormal
Lib_Level.IsAltPath = IsAltPath
Lib_Level.IsBackwardsPath = IsBackwardsPath
Lib_Level.IsCorpseEntrance = IsCorpseEntrance

--#endregion

return Lib_Level