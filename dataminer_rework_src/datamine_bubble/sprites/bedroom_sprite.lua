---@class BedroomSpriteUtils
local BedroomSpriteUtils = {}

local BEDROOM_ANM2_PATH = "gfx/dataminer_rework/dataminer_bubble/bedroom.anm2"

local s_Frames = {
    [false] = 0,
    [true] = 1,
}

---@return Sprite
local function CreateSprite()
    local sprite = Sprite()
    sprite:Load(BEDROOM_ANM2_PATH, true)
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:SetFrame(s_Frames[false])
    return sprite
end

---@param sprite Sprite
---@param isIsaacsBedroom boolean
local function InitSprite(sprite, isIsaacsBedroom)
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:SetFrame(sprite:GetDefaultAnimation(), s_Frames[isIsaacsBedroom])
end

--#region Module

BedroomSpriteUtils.CreateSprite = CreateSprite
BedroomSpriteUtils.InitSprite = InitSprite

--#endregion

return BedroomSpriteUtils