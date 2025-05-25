---@class VirtualShopModule
local VirtualShop = {}

--#region Dependencies

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_ItemPool = g_Game:GetItemPool()
local g_PlayerManager = PlayerManager
local g_ItemConfig = Isaac.GetItemConfig()
local g_PersistentGameData = Isaac.GetPersistentGameData()

local Enums = require("enums")

local Lib = {
    Math = require("lib.math"),
    RNG = require("lib.rng"),
    ItemPool = require("lib.itempool"),
    EntityPickup = require("lib.entity_pickup"),
}

local EntityRedirection = require("datamining.entity_redirection")
local VirtualRoomQueries = require("datamining.virtual_room_queries")

--#endregion

---@class VirtualShop
---@field m_Room VirtualRoom
---@field m_ShopLevel integer
---@field m_NextShopItemIdx integer
---@field m_ShopItemIdxDeque integer[]
---@field m_DiscountShopItemIdx integer -- -1 for no discount
---@field m_ShopItemType integer[] -- One for each shop item slot
---@field m_TimesRestocked integer[] -- One for each shop item slot

---@param virtualRoom VirtualRoom
---@return VirtualShop
local function CreateVirtualShop(virtualRoom)
    ---@type VirtualShop
    local shop = {
        m_Room = virtualRoom,
        m_ShopLevel = 0,
        m_NextShopItemIdx = -1,
        m_ShopItemIdxDeque = {},
        m_DiscountShopItemIdx = -1,
        m_ShopItemType = {0, 0, 0, 0, 0, 0, 0, 0},
        m_TimesRestocked = {0, 0, 0, 0, 0, 0, 0, 0},
    }

    return shop
end

local s_ActiveVirtualShops = setmetatable({}, { __mode = "k" })
local function count_active_virtual_shops()
    local count = 0
    for _ in pairs(s_ActiveVirtualShops) do
        count = count + 1
    end
    return count
end

---Record created object to check for memory leaks
if DATAMINER_DEBUG_MODE then
    local old_create_virtual_room = CreateVirtualShop
    ---@param virtualRoom VirtualRoom
    ---@return VirtualShop
    CreateVirtualShop = function(virtualRoom)
        local virtualShop = old_create_virtual_room(virtualRoom)
        s_ActiveVirtualShops[virtualShop] = true
        return virtualShop
    end
end

---@param roomData RoomConfigRoom
---@return boolean
local function is_keeper_shop(roomData)
    return roomData.Type == RoomType.ROOM_SHOP and (100 <= roomData.Subtype and roomData.Subtype < 120)
end

--#region Init

---@param rng RNG
---@param maxDiscountIdx integer
---@return integer
local function get_discount_idx(rng, maxDiscountIdx)
    if rng:RandomInt(3) == 0 then
        return -1
    end

    return rng:RandomInt(maxDiscountIdx)
end

---@param shop VirtualShop
---@param rng RNG
local function init_devil_shop(shop, rng)
    for i = 1, #shop.m_ShopItemType, 1 do
        shop.m_ShopItemType[i] = Enums.eShopItemType.COLLECTIBLE
    end

    shop.m_NextShopItemIdx = 0
    shop.m_DiscountShopItemIdx = get_discount_idx(rng, 6)
end

