---@class BossSpriteUtils
local BossSpriteUtils = {}

---@class BossSpriteData
---@field anm2Path string
---@field frame integer

local DEFAULT_BOSS = 0

---@type table<integer, BossSpriteData>
local s_BossSpriteData = {}

---@param bossType BossType
---@return BossSpriteData
local function get_sprite_data(bossType)
    local spriteData = s_BossSpriteData[bossType]
    if not spriteData then
        spriteData = s_BossSpriteData[DEFAULT_BOSS]
    end

    return spriteData
end

---@param sprite Sprite
---@param bossType BossType
local function InitSprite(sprite, bossType)
    local spriteData = get_sprite_data(bossType)

    if sprite:GetFilename() ~= spriteData.anm2Path then
        sprite:Load(spriteData.anm2Path, true)
    end

    sprite:SetFrame(sprite:GetDefaultAnimation(), spriteData.frame)
end

---@param bossType BossType
---@param anm2Path string
---@param frame integer
local function AddBossSpriteData(bossType, anm2Path, frame)
    s_BossSpriteData[bossType] = {
        anm2Path = anm2Path,
        frame = frame,
    }
end

--#region Module

BossSpriteUtils.InitSprite = InitSprite
BossSpriteUtils.AddBossSpriteData = AddBossSpriteData

--#endregion

return BossSpriteUtils