---@class MinibossSpriteUtils
local MinibossSpriteUtils = {}

---@class MinibossSpriteData
---@field anm2Path string
---@field frame integer

local DEFAULT_MINIBOSS = RoomSubType.MINIBOSS_GREED

---@type table<integer, MinibossSpriteData>
local s_MinibossSpriteData = {}

---@param miniboss integer
---@return MinibossSpriteData
local function get_sprite_data(miniboss)
    local spriteData = s_MinibossSpriteData[miniboss]
    if not spriteData then
        spriteData = s_MinibossSpriteData[DEFAULT_MINIBOSS]
    end

    return spriteData
end

---@param sprite Sprite
---@param miniboss integer
local function InitSprite(sprite, miniboss)
    local spriteData = get_sprite_data(miniboss)

    if sprite:GetFilename() ~= spriteData.anm2Path then
        sprite:Load(spriteData.anm2Path, true)
    end

    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:SetFrame(spriteData.frame)
end

---@param miniboss integer
---@param anm2Path string
---@param frame integer
local function AddMinibossSpriteData(miniboss, anm2Path, frame)
    s_MinibossSpriteData[miniboss] = {
        anm2Path = anm2Path,
        frame = frame,
    }
end

--#region Module

MinibossSpriteUtils.InitSprite = InitSprite
MinibossSpriteUtils.AddMinibossSpriteData = AddMinibossSpriteData

--#endregion

return MinibossSpriteUtils