---@param shop VirtualShop
---@param rng RNG
local function init_angel_shop(shop, rng)
    local shopItems = {
        Enums.eShopItemType.COLLECTIBLE, Enums.eShopItemType.SOUL_HEART, Enums.eShopItemType.SOUL_HEART,
        Enums.eShopItemType.KEY_SINGLE, Enums.eShopItemType.KEY_SINGLE, Enums.eShopItemType.HEART_ETERNAL,
        Enums.eShopItemType.HEART_ETERNAL, Enums.eShopItemType.HOLY_CARD,
    }

    Lib.RNG.RandomShuffle(shopItems, rng, 1, #shopItems)

    local itemsCount = math.min(#shop.m_ShopItemType, #shopItems)
    for i = 1, itemsCount, 1 do
        shop.m_ShopItemType[i] = shopItems[i]
    end
    shop.m_ShopItemType[2] = Enums.eShopItemType.COLLECTIBLE

    shop.m_NextShopItemIdx = 0
    shop.m_DiscountShopItemIdx = get_discount_idx(rng, 6)
end

---@param shop VirtualShop
---@param rng RNG
local function init_keeper_shop(shop, rng)
    local randomShopItems = {
        Enums.eShopItemType.TRINKET, Enums.eShopItemType.KEY_SINGLE, Enums.eShopItemType.BOMB_SINGLE,
        Enums.eShopItemType.CARD, Enums.eShopItemType.LIL_BATTERY, Enums.eShopItemType.PILL,
    }

    Lib.RNG.RandomShuffle(randomShopItems, rng, 1, #randomShopItems)

    shop.m_ShopItemType[1] = randomShopItems[1]
    shop.m_ShopItemType[2] = randomShopItems[2]
    shop.m_ShopItemType[3] = Enums.eShopItemType.COLLECTIBLE
    shop.m_ShopItemType[4] = Enums.eShopItemType.COLLECTIBLE_BOSS
    shop.m_ShopItemType[5] = Enums.eShopItemType.COLLECTIBLE_TREASURE

    randomShopItems[1] = Enums.eShopItemType.COLLECTIBLE
    randomShopItems[2] = Enums.eShopItemType.COLLECTIBLE_TREASURE

    Lib.RNG.RandomShuffle(randomShopItems, rng, 1, #randomShopItems)

    shop.m_ShopItemType[6] = randomShopItems[1]
    shop.m_ShopItemType[7] = randomShopItems[2]
    shop.m_ShopItemType[8] = Enums.eShopItemType.COLLECTIBLE_TREASURE

    shop.m_NextShopItemIdx = 0
    shop.m_DiscountShopItemIdx = get_discount_idx(rng, 8)
end

---@param shop VirtualShop
---@param rng RNG
local function init_secret_shop(shop, rng)
    local shopItems = {
        Enums.eShopItemType.COLLECTIBLE,
        rng:RandomInt(2) == 0 and Enums.eShopItemType.COLLECTIBLE_ANGEL or Enums.eShopItemType.COLLECTIBLE_DEVIL,
        rng:RandomInt(8) == 0 and Enums.eShopItemType.COLLECTIBLE_SECRET or Enums.eShopItemType.COLLECTIBLE_BOSS,
        Enums.eShopItemType.TRINKET, Enums.eShopItemType.TRINKET, Enums.eShopItemType.HEART_SPECIAL,
        Enums.eShopItemType.CARD, Enums.eShopItemType.RUNE,
    }

    Lib.RNG.RandomShuffle(shopItems, rng, 1, #shopItems)

    local itemsCount = math.min(#shop.m_ShopItemType, #shopItems)
    for i = 1, itemsCount, 1 do
        shop.m_ShopItemType[i] = shopItems[i]
    end

    shop.m_NextShopItemIdx = 0
    shop.m_DiscountShopItemIdx = get_discount_idx(rng, 8)
end

local s_GreedRandomShopItem = {
    [1] = Enums.eShopItemType.KEY_SINGLE,
    [2] = Enums.eShopItemType.BOMB_SINGLE,
    [3] = Enums.eShopItemType.HEART_FULL,
    [4] = Enums.eShopItemType.SOUL_HEART,
    [5] = Enums.eShopItemType.COLLECTIBLE,
    [6] = Enums.eShopItemType.COLLECTIBLE_TREASURE,
    [7] = Enums.eShopItemType.LIL_BATTERY,
    [8] = Enums.eShopItemType.PILL,
    [9] = Enums.eShopItemType.CARD,
    [10] = Enums.eShopItemType.TRINKET,
}

---@param seed integer
---@return Enums.ShopItemType
local function get_random_greed_shop_item(seed)
    return s_GreedRandomShopItem[seed % #s_GreedRandomShopItem + 1]
end

---@param shop VirtualShop
---@param rng RNG
local function init_greed_shop(shop, rng)
    shop.m_ShopItemType[1] = Enums.eShopItemType.KEY_SINGLE
    shop.m_ShopItemType[2] = Enums.eShopItemType.HEART_FULL
    shop.m_ShopItemType[3] = Enums.eShopItemType.COLLECTIBLE
    shop.m_ShopItemType[4] = Enums.eShopItemType.COLLECTIBLE_BOSS
    shop.m_ShopItemType[5] = get_random_greed_shop_item(rng:Next())
    shop.m_ShopItemType[6] = get_random_greed_shop_item(rng:Next())
    shop.m_ShopItemType[7] = get_random_greed_shop_item(rng:Next())
    shop.m_ShopItemType[8] = get_random_greed_shop_item(rng:Next())

    shop.m_NextShopItemIdx = 0
    shop.m_DiscountShopItemIdx = get_discount_idx(rng, 8)
end

---@param shop VirtualShop
---@param rng RNG
local function init_generic_shop(shop, rng)
    local randomShopItems = {}

    for i = 1, 8, 1 do
        table.insert(randomShopItems, i - 1)
    end

    if shop.m_ShopLevel > 3 then
        table.insert(randomShopItems, Enums.eShopItemType.COLLECTIBLE)
    end

    Lib.RNG.RandomShuffle(randomShopItems, rng, 1, #randomShopItems)

    local itemsCount = math.min(#shop.m_ShopItemType, #randomShopItems)
    for i = 1, itemsCount, 1 do
        shop.m_ShopItemType[i] = randomShopItems[i]
    end
    shop.m_ShopItemType[rng:RandomInt(2) + 1] = Enums.eShopItemType.COLLECTIBLE

    shop.m_NextShopItemIdx = 0
    shop.m_DiscountShopItemIdx = get_discount_idx(rng, 6)
end

---@param shop VirtualShop
---@param rng RNG
local function init_shop_service(shop, rng)
    local roomDesc = shop.m_Room.m_RoomDescriptor
    local roomData = roomDesc.Data
    local roomType = roomData and roomData.Type or RoomType.ROOM_DEFAULT

    if roomType == RoomType.ROOM_DEVIL or roomType == RoomType.ROOM_BLACK_MARKET or (roomDesc.Flags & RoomDescriptor.FLAG_DEVIL_TREASURE ~= 0) then
        init_devil_shop(shop, rng)
        return
    end

    if roomType == RoomType.ROOM_ANGEL then
        init_angel_shop(shop, rng)
        return
    end

    if roomData and is_keeper_shop(roomData) then
        init_keeper_shop(shop, rng)
        return
    end

    if shop.m_Room.m_RoomIdx == GridRooms.ROOM_SECRET_SHOP_IDX then
        init_secret_shop(shop, rng)
        return
    end

    if g_Game:IsGreedMode() or (roomData and is_keeper_shop(roomData)) then
        init_greed_shop(shop, rng)
        return
    end

    init_generic_shop(shop, rng)
end

---@param shop VirtualShop
local function InitShop(shop)
    local room = shop.m_Room
    local roomDesc = room.m_RoomDescriptor

    for i = 1, #shop.m_TimesRestocked, 1 do
        shop.m_TimesRestocked[i] = 0
    end

    local rng = RNG(roomDesc.AwardSeed, 35)
    init_shop_service(shop, rng)
    roomDesc.AwardSeed = rng:GetSeed()
end

--#endregion

--#region PickupDetails

--#region ShopItemPickup

---@class ShopPickup
---@field variant PickupVariant | integer
---@field subtype integer

---@param shop VirtualShop
---@param roomType RoomType
---@param index integer
local function should_perform_baby_shop_morph(shop, roomType, index)
    if not (roomType == RoomType.ROOM_SHOP or roomType == RoomType.ROOM_BLACK_MARKET) then
        return
    end

    local shopItemType = shop.m_ShopItemType[index + 1]
    if not (shopItemType == Enums.eShopItemType.COLLECTIBLE or shopItemType == Enums.eShopItemType.COLLECTIBLE_SHOP) then
        return
    end

    shop.m_ShopItemType[index + 1] = Enums.eShopItemType.COLLECTIBLE_BABY_SHOP
end

--#region GetShopPickup Switch

---@param poolType ItemPoolType
---@param seed integer
local function get_item_pool_collectible(poolType, seed)
    if g_Game:IsGreedMode() then
        poolType = Lib.ItemPool.GetGreedModePool(poolType)
    end

    return g_ItemPool:GetCollectible(poolType, false, seed, CollectibleType.COLLECTIBLE_NULL)
end

---@class Switch.GetShopPickup
---@field room VirtualRoom
---@field seed integer

---@param io Switch.GetShopPickup
local function get_heart_full(io)
    return {PickupVariant.PICKUP_HEART, HeartSubType.HEART_FULL}
end

---@param io Switch.GetShopPickup
local function get_bomb_single(io)
    return {PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL}
end

---@param io Switch.GetShopPickup
local function get_pill(io)
    return {PickupVariant.PICKUP_PILL, g_ItemPool:GetPill(io.seed)}
end

---@param io Switch.GetShopPickup
local function get_key_single(io)
    return {PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL}
end

---@param io Switch.GetShopPickup
local function get_soul_heart(io)
    return {PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL}
end

---@param io Switch.GetShopPickup
local function get_lil_battery(io)
    return {PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_NORMAL}
end

---@param io Switch.GetShopPickup
local function get_card(io)
    return {PickupVariant.PICKUP_TAROTCARD, g_ItemPool:GetCard(io.seed, true, false, false)}
end

---@param io Switch.GetShopPickup
local function get_grab_bag(io)
    return {PickupVariant.PICKUP_GRAB_BAG, SackSubType.SACK_NORMAL}
end

---@param io Switch.GetShopPickup
local function get_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, VirtualRoomQueries.GetSeededCollectible(io.room, io.seed, true)}
end

---@param io Switch.GetShopPickup
local function get_boss_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_BOSS, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_treasure_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_TREASURE, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_trinket(io)
    return {PickupVariant.PICKUP_TRINKET, g_ItemPool:GetTrinket(true)}
end

---@param io Switch.GetShopPickup
local function get_devil_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_DEVIL, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_angel_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_ANGEL, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_secret_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_SECRET, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_special_heart(io)
    local rng = RNG(io.seed, 51)

    local heartSubType = HeartSubType.HEART_BLACK

    if rng:RandomInt(3) == 0 then
        heartSubType = HeartSubType.HEART_ETERNAL
    end

    if rng:RandomInt(4) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_BONE) then
        heartSubType = HeartSubType.HEART_BONE
    end

    if rng:RandomInt(4) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_ROTTEN) then
        heartSubType = HeartSubType.HEART_ROTTEN
    end

    return {PickupVariant.PICKUP_HEART, heartSubType}
end

---@param io Switch.GetShopPickup
local function get_rune(io)
    return {PickupVariant.PICKUP_TAROTCARD, g_ItemPool:GetCard(io.seed, false, true, true)}
end

---@param io Switch.GetShopPickup
local function get_shop_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_SHOP, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_baby_shop_collectible(io)
    return {PickupVariant.PICKUP_COLLECTIBLE, get_item_pool_collectible(ItemPoolType.POOL_BABY_SHOP, io.seed)}
end

---@param io Switch.GetShopPickup
local function get_eternal_heart(io)
    return {PickupVariant.PICKUP_HEART, HeartSubType.HEART_ETERNAL}
end

---@param io Switch.GetShopPickup
local function get_holy_card(io)
    if not g_PersistentGameData:Unlocked(Achievement.HOLY_CARD) then
        return get_key_single(io)
    end

    return {PickupVariant.PICKUP_TAROTCARD, Card.CARD_HOLY}
end

local switch_GetShopPickup = {
    [Enums.eShopItemType.HEART_FULL] = get_heart_full,
    [Enums.eShopItemType.BOMB_SINGLE] = get_bomb_single,
    [Enums.eShopItemType.PILL] = get_pill,
    [Enums.eShopItemType.KEY_SINGLE] = get_key_single,
    [Enums.eShopItemType.SOUL_HEART] = get_soul_heart,
    [Enums.eShopItemType.LIL_BATTERY] = get_lil_battery,
    [Enums.eShopItemType.CARD] = get_card,
    [Enums.eShopItemType.GRAB_BAG] = get_grab_bag,
    [Enums.eShopItemType.COLLECTIBLE] = get_collectible,
    [Enums.eShopItemType.COLLECTIBLE_BOSS] = get_boss_collectible,
    [Enums.eShopItemType.COLLECTIBLE_TREASURE] = get_treasure_collectible,
    [Enums.eShopItemType.TRINKET] = get_trinket,
    [Enums.eShopItemType.COLLECTIBLE_DEVIL] = get_devil_collectible,
    [Enums.eShopItemType.COLLECTIBLE_ANGEL] = get_angel_collectible,
    [Enums.eShopItemType.COLLECTIBLE_SECRET] = get_secret_collectible,
    [Enums.eShopItemType.HEART_SPECIAL] = get_special_heart,
    [Enums.eShopItemType.RUNE] = get_rune,
    [Enums.eShopItemType.COLLECTIBLE_SHOP] = get_shop_collectible,
    [Enums.eShopItemType.COLLECTIBLE_BABY_SHOP] = get_baby_shop_collectible,
    [Enums.eShopItemType.HEART_ETERNAL] = get_eternal_heart,
    [Enums.eShopItemType.HOLY_CARD] = get_holy_card,
}

--#endregion

---@param shop VirtualShop
---@param shopItem Enums.ShopItemType
---@param seed integer
---@return ShopPickup
local function get_shop_pickup(shop, shopItem, seed)
    ---@type Switch.GetShopPickup
    local io = {room = shop.m_Room, seed = seed}
    local GetShopPickup = switch_GetShopPickup[shopItem]
    local shopPickup = GetShopPickup(io)

    ---@type ShopPickup
    return {variant = shopPickup[1], subtype = shopPickup[2]}
end

---@param shop VirtualShop
---@param index integer
---@param seed integer
---@return ShopPickup
local function GetShopItem(shop, index, seed)
    local room = shop.m_Room
    index = Lib.Math.Clamp(index, 0, 7)

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_ADOPTION_PAPERS) and should_perform_baby_shop_morph(shop, room.m_RoomType, index) then
        shop.m_ShopItemType[index + 1] = Enums.eShopItemType.COLLECTIBLE_BABY_SHOP
    end

    return get_shop_pickup(shop, shop.m_ShopItemType[index + 1], seed)
end

--#endregion

--#region PickupPrice

---@param seed integer
---@return boolean
local function is_forced_coin_price(seed)
    if g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_KEEPER) or g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_KEEPER_B) then
        return true
    end

    local rng = RNG(seed, 77)
    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_KEEPERS_BARGAIN) and rng:RandomInt(2) == 0 then
        return true
    end

    return false
end

---@param shop VirtualShop
local function uses_devil_deal_price_logic(shop)
    local roomDesc = shop.m_Room.m_RoomDescriptor
    local roomData = roomDesc.Data
    local roomType = roomData and roomData.Type or RoomType.ROOM_DEFAULT

    if roomType == RoomType.ROOM_DEVIL or roomType == RoomType.ROOM_BLACK_MARKET then
        return true
    end

    if roomDesc.Flags & RoomDescriptor.FLAG_DEVIL_TREASURE ~= 0 then
        return true
    end

    if roomType == RoomType.ROOM_BOSS and g_Level:GetStateFlag(LevelStateFlag.STATE_SATANIC_BIBLE_USED) and not g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_KEEPER_B) then
        return true
    end

    return false
end

---@class Switch.GetShopPriceIO
---@field room VirtualRoom
---@field variant PickupVariant | integer
---@field subType integer
---@field rng RNG
---@field shopItemType Enums.ShopItemType | integer
---@field poundOfFlesh boolean
---@field forcedCoinPrice boolean

--#region Switch GetSecretShopPrice

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_secret_shop_trinket_price(io)
    if io.poundOfFlesh and not io.forcedCoinPrice then
        return PickupPrice.PRICE_SPIKES
    end

    return 15
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_secret_shop_tarot_card_price(io)
    if io.poundOfFlesh and not io.forcedCoinPrice then
        return PickupPrice.PRICE_SPIKES
    end

    return 6
end

local s_SecretShopHeartPrice = {
    [HeartSubType.HEART_ETERNAL] = 15,
    [HeartSubType.HEART_BONE] = 8,
    [HeartSubType.HEART_BLACK] = 8,
    [HeartSubType.HEART_SOUL] = 6,
    default = 5,
}

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_secret_shop_heart_price(io)
    if io.poundOfFlesh and not io.forcedCoinPrice then
        return PickupPrice.PRICE_SPIKES
    end

    return s_SecretShopHeartPrice[io.subType] or s_SecretShopHeartPrice.default
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_secret_shop_collectible_price(io)
    if io.poundOfFlesh and not io.forcedCoinPrice then
        return io.rng:RandomInt(2) ~= 0 and PickupPrice.PRICE_TWO_HEARTS or PickupPrice.PRICE_ONE_HEART
    end

    if io.shopItemType == Enums.eShopItemType.COLLECTIBLE_SECRET then
        return io.rng:RandomInt(80) + 20
    end

    local maxShopPrice = (io.shopItemType == Enums.eShopItemType.COLLECTIBLE_DEVIL or io.shopItemType == Enums.eShopItemType.COLLECTIBLE_ANGEL) and 50 or 30
    return io.rng:RandomInt(maxShopPrice - 14) + 15
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_secret_shop_default_price(io)
    return 5
end

local switch_GetSecretShopPrice = {
    [PickupVariant.PICKUP_TRINKET] = get_secret_shop_trinket_price,
    [PickupVariant.PICKUP_TAROTCARD] = get_secret_shop_tarot_card_price,
    [PickupVariant.PICKUP_HEART] = get_secret_shop_heart_price,
    [PickupVariant.PICKUP_COLLECTIBLE] = get_secret_shop_collectible_price,
    default = get_secret_shop_default_price,
}

--#endregion

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_secret_shop_item_price(io)
    local GetSecretShopPrice = switch_GetSecretShopPrice[io.variant] or switch_GetSecretShopPrice.default
    return GetSecretShopPrice(io)
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_devil_deal_item_price(io)
    if io.variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        if io.forcedCoinPrice or io.poundOfFlesh then
            return 5
        end

        return PickupPrice.PRICE_SPIKES
    end

    local collectibleConfig = g_ItemConfig:GetCollectible(io.subType)

    local price = 0
    if not collectibleConfig then
        Isaac.DebugString(string.format("[warn] Room::GetShopItemPrice: no config for collectible %d.", io.subType))
        price = io.rng:RandomInt(2) ~= 0 and PickupPrice.PRICE_TWO_HEARTS or PickupPrice.PRICE_ONE_HEART
    else
        price = collectibleConfig.DevilPrice >= 2 and PickupPrice.PRICE_TWO_HEARTS or PickupPrice.PRICE_ONE_HEART
    end

    if io.forcedCoinPrice or io.poundOfFlesh then
        price = price == PickupPrice.PRICE_TWO_HEARTS and 30 or 15
    end

    return price
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_regular_pickup_item_price(io)
    if io.poundOfFlesh and not io.forcedCoinPrice then
        return PickupPrice.PRICE_SPIKES
    end

    if io.variant == PickupVariant.PICKUP_HEART then
        return (io.subType == HeartSubType.HEART_FULL or io.subType == HeartSubType.HEART_HALF) and 3 or 5
    end

    if io.variant == PickupVariant.PICKUP_KEY then
        return io.subType == KeySubType.KEY_GOLDEN and 10 or 5
    end

    if io.variant == PickupVariant.PICKUP_BOMB then
        return io.subType == BombSubType.BOMB_GOLDEN and 10 or 5
    end

    if io.variant == PickupVariant.PICKUP_GRAB_BAG then
        return 7
    end

    return 5
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_regular_collectible_item_price(io)
    local collectibleConfig = g_ItemConfig:GetCollectible(io.subType)

    if io.poundOfFlesh and not io.forcedCoinPrice then
        if not collectibleConfig then
            return PickupPrice.PRICE_ONE_HEART
        end

        return -collectibleConfig.DevilPrice
    end

    if not collectibleConfig then
        Isaac.DebugString(string.format("[warn] Room::GetShopItemPrice: no config for collectible %d.", io.subType))
        return 15
    end

    if io.room.m_RoomType == RoomType.ROOM_ANGEL then
        return collectibleConfig.ShopPrice
    end

    local price = collectibleConfig.ShopPrice
    if price ~= 15 then
        return price
    end

    return collectibleConfig.DevilPrice == 2 and 30 or 15
end

---@param io Switch.GetShopPriceIO
---@return PickupPrice | integer
local function get_default_item_price(io)
    if io.variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        return get_regular_pickup_item_price(io)
    end

    return get_regular_collectible_item_price(io)
end

---@param shop VirtualShop
---@param variant PickupVariant | integer
---@param subType integer
---@param index integer
local function GetShopItemPrice(shop, variant, subType, index)
    local roomDesc = shop.m_Room.m_RoomDescriptor

    local seed = roomDesc.DecorationSeed & 0xfffff800 | variant + subType
    local rng = RNG(seed, 35)

    local poundOfFlesh = g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_POUND_OF_FLESH)
    local forcedCoinPrice = is_forced_coin_price(seed)

    local shopItemType = -1
    if 0 <= index or index < 8 then
        shopItemType = shop.m_ShopItemType[index + 1]
    end

    ---@type Switch.GetShopPriceIO
    local io = {room = shop.m_Room, variant = variant, subType = subType, shopItemType = shopItemType, rng = rng, poundOfFlesh = poundOfFlesh, forcedCoinPrice = forcedCoinPrice}

    if shop.m_Room.m_RoomIdx == GridRooms.ROOM_SECRET_SHOP_IDX then
        return get_secret_shop_item_price(io)
    end

    if uses_devil_deal_price_logic(shop) then
        return get_devil_deal_item_price(io)
    end

    return get_default_item_price(io)
