---@class CollectibleSpriteUtils
local CollectibleSpriteUtils = {}

---@class CollectibleSpriteData
---@field anm2Path string
---@field frame integer

local GLITCHED_ITEM_ID = -1

---@type table<CollectibleType, CollectibleSpriteData>
local s_CollectibleSpriteData = {}

---@param collectibleType CollectibleType | integer
---@return CollectibleSpriteData
local function get_sprite_data(collectibleType)
    if collectibleType < 0 then
        return s_CollectibleSpriteData[GLITCHED_ITEM_ID]
    end

    local spriteData = s_CollectibleSpriteData[collectibleType]
    if not spriteData then
        spriteData = s_CollectibleSpriteData[CollectibleType.COLLECTIBLE_NULL]
    end

    return spriteData
end

---@param sprite Sprite
---@param collectibleType CollectibleType
local function InitSprite(sprite, collectibleType)
    local spriteData = get_sprite_data(collectibleType)

    if sprite:GetFilename() ~= spriteData.anm2Path then
        sprite:Load(spriteData.anm2Path, true)
    end

    sprite:SetFrame(sprite:GetDefaultAnimation(), spriteData.frame)
end

---@param collectibleType CollectibleType
---@param anm2Path string
---@param frame integer
local function AddCollectibleSpriteData(collectibleType, anm2Path, frame)
    s_CollectibleSpriteData[collectibleType] = {
        anm2Path = anm2Path,
        frame = frame,
    }
end

--#region Module

CollectibleSpriteUtils.InitSprite = InitSprite
CollectibleSpriteUtils.AddCollectibleSpriteData = AddCollectibleSpriteData

--#endregion

return CollectibleSpriteUtils