---@class Enums
local Enums = {}

---@enum Enums.ShopItemType
local eShopItemType = {
    HEART_FULL = 0,
    BOMB_SINGLE = 1,
    PILL = 2,
    KEY_SINGLE = 3,
    SOUL_HEART = 4,
    LIL_BATTERY = 5,
    CARD = 6,
    GRAB_BAG = 7,
    COLLECTIBLE = 8,
    COLLECTIBLE_BOSS = 9,
    COLLECTIBLE_TREASURE = 10,
    TRINKET = 11,
    COLLECTIBLE_DEVIL = 12,
    COLLECTIBLE_ANGEL = 13,
    COLLECTIBLE_SECRET = 14,
    HEART_SPECIAL = 15, -- Black, Eternal, Bone or Rotten
    RUNE = 16,
    COLLECTIBLE_SHOP = 17,
    COLLECTIBLE_BABY_SHOP = 18,
    HEART_ETERNAL = 19,
    HOLY_CARD = 20
}

--#region Module

Enums.eShopItemType = eShopItemType

--#endregion

return Enums