---@class PedestalSpriteUtils
local PedestalSpriteUtils = {}

local PEDESTAL_ANM2_PATH = "gfx/dataminer_rework/dataminer_bubble/collectible_pedestal.anm2"

local s_Animations = {
    PEDESTAL = "Pedestal",
    PRICE_REGULAR = "NumbersWhite",
    PRICE_DISCOUNT = "NumbersRed",
    PRICE_SPECIAL = "Hearts",
}

local s_Layers = {
    PRICE_TENS_DIGIT = 0,
    PRICE_ONES_DIGIT = 1,
    PRICE_CURRENCY_SYMBOL = 2,
}

local s_SpecialPriceFrame = {
    [PickupPrice.PRICE_ONE_HEART] = 0,
    [PickupPrice.PRICE_TWO_HEARTS] = 1,
    [PickupPrice.PRICE_THREE_SOULHEARTS] = 2,
    [PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS] = 3,
    [PickupPrice.PRICE_SOUL] = 4,
    [PickupPrice.PRICE_ONE_SOUL_HEART] = 5,
    [PickupPrice.PRICE_TWO_SOUL_HEARTS] = 6,
    [PickupPrice.PRICE_ONE_HEART_AND_ONE_SOUL_HEART] = 7,
}

---@param price PickupPrice | integer
---@param originalPrice PickupPrice | integer
---@return string
local function get_price_animation(price, originalPrice)
    if price < 0 and price ~= PickupPrice.PRICE_FREE then
        return s_Animations.PRICE_SPECIAL
    end

    if price < originalPrice then
        return s_Animations.PRICE_DISCOUNT
    end

    return s_Animations.PRICE_REGULAR
end

---@param sprite Sprite
---@param price PickupPrice | integer
local function init_regular_price_sprite_frame(sprite, price)
    if price < 10 then
        sprite:GetLayer(s_Layers.PRICE_TENS_DIGIT):SetVisible(false)
    else
        sprite:SetLayerFrame(s_Layers.PRICE_TENS_DIGIT, price // 10)
    end
    sprite:SetLayerFrame(s_Layers.PRICE_ONES_DIGIT, price % 10)
    sprite:SetLayerFrame(s_Layers.PRICE_CURRENCY_SYMBOL, 10)
end

---@param sprite Sprite
---@param price PickupPrice | integer
local function init_special_price_sprite_frame(sprite, price)
    if price == PickupPrice.PRICE_FREE then
        init_regular_price_sprite_frame(sprite, 0)
        return
    end

    local frame = s_SpecialPriceFrame[price]
    if not frame then
        return
    end

    sprite:SetFrame(frame)
end

---@param sprite Sprite
local function init_pedestal_sprite(sprite)
    sprite:SetFrame(s_Animations.PEDESTAL, 0)
end

local function init_price_sprite(sprite, price, originalPrice)
    local animation = get_price_animation(price, originalPrice)
    sprite:SetAnimation(animation, true)

    if price < 0 then
        init_special_price_sprite_frame(sprite, price)
        return
    end

    init_regular_price_sprite_frame(sprite, price)
end

---@return Sprite
local function CreateSprite()
    local sprite = Sprite()
    sprite:Load(PEDESTAL_ANM2_PATH, true)
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    sprite:SetFrame(0)
    return sprite
end

---@param sprite Sprite
---@param price PickupPrice | integer
local function InitSprite(sprite, price, originalPrice)
    sprite:Reload()
    sprite:SetAnimation(sprite:GetDefaultAnimation(), true)
    if price == 0 then
        init_pedestal_sprite(sprite)
    else
        init_price_sprite(sprite, price, originalPrice)
    end
end

--#region Module

PedestalSpriteUtils.CreateSprite = CreateSprite
PedestalSpriteUtils.InitSprite = InitSprite

--#endregion

return PedestalSpriteUtils