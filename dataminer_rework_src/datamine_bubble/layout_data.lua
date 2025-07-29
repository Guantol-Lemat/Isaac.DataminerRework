---@class LayoutData
local LayoutData = {}

--#region Dependencies

local Log = require("log")

--#endregion

local LAYOUT_ANM2_PATH = "gfx/dataminer_rework/layout.anm2"

---@enum CollectibleLayout
local CollectibleLayout = {
    COLLECTIBLE_1 = 1,
    COLLECTIBLE_2 = 2,
    COLLECTIBLE_3 = 3,
    COLLECTIBLE_4 = 4,
}

---@enum BossLayout
local BossLayout = {
    BOSS_1 = 1,
    BOSS_2 = 2,
}

---@enum ChestLayout
local ChestLayout = {
    CHEST_1 = 1,
    CHEST_2 = 2,
    CHEST_3 = 3,
    CHEST_4 = 4,
}

local s_Animations = {
    BUBBLE_DOOR_LAYOUT = "_Bubble_Door",
    COLLECTIBLE_PEDESTAL = "_Collectible_Pedestal",
    COLLECTIBLE_LAYOUT = "_Collectible_Layout",
    BOSS_LAYOUT = "_Boss_Layout",
    CHEST_LAYOUT = "_Chest_Layout",
}

local s_Layers = {
    BUBBLE = 0,
    BUBBLE_SOURCE_LEFT = 12,
    BUBBLE_SOURCE_UP = 13,
    BUBBLE_SOURCE_RIGHT = 14,
    BUBBLE_SOURCE_DOWN = 15,
    BUBBLE_DOOR = 16,
    PEDESTAL_1 = 1,
    PEDESTAL_2 = 3,
    PEDESTAL_3 = 4,
    PEDESTAL_4 = 5,
    COLLECTIBLE = 2,
    BOSS_1 = 6,
    BOSS_2 = 7,
    CHEST_1 = 8,
    CHEST_2 = 9,
    CHEST_3 = 10,
    CHEST_4 = 11,
}

---@type table<Direction, BubbleDirectionData>
local s_BubbleDirectionData = {}

local s_CollectiblePositionOffset = Vector(0, 0)

---@type table<CollectibleLayout, Vector[]>
local s_CollectibleLayoutData = {}

---@type table<BossLayout, Vector[]>
local s_BossLayoutData = {}

---@type table<ChestLayout, Vector[]>
local s_ChestLayoutData = {}

--#region Bubble Direction Data

---@class BubbleDirectionData
---@field positionOffset Vector
---@field activeSources boolean[]

---@param animationData AnimationData
---@param frame integer
---@return BubbleDirectionData
local function get_direction_data(animationData, frame)
    ---@type BubbleDirectionData
    local directionData = {
        positionOffset = Vector(0, 0),
        activeSources = {}
    }

    local bubbleLayer = animationData:GetLayer(s_Layers.BUBBLE)
    local doorLayer = animationData:GetLayer(s_Layers.BUBBLE_DOOR)

    local sourceLayers = {
        [Direction.LEFT] = animationData:GetLayer(s_Layers.BUBBLE_SOURCE_LEFT),
        [Direction.UP] = animationData:GetLayer(s_Layers.BUBBLE_SOURCE_UP),
        [Direction.RIGHT] = animationData:GetLayer(s_Layers.BUBBLE_SOURCE_RIGHT),
        [Direction.DOWN] = animationData:GetLayer(s_Layers.BUBBLE_SOURCE_DOWN),
    }

    local bubblePosition = bubbleLayer:GetFrame(frame):GetPos()
    local doorPosition = doorLayer:GetFrame(frame):GetPos()

    directionData.positionOffset = doorPosition - bubblePosition
    for i = Direction.LEFT, Direction.DOWN, 1 do
        directionData.activeSources[i] = sourceLayers[i]:GetFrame(frame):IsVisible()
    end

    return directionData
end

---@param sprite Sprite
---@return table<Direction, BubbleDirectionData>
local function init_bubble_direction_data(sprite)
    local bubblePositionData = {}

    local bubbleAnimation = sprite:GetAnimationData(s_Animations.BUBBLE_DOOR_LAYOUT)
    if not bubbleAnimation then
        error(Log.Format(Log.LogType.ERROR, "Layout ANM2 does not contain animation: \"" .. s_Animations.BUBBLE_DOOR_LAYOUT .. "\""))
    end

    for i = Direction.LEFT, Direction.DOWN, 1 do
        bubblePositionData[i] = get_direction_data(bubbleAnimation, i)
    end

    return bubblePositionData
end

--#endregion

--#region Collectible Data

---@param sprite Sprite
---@return Vector
local function init_collectible_position_offset(sprite)
    local animationData = sprite:GetAnimationData(s_Animations.COLLECTIBLE_PEDESTAL)
    if not animationData then
        error(Log.Format(Log.LogType.ERROR, "Layout ANM2 does not contain animation: \"" .. s_Animations.COLLECTIBLE_PEDESTAL .. "\""))
    end

    return animationData:GetLayer(s_Layers.COLLECTIBLE):GetFrame(0):GetPos()
end

local s_PedestalLayers = {
    [1] = s_Layers.PEDESTAL_1,
    [2] = s_Layers.PEDESTAL_2,
    [3] = s_Layers.PEDESTAL_3,
    [4] = s_Layers.PEDESTAL_4,
}

---@param animationData AnimationData
---@param frame integer
---@return Vector[]
local function get_collectible_positions(animationData, frame)
    local positions = {}

    for i = 1, 4, 1 do
        local frameData = animationData:GetLayer(s_PedestalLayers[i]):GetFrame(frame)
        if not frameData then
            goto continue
        end

        if not frameData:IsVisible() then
            goto continue
        end

        positions[i] = frameData:GetPos()
        ::continue::
    end

    return positions
