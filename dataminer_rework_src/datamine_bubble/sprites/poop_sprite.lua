---@class PoopSpriteUtils
local PoopSpriteUtils = {}

local POOP_ANM2_PATH = "gfx/dataminer_rework/dataminer_bubble/poop.anm2"

local function CreateSprite()
    local sprite = Sprite()
    sprite:Load(POOP_ANM2_PATH, true)
    sprite:Play(sprite:GetDefaultAnimation(), true)
    return sprite
end

--#region Module

PoopSpriteUtils.CreateSprite = CreateSprite

--#endregion

return PoopSpriteUtils