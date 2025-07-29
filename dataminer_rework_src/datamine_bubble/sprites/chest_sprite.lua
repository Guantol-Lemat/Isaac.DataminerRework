---@class ChestSpriteUtils
local ChestSpriteUtils = {}

local CHEST_ANM2_PATH = "gfx/dataminer_rework/dataminer_bubble/chest.anm2"

local s_Frames = {
    [false] = 0,
    [true] = 1,
}

---@return Sprite
local function CreateSprite()
    local sprite = Sprite()
    sprite:Load(CHEST_ANM2_PATH, true)
    sprite:SetFrame(sprite:GetDefaultAnimation(), s_Frames[false])
    return sprite
end

---@param sprite Sprite
---@param isMegaChest boolean
local function InitSprite(sprite, isMegaChest)
    sprite:SetFrame(sprite:GetDefaultAnimation(), s_Frames[isMegaChest])
end

--#region Module

ChestSpriteUtils.CreateSprite = CreateSprite
ChestSpriteUtils.InitSprite = InitSprite

--#endregion

return ChestSpriteUtils