end

---@param sprite Sprite
---@return table<integer, Vector[]>
local function init_collectible_layout_data(sprite)
    local collectibleLayout = {}

    local animationData = sprite:GetAnimationData(s_Animations.COLLECTIBLE_LAYOUT)
    if not animationData then
        error(Log.Format(Log.LogType.ERROR, "Layout ANM2 does not contain animation: \"" .. s_Animations.COLLECTIBLE_LAYOUT .. "\""))
    end

    for i = 1, 4, 1 do
        local positions = get_collectible_positions(animationData, i - 1)
        collectibleLayout[i] = positions
        assert(#positions >= i, Log.Format(Log.LogType.ASSERT, "Collectible Layout at frame %d does not contain at least %d positions", i - 1, i))
    end

    return collectibleLayout
end

--#endregion

--#region Boss Layout Data

local s_BossLayers = {
    [1] = s_Layers.BOSS_1,
    [2] = s_Layers.BOSS_2,
}

---@param animationData AnimationData
---@param frame integer
---@return Vector[]
local function get_boss_positions(animationData, frame)
    local positions = {}

    for i = 1, 2, 1 do
        local frameData = animationData:GetLayer(s_BossLayers[i]):GetFrame(frame)
        if not frameData then
            goto continue
        end

        if not frameData:IsVisible() then
            goto continue
        end

        positions[i] = frameData:GetPos()
        ::continue::
    end

    return positions
end

---@param sprite Sprite
---@return table<integer, Vector[]>
local function init_boss_layout_data(sprite)
    local bossLayout = {}

    local animationData = sprite:GetAnimationData(s_Animations.BOSS_LAYOUT)
    if not animationData then
        error(Log.Format(Log.LogType.ERROR, "Layout ANM2 does not contain animation: \"" .. s_Animations.BOSS_LAYOUT .. "\""))
    end

    for i = 1, 2, 1 do
        local positions = get_boss_positions(animationData, i - 1)
        bossLayout[i] = positions
        assert(#positions >= i, Log.Format(Log.LogType.ASSERT, "Boss Layout at frame %d does not contain at least %d positions", i - 1, i))
    end

    return bossLayout
end

--#endregion

--#region Chest Layout Data

local s_ChestLayers = {
    [1] = s_Layers.CHEST_1,
    [2] = s_Layers.CHEST_2,
    [3] = s_Layers.CHEST_3,
    [4] = s_Layers.CHEST_4,
}

---@param animationData AnimationData
---@param frame integer
---@return Vector[]
local function get_chest_positions(animationData, frame)
    local positions = {}

    for i = 1, 4, 1 do
        local frameData = animationData:GetLayer(s_ChestLayers[i]):GetFrame(frame)
        if not frameData then
            goto continue
        end

        if not frameData:IsVisible() then
            goto continue
        end

        positions[i] = frameData:GetPos()
        ::continue::
    end

    return positions
end

---@param sprite Sprite
---@return table<integer, Vector[]>
local function init_chest_layout_data(sprite)
    local chestLayout = {}

    local animationData = sprite:GetAnimationData(s_Animations.CHEST_LAYOUT)
    if not animationData then
        error(Log.Format(Log.LogType.ERROR, "Layout ANM2 does not contain animation: \"" .. s_Animations.CHEST_LAYOUT .. "\""))
    end

    for i = 1, 4, 1 do
        local positions = get_chest_positions(animationData, i - 1)
        chestLayout[i] = positions
        assert(#positions >= i, Log.Format(Log.LogType.ASSERT, "Chest Layout at frame %d does not contain at least %d positions", i - 1, i))
    end

    return chestLayout
end

--#endregion

local function InitLayoutData()
    local sprite = Sprite()
    sprite:Load(LAYOUT_ANM2_PATH, false)

    s_BubbleDirectionData = init_bubble_direction_data(sprite)
    s_CollectiblePositionOffset = init_collectible_position_offset(sprite)
    s_CollectibleLayoutData = init_collectible_layout_data(sprite)
    s_BossLayoutData = init_boss_layout_data(sprite)
    s_ChestLayoutData = init_chest_layout_data(sprite)
end

---@param direction Direction
---@return BubbleDirectionData
local function GetBubbleDirectionData(direction)
    return s_BubbleDirectionData[direction]
end

---@return Vector
local function GetCollectiblePositionOffset()
    return s_CollectiblePositionOffset
end

---@param layout CollectibleLayout
---@return Vector[]
local function GetCollectibleLayoutData(layout)
    return s_CollectibleLayoutData[layout]
end

---@param layout BossLayout
---@return Vector[]
local function GetBossLayoutData(layout)
    return s_BossLayoutData[layout]
end

---@param layout ChestLayout
---@return Vector[]
local function GetChestLayoutData(layout)
    return s_ChestLayoutData[layout]
end

--#region Module

LayoutData.CollectibleLayout = CollectibleLayout
LayoutData.BossLayout = BossLayout
LayoutData.ChestLayout = ChestLayout
LayoutData.InitLayoutData = InitLayoutData
LayoutData.GetBubbleDirectionData = GetBubbleDirectionData
LayoutData.GetCollectiblePositionOffset = GetCollectiblePositionOffset
LayoutData.GetCollectibleLayoutData = GetCollectibleLayoutData
LayoutData.GetBossLayoutData = GetBossLayoutData
LayoutData.GetChestLayoutData = GetChestLayoutData

--#endregion

return LayoutData