end

--#endregion

--#region PickupPriceModifiers

---@class Shop.HeartData
---@field highestMaxHeart integer
---@field highestSoulHearts integer

---@param player EntityPlayer
---@param heartData Shop.HeartData
local function update_heart_data(player, heartData)
    if player.Variant ~= PlayerVariant.PLAYER or player:IsCoopGhost() then
        return
    end

    if player:IsHologram() or player.Parent ~= nil then
        return
    end

    if player:GetHealthType() == HealthType.LOST or player:HasInstantDeathCurse() then
        heartData.highestSoulHearts = math.max(heartData.highestSoulHearts, 1)
        return
    end

    heartData.highestMaxHeart = math.max(player:GetEffectiveMaxHearts(), heartData.highestMaxHeart)
    heartData.highestSoulHearts = math.max(player:GetSoulHearts(), heartData.highestSoulHearts)
end

---@param shop VirtualShop
---@param shopIndex integer
---@param price PickupPrice
local function get_modified_deal_price(shop, shopIndex, price)
    if price == PickupPrice.PRICE_SPIKES then
        return price
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_YOUR_SOUL) then
        return PickupPrice.PRICE_SOUL
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_JUDAS_TONGUE) and price == PickupPrice.PRICE_TWO_HEARTS then
        price = PickupPrice.PRICE_ONE_HEART
    end

    ---@type Shop.HeartData
    local heartData = {highestMaxHeart = 0, highestSoulHearts = 0}

    for index, player in ipairs(g_PlayerManager:GetPlayers()) do
        update_heart_data(player, heartData)
    end

    if g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_BLUEBABY) then
        if price == PickupPrice.PRICE_ONE_HEART then
            return PickupPrice.PRICE_ONE_SOUL_HEART
        end

        if price == PickupPrice.PRICE_TWO_HEARTS then
            return PickupPrice.PRICE_TWO_SOUL_HEARTS
        end

        return price
    end

    if heartData.highestMaxHeart < 1 then
        return PickupPrice.PRICE_THREE_SOULHEARTS
    end

    local discount = shopIndex >= 0 and shop.m_DiscountShopItemIdx == shopIndex
    if price == PickupPrice.PRICE_TWO_HEARTS then
        if (discount and heartData.highestSoulHearts > 3) or heartData.highestMaxHeart < 4 then
            return PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS
        end
    end

    if price == PickupPrice.PRICE_ONE_HEART and discount then
        if heartData.highestSoulHearts > 5 then
            return PickupPrice.PRICE_THREE_SOULHEARTS
        end
    end

    return price
