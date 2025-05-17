---@class PredictionSprites
local PredictionSprites = {}

local PICKUP_PRICE_ANM2 = ""

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
        return "Hearts"
    end

    if price < originalPrice then
        return "NumbersRed"
    end

    return "NumbersWhite"
end

---@param sprite Sprite
---@param price PickupPrice | integer
local function init_regular_price_sprite_frame(sprite, price)
    if price < 10 then
        sprite:GetLayer(0):SetVisible(false)
    else
        sprite:SetLayerFrame(0, price // 10)
    end
    sprite:SetLayerFrame(1, price % 10)
    sprite:SetLayerFrame(2, 10)
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
---@param price PickupPrice | integer
---@param originalPrice PickupPrice | integer
local function InitPriceSprite(sprite, price, originalPrice)
    sprite:Load(PICKUP_PRICE_ANM2, true)
    local animation = get_price_animation(price, originalPrice)
    sprite:SetAnimation(animation, true)

    if price < 0 then
        init_special_price_sprite_frame(sprite, price)
        return
    end

    init_regular_price_sprite_frame(sprite, price)
end

--#region Module

PredictionSprites.InitPriceSprite = InitPriceSprite

--#endregion

return PredictionSprites