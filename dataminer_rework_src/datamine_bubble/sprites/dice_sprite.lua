---@class DiceSpriteUtils
local DiceSpriteUtils = {}

--#region Dependencies

local Enums = require("enums")
local DiceFloorSubtype = Enums.eDiceFloorSubtype

--#endregion

local DICE_ANM2_PATH = "gfx/dataminer_rework/dataminer_bubble/dice.anm2"

local s_Frames = {
    [DiceFloorSubtype.DICE_1] = 0,
    [DiceFloorSubtype.DICE_2] = 1,
    [DiceFloorSubtype.DICE_3] = 2,
    [DiceFloorSubtype.DICE_4] = 3,
    [DiceFloorSubtype.DICE_5] = 4,
    [DiceFloorSubtype.DICE_6] = 5,
}

local DEFAULT_DICE_FLOOR = DiceFloorSubtype.DICE_6

---@return Sprite
local function CreateSprite()
    local sprite = Sprite()
    sprite:Load(DICE_ANM2_PATH, true)
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:SetFrame(s_Frames[DEFAULT_DICE_FLOOR])
    return sprite
end

---@param sprite Sprite
---@param diceFloorSubtype Enums.eDiceFloorSubtype
local function InitSprite(sprite, diceFloorSubtype)
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:SetFrame(s_Frames[diceFloorSubtype] or s_Frames[DEFAULT_DICE_FLOOR])
end

--#region Module

DiceSpriteUtils.CreateSprite = CreateSprite
DiceSpriteUtils.InitSprite = InitSprite

--#endregion

return DiceSpriteUtils