end

---@param shop VirtualShop
---@param shopIndex integer
local function get_discount_points(shop, shopIndex)
    local discountPoints = g_PlayerManager.GetNumCollectibles(CollectibleType.COLLECTIBLE_STEAM_SALE)
    if discountPoints > 0 then
        return discountPoints
    end

    if shopIndex >= 0 and shop.m_DiscountShopItemIdx == shopIndex then
        return 1
    end

    return 0
end

---@param price integer
---@param discountPoints integer
---@return integer
local function calc_discount_price(price, discountPoints)
    if discountPoints < 1 then
        return price
    end

    if discountPoints == 1 then
        return price // 2
    end

    return math.ceil(price / (discountPoints + 1))
end

---@param price integer
---@param originalPrice integer
---@param timesRestocked integer
---@return integer
local function calc_restocked_price(price, originalPrice, timesRestocked)
    local increaseRatio = math.max(originalPrice // 7, 1)
    price = (increaseRatio * (timesRestocked + 1) * timesRestocked) // 2 + price
    return math.min(price, 99)
end

---@param shop VirtualShop
---@param shopIndex integer
---@param price PickupPrice
local function get_modified_price(shop, shopIndex, price)
    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_ADOPTION_PAPERS) and shop.m_ShopItemType[shopIndex] == Enums.eShopItemType.COLLECTIBLE_BABY_SHOP then
        price = (price * 2) // 3
    end

    local originalPrice = price
    local discountPoints = get_discount_points(shop, shopIndex)

    if shop.m_Room.m_RoomType == RoomType.ROOM_SHOP and g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_STORE_CREDIT) then
        price = PickupPrice.PRICE_FREE
    else
        price = calc_discount_price(price, discountPoints)
    end

    if not g_Game:IsGreedMode() or price < 0 then
        local timesRestocked = shopIndex > -1 and shop.m_TimesRestocked[shopIndex] or 0
        price = calc_restocked_price(price, originalPrice, timesRestocked)
    end

    return price
