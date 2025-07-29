---@class BubbleSpriteUtils
local BubbleSpriteUtils = {}

--#region Dependencies

local Log = require("log")

--#endregion

--#region Static Data

local BUBBLE_ANM2_PATH = "gfx/dataminer_rework/dataminer_bubble.anm2"

local APPEAR_ANIMATION = "Appear"
local IDLE_ANIMATION = "Idle"

---@type table<Direction, integer>
local SourceDirectionLayers = {
    [Direction.LEFT] = 1,
    [Direction.RIGHT] = 2,
    [Direction.UP] = 3,
    [Direction.DOWN] = 4,
}

local VIEW_NULL_LAYER_NAME = "View"

--#endregion

---@return Sprite
local function CreateSprite()
    local sprite = Sprite()
    sprite:Load(BUBBLE_ANM2_PATH, true)
    sprite:Play(sprite:GetDefaultAnimation(), true)
    for i = Direction.LEFT, Direction.DOWN, 1 do
        local layer = SourceDirectionLayers[i]
        sprite:GetLayer(layer):SetVisible(false)
    end
    return sprite
end

---@param sprite Sprite
---@param direction Direction
---@param hostile boolean
local function InitSprite(sprite, direction, hostile)
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:Play(APPEAR_ANIMATION, true)
    local layer = SourceDirectionLayers[direction]
    sprite:GetLayer(layer):SetVisible(true)
end

---@param sprite Sprite
local function UpdateSprite(sprite)
    if sprite:IsFinished(APPEAR_ANIMATION) then
        sprite:Play(IDLE_ANIMATION, true)
    end
    sprite:Update()
end

---@param sprite Sprite
---@return ViewFrameData
local function GetViewFrameData(sprite)
    local frameData = sprite:GetNullFrame(VIEW_NULL_LAYER_NAME)
    if not frameData then
        error(Log.Format(Log.LogType.ERROR, "no null frame found for layer \"" .. VIEW_NULL_LAYER_NAME .. "\" in View Bubble Sprite."))
    end

    local scale = sprite.Scale

    ---@type ViewFrameData
    local viewFrameData = {
        position = frameData:GetPos() * scale,
        scale = frameData:GetScale() * scale,
        color = frameData:GetColor() * sprite.Color,
    }

    return viewFrameData
end

--#region Module

BubbleSpriteUtils.CreateSprite = CreateSprite
BubbleSpriteUtils.InitSprite = InitSprite
BubbleSpriteUtils.UpdateSprite = UpdateSprite
BubbleSpriteUtils.GetViewFrameData = GetViewFrameData

--#endregion

return BubbleSpriteUtils