end

---@param shop VirtualShop
---@param shopIndex integer
---@param price PickupPrice | integer
---@return PickupPrice | integer
local function TryGetShopDiscount(shop, shopIndex, price)
    if price == 0 then
        return 0
    end

    if price < 0 then
        return get_modified_deal_price(shop, shopIndex, price)
    end

    return get_modified_price(shop, shopIndex, price)
end

--#endregion

--#endregion

---@param shop VirtualShop
local function increase_shop_item_idx(shop)
    shop.m_NextShopItemIdx = (shop.m_NextShopItemIdx + 1) % 8
end

---@param shop VirtualShop
---@return integer
local function get_next_shop_item_idx(shop)
    if #shop.m_ShopItemIdxDeque > 0 then
        return shop.m_ShopItemIdxDeque[1] -- front
    end

    return shop.m_NextShopItemIdx
end

---@class ShopItemData : ShopPickup
---@field shopItemIdx integer
---@field price integer

---@param shop VirtualShop
---@param seed integer
---@return ShopItemData
local function MakeShopItem(shop, seed)
    if shop.m_NextShopItemIdx < 0 then
        InitShop(shop)
    end

    local shopItemIdx = get_next_shop_item_idx(shop)
    local shopPickup = GetShopItem(shop, shopItemIdx, seed)
    local price = GetShopItemPrice(shop, shopPickup.variant, shopPickup.subtype, shopItemIdx)
    price = TryGetShopDiscount(shop, shopItemIdx, price)

    if #shop.m_ShopItemIdxDeque == 0 then
        increase_shop_item_idx(shop)
    end

    ---@type ShopItemData
    return {
        shopItemIdx = shopItemIdx,
        variant = shopPickup.variant,
        subtype = shopPickup.subtype,
        price = price,
    }
end

--#region Module

VirtualShop.Create = CreateVirtualShop
VirtualShop.GetShopItem = GetShopItem
VirtualShop.GetShopItemPrice = GetShopItemPrice
VirtualShop.TryGetShopDiscount = TryGetShopDiscount
VirtualShop.MakeShopItem = MakeShopItem

if DATAMINER_DEBUG_MODE then
    VirtualShop.count_active_virtual_shops = count_active_virtual_shops
end

--#endregion

return VirtualShop