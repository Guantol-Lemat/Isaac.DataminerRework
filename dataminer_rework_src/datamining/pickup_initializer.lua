---@class PickupInitializer
local PickupInitializer = {}

--#region Dependencies

local Lib = {
    Table = require("lib.table"),
    Room = require("lib.room"),
    EntityPickup = require("lib.entity_pickup"),
    PlayerManager = require("lib.player_manager"),
    ItemConfig = require("lib.item_config"),
    WeightedOutcomePicker = require("lib.weighted_outcome_picker")
}

local g_Game = Game()
local g_Level = g_Game:GetLevel()
local g_ItemPool = g_Game:GetItemPool()
local g_Seeds = g_Game:GetSeeds()
local g_PlayerManager = PlayerManager
local g_ItemConfig = Isaac.GetItemConfig()
local g_PersistentGameData = Isaac.GetPersistentGameData()

local EntityRedirection = require("datamining.entity_redirection")
local VirtualRoomQueries = require("datamining.virtual_room_queries")
local Shop = require("datamining.virtual_shop")
local CustomCallbacks = require("callbacks")

--#endregion

---@class VirtualPickup
---@field m_Room VirtualRoom
---@field m_Type integer
---@field Variant integer
---@field SubType integer
---@field InitSeed integer
---@field m_DropRNG RNG
---@field m_Flags EntityFlag | integer
---@field Price PickupPrice | integer
---@field ShopItemId integer
---@field m_OptionsCycles CollectibleType[] | integer[]
---@field m_FlipCollectible CollectibleType | integer | nil

---@return VirtualPickup
local function CreateVirtualPickup()
    ---@type VirtualPickup
    local virtualPickup = {
---@diagnostic disable-next-line: assign-type-mismatch
        m_Room = nil,
        m_Type = EntityType.ENTITY_PICKUP,
        Variant = 0,
        SubType = 0,
        InitSeed = 0,
        m_DropRNG = RNG(),
        m_Flags = 0,
        Price = 0,
        ShopItemId = 0,
        m_OptionsCycles = {},
        m_FlipCollectible = nil,
    }

    return virtualPickup
end

local s_ActiveVirtualPickups = setmetatable({}, { __mode = "k" })
local function count_active_virtual_pickups()
    local count = 0
    for _ in pairs(s_ActiveVirtualPickups) do
        count = count + 1
    end
    return count
end

---Record created object to check for memory leaks
if DATAMINER_DEBUG_MODE then
    local old_create_virtual_pickup = CreateVirtualPickup
    ---@return VirtualPickup
    CreateVirtualPickup = function()
        local pickup = old_create_virtual_pickup()
        s_ActiveVirtualPickups[pickup] = true
        return pickup
    end
end

local s_IgnoreModifiers = 0

---@return boolean
local function ShouldIgnoreModifiers()
    return s_IgnoreModifiers ~= 0
end

local function BeginIgnoreModifiers()
    s_IgnoreModifiers = s_IgnoreModifiers + 1
end

local function EndIgnoreModifiers()
    s_IgnoreModifiers = s_IgnoreModifiers - 1
end

local function switch_break()
end

local function should_block_heart(rng)
    if not g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_DAEMONS_TAIL) then
        return false
    end

    return rng:RandomInt(5) ~= 0
end

--#region SelectVariant

local s_VariantWeights = {
    {PickupVariant.PICKUP_COIN, 20},
    {PickupVariant.PICKUP_HEART, 15},
    {PickupVariant.PICKUP_KEY, 15},
    {PickupVariant.PICKUP_BOMB, 15},
    {PickupVariant.PICKUP_CHEST, 5},
    {PickupVariant.PICKUP_LOCKEDCHEST, 5},
    {PickupVariant.PICKUP_PILL, 4},
    {PickupVariant.PICKUP_TAROTCARD, 4},
    {PickupVariant.PICKUP_LIL_BATTERY, 2},
    {PickupVariant.PICKUP_TRINKET, 1},
    {PickupVariant.PICKUP_COLLECTIBLE, 1},
}

local s_RetryVariantWeights = {
    s_VariantWeights[1],
    s_VariantWeights[3],
    s_VariantWeights[4],
    s_VariantWeights[2],
}

local s_VariantFilters = {
    [NullPickupSubType.ANY] = {},
    [NullPickupSubType.NO_COLLECTIBLE_CHEST] = Lib.Table.CreateDictionary({PickupVariant.PICKUP_COLLECTIBLE, PickupVariant.PICKUP_CHEST, PickupVariant.PICKUP_LOCKEDCHEST}),
    [NullPickupSubType.NO_COLLECTIBLE] = Lib.Table.CreateDictionary({PickupVariant.PICKUP_COLLECTIBLE}),
    [NullPickupSubType.NO_COLLECTIBLE_CHEST_COIN] = Lib.Table.CreateDictionary({PickupVariant.PICKUP_COLLECTIBLE, PickupVariant.PICKUP_CHEST, PickupVariant.PICKUP_LOCKEDCHEST, PickupVariant.PICKUP_COIN}),
    [NullPickupSubType.NO_COLLECTIBLE_TRINKET_CHEST] = Lib.Table.CreateDictionary({PickupVariant.PICKUP_COLLECTIBLE, PickupVariant.PICKUP_TRINKET, PickupVariant.PICKUP_CHEST, PickupVariant.PICKUP_LOCKEDCHEST}),
}

---@param variant PickupVariant
---@param filter NullPickupSubType
---@param randomFloat number
---@return boolean shouldMorph
local function should_morph_into_coin(variant, filter, randomFloat)
    if filter == NullPickupSubType.NO_COLLECTIBLE_CHEST_COIN or variant == PickupVariant.PICKUP_COIN then
        return false
    end

    return g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_RIB_OF_GREED) and randomFloat < 0.1
end

---@param variant PickupVariant
---@param filter NullPickupSubType
---@param randomFloat number
---@return boolean shouldMorph
local function should_morph_into_battery(variant, filter, randomFloat)
    if variant == PickupVariant.PICKUP_LIL_BATTERY then
        return false
    end

    return g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_WATCH_BATTERY) and (0.1 <= randomFloat and randomFloat < 0.2)
end

---@param variant PickupVariant
---@param filter NullPickupSubType
---@param randomFloat number
---@return PickupVariant newVariant
local function try_morph_pickup_variant(variant, filter, randomFloat)
    if should_morph_into_coin(variant, filter, randomFloat) then
        return PickupVariant.PICKUP_COIN
    end

    if should_morph_into_battery(variant, filter, randomFloat) then
        return PickupVariant.PICKUP_LIL_BATTERY
    end

    return variant
end

---@param seed integer
---@param filter NullPickupSubType
local function select_variant(seed, filter)
    local rng = RNG(seed, 7)
    local variantMorphFloat = rng:RandomFloat()
    local wop = WeightedOutcomePicker()

    for index, value in ipairs(s_VariantWeights) do
        if not s_VariantFilters[filter] or not s_VariantFilters[filter][value[1]] then
            wop:AddOutcomeWeight(value[1], value[2])
        end
    end

    local variant = Lib.WeightedOutcomePicker.PhantomPickOutcome(wop, seed, 35)
    local filterCopy = filter
    filter = 0 -- Good job guys

    local blockRNG = RNG(); blockRNG:SetSeed(seed, 47)
    if variant == PickupVariant.PICKUP_HEART and should_block_heart(blockRNG) then
        wop:ClearOutcomes()

        for index, value in ipairs(s_RetryVariantWeights) do
            if not s_VariantFilters[filter] or not s_VariantFilters[filter][value[1]] then
                wop:AddOutcomeWeight(value[1], value[2])
            end
        end

        variant = Lib.WeightedOutcomePicker.PhantomPickOutcome(wop, blockRNG:GetSeed(), 47)
    end

    return try_morph_pickup_variant(variant, filterCopy, variantMorphFloat)
end

--#endregion

--#region VariantModifiers

local function should_apply_little_baggy(card)
    if card < Card.CARD_NULL then
        return true
    end

    local cardConfig = g_ItemConfig:GetCard(card)
    if not cardConfig then
        return true
    end

    return cardConfig.CardType == ItemConfig.CARDTYPE_TAROT or cardConfig.CardType == ItemConfig.CARDTYPE_TAROT_REVERSE or
        cardConfig.CardType == ItemConfig.CARDTYPE_SUIT or cardConfig.CardType == ItemConfig.CARDTYPE_SPECIAL
end

---@param variant PickupVariant
---@param subType integer
---@return integer newVariant
---@return integer newSubType
local function apply_variant_modifiers(variant, subType)
    local starterDeck = g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_STARTER_DECK)
    local littleBaggy = g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_LITTLE_BAGGY)

    if starterDeck == littleBaggy then
        starterDeck = false
        littleBaggy = false
    end

    if variant == PickupVariant.PICKUP_PILL and starterDeck then
        return PickupVariant.PICKUP_TAROTCARD, 0
    end

    if variant == PickupVariant.PICKUP_TAROTCARD and littleBaggy and should_apply_little_baggy(subType) then
        return PickupVariant.PICKUP_PILL, 0
    end

    return variant, subType
end

--#endregion

--#region SelectSubType

---@class Switch.SelectSubTypeIO
---@field variant integer
---@field subType integer
---@field rng RNG
---@field advanceRNG boolean
---@field ignoreModifiers boolean
---@field room VirtualRoom

---@param io Switch.SelectSubTypeIO
local function pickup_variant_not_implemented(io)
    Isaac.DebugString(string.format("[warn] Pickup variant %d not implemented yet!", io.variant))
end

---@param rng RNG
---@return boolean success
local function eternal_heart_retry(rng)
    local bibleTract = g_PlayerManager.GetTotalTrinketMultiplier(TrinketType.TRINKET_BIBLE_TRACT)
    if bibleTract > 0 and rng:RandomInt(30 / bibleTract) == 0 then
        return true
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_1) and rng:RandomInt(40) == 0 then
        return true
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_KEY_PIECE_2) and rng:RandomInt(40) == 0 then
        return true
    end

    return false
end

---@param rng RNG
---@return boolean success
local function soul_heart_retry(rng)
    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_MITRE) and rng:RandomInt(3) == 0 then
        return true
    end

    local momsPearl = g_PlayerManager.GetTotalTrinketMultiplier(TrinketType.TRINKET_MOMS_PEARL)
    if momsPearl > 0 and rng:RandomInt(10 / momsPearl) == 0 then
        return true
    end

    if g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_EVE) and rng:RandomInt(10) == 0 then
        return true
    end

    return false
end

---@param rng RNG
---@return boolean success
local function black_heart_retry(rng)
    local blackLipstick = g_PlayerManager.GetTotalTrinketMultiplier(TrinketType.TRINKET_BLACK_LIPSTICK)
    if blackLipstick > 0 and rng:RandomInt(10 / blackLipstick) == 0 then
        return true
    end

    return false
end

---@param rng RNG
---@return HeartSubType heartType
local function get_random_soul_heart_sub_type(rng)
    local heartType = HeartSubType.HEART_SOUL

    if rng:RandomInt(4) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_HALF_SOUL) then
        heartType = HeartSubType.HEART_HALF_SOUL
    end

    if rng:RandomInt(20) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_BONE) then
        heartType = HeartSubType.HEART_BONE
    end

    if rng:RandomInt(20) == 0 or black_heart_retry(rng) then
        heartType = HeartSubType.HEART_BLACK
    end

    if rng:RandomInt(5) == 0 and (g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_THEFORGOTTEN) or g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_THESOUL)) then
        heartType = HeartSubType.HEART_BONE
    end

    return heartType
end

---@param io Switch.SelectSubTypeIO
local function select_heart(io)
    if io.subType ~= 0 then
        return
    end

    local rng = io.rng
    local heartType = HeartSubType.HEART_FULL

    if rng:RandomInt(2) == 0 then
        heartType = HeartSubType.HEART_HALF
    end

    local doubleHeartsChance = g_Game:IsHardMode() and 50 or 20
    if rng:RandomInt(doubleHeartsChance) == 0 then
        heartType = HeartSubType.HEART_DOUBLEPACK
    end

    if rng:RandomInt(50) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_ROTTEN) then
        heartType = HeartSubType.HEART_ROTTEN
    end

    if rng:RandomInt(100) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_SCARED) then
        heartType = HeartSubType.HEART_SCARED
    end

    if rng:RandomInt(100) == 0 then
        heartType = HeartSubType.HEART_BLENDED
    end

    if rng:RandomInt(50) == 0 or eternal_heart_retry(rng) then
        heartType = HeartSubType.HEART_ETERNAL
    end

    if rng:RandomInt(10) == 0 or soul_heart_retry(rng) then
        heartType = get_random_soul_heart_sub_type(rng)
    end

    if rng:RandomInt(160) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HEART, HeartSubType.HEART_GOLDEN) then
        heartType = HeartSubType.HEART_GOLDEN
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_DAEMONS_TAIL) and io.room.m_RoomType ~= RoomType.ROOM_SUPERSECRET then
        heartType = HeartSubType.HEART_BLACK
    end

    if io.room.m_RoomType == RoomType.ROOM_SUPERSECRET then
        heartType = Lib.Room.GetSuperSecretHeartType(io.room.m_RoomDescriptor.Data) or heartType
    elseif heartType == HeartSubType.HEART_HALF and g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_MOMS_LOCKET) then
        heartType = HeartSubType.HEART_FULL
    end

    io.subType = heartType
end

---@param rng RNG
---@return CoinSubType coinType
local function get_random_coin_sub_type(rng)
    local coinType = CoinSubType.COIN_PENNY

    if rng:RandomInt(20) == 0 then
        coinType = CoinSubType.COIN_NICKEL
    elseif rng:RandomInt(100) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_COIN, CoinSubType.COIN_STICKYNICKEL) then
        coinType = CoinSubType.COIN_STICKYNICKEL
    end

    if rng:RandomInt(100) == 0 then
        coinType = CoinSubType.COIN_DIME
    elseif rng:RandomInt(100) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_COIN, CoinSubType.COIN_LUCKYPENNY) then
        coinType = CoinSubType.COIN_LUCKYPENNY
    end

    if rng:RandomInt(200) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_COIN, CoinSubType.COIN_GOLDEN) then
        coinType = CoinSubType.COIN_GOLDEN
    end

    return coinType
end

---@param io Switch.SelectSubTypeIO
local function select_coin(io)
    if io.subType == 0 then
        io.subType = get_random_coin_sub_type(io.rng)
    end

    if io.subType == CoinSubType.COIN_NICKEL and false then -- April Fools Daily Challenge
        io.subType = CoinSubType.COIN_STICKYNICKEL
    end
end

---@param io Switch.SelectSubTypeIO
local function select_key(io)
    if io.subType ~= 0 then
        return
    end

    local rng = io.rng
    local wop = WeightedOutcomePicker()

    wop:AddOutcomeWeight(KeySubType.KEY_NORMAL, 49)
    wop:AddOutcomeWeight(KeySubType.KEY_GOLDEN, 1)
    local chargedKey = EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_KEY, KeySubType.KEY_CHARGED) and KeySubType.KEY_CHARGED or KeySubType.KEY_NORMAL
    wop:AddOutcomeWeight(chargedKey, 1)

    io.subType = Lib.WeightedOutcomePicker.PhantomPickOutcome(wop, rng:Next(), 35)
end

---@param io Switch.SelectSubTypeIO
local function select_bomb(io)
    if io.subType ~= 0 then
        return
    end

    local rng = io.rng
    local bombType = BombSubType.BOMB_NORMAL

    if rng:RandomInt(7) == 0 then
        bombType = BombSubType.BOMB_DOUBLEPACK
    end

    if rng:RandomInt(100) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_BOMB, BombSubType.BOMB_GOLDEN) then
        bombType = BombSubType.BOMB_GOLDEN
    end

    if rng:RandomInt(50) == 0 then
        bombType = bombType == BombSubType.BOMB_GOLDEN and BombSubType.BOMB_GOLDENTROLL or BombSubType.BOMB_SUPERTROLL
    end

    if rng:RandomInt(10) == 0 then
        bombType = bombType == BombSubType.BOMB_GOLDEN and BombSubType.BOMB_GOLDENTROLL or BombSubType.BOMB_TROLL
    end

    io.subType = bombType
end

local function select_grab_bag(io)
    if io.subType ~= 0 then
        return
    end

    local rng = io.rng
    local grabBagType = SackSubType.SACK_NORMAL

    if rng:RandomInt(100) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_GRAB_BAG, SackSubType.SACK_BLACK) then
        grabBagType = SackSubType.SACK_BLACK
    end

    io.subType = grabBagType
end

---@param io Switch.SelectSubTypeIO
local function post_process_chest(io)
    if io.subType ~= 0 then
        return
    end

    if io.variant == PickupVariant.PICKUP_MEGACHEST then
        io.subType = io.rng:RandomInt(4) + 1 + io.rng:RandomInt(4)
        return
    end

    if io.variant == PickupVariant.PICKUP_ETERNALCHEST then
        io.subType = 2
        return
    end

    io.subType = 1
end

---@param virtualRoom VirtualRoom
---@return boolean
local function can_spawn_haunted_chest(virtualRoom)
    local roomShape = virtualRoom.m_RoomDescriptor.Data.Shape
    return EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_HAUNTEDCHEST, 0) and roomShape ~= RoomShape.ROOMSHAPE_IH and roomShape ~= RoomShape.ROOMSHAPE_IV
        and roomShape ~= RoomShape.ROOMSHAPE_IIV and roomShape ~= RoomShape.ROOMSHAPE_IIH
end

---@param rng RNG
---@param virtualRoom VirtualRoom
---@return PickupVariant? chestVariant
local function get_random_chest_variant(rng, virtualRoom)
    if rng:RandomInt(40) == 0 then
        return PickupVariant.PICKUP_MIMICCHEST
    end

    if rng:RandomInt(20) == 0 then
        return PickupVariant.PICKUP_REDCHEST
    end

    if rng:RandomInt(50) == 0 then
        return PickupVariant.PICKUP_BOMBCHEST
    end

    if rng:RandomInt(80) == 0 then
        return PickupVariant.PICKUP_SPIKEDCHEST
    end

    if rng:RandomInt(100) == 0 then
        return PickupVariant.PICKUP_GRAB_BAG
    end

    if rng:RandomInt(80) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_WOODENCHEST, 0) then
        return PickupVariant.PICKUP_WOODENCHEST
    end

    if rng:RandomInt(40) == 0 and can_spawn_haunted_chest(virtualRoom) then
        return PickupVariant.PICKUP_HAUNTEDCHEST
    end
end

---@param rng RNG
---@param variant PickupVariant
---@return PickupVariant chestVariant
local function get_random_locked_chest_variant(variant, rng)
    if variant == PickupVariant.PICKUP_MEGACHEST then
        return PickupVariant.PICKUP_MEGACHEST
    end

    if not g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_GILDED_KEY) or g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_LEFT_HAND) then
        if variant ~= PickupVariant.PICKUP_LOCKEDCHEST then
            return variant
        end
    end

    variant = PickupVariant.PICKUP_LOCKEDCHEST
    if rng:RandomInt(120) and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_MEGACHEST, 0) then
        variant = PickupVariant.PICKUP_MEGACHEST
    end

    return variant
end

---@param io Switch.SelectSubTypeIO
local function select_special_chest(io)
    if io.variant == PickupVariant.PICKUP_SPIKEDCHEST and g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_FLAT_FILE) then
        io.variant = PickupVariant.PICKUP_MIMICCHEST
    end

    if io.subType ~= 0 then
        return
    end

    if g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_LEFT_HAND) then
        io.variant = PickupVariant.PICKUP_REDCHEST
    end

    if io.variant ~= PickupVariant.PICKUP_MEGACHEST then
        io.variant = get_random_locked_chest_variant(io.variant, io.rng)
    end

    post_process_chest(io)
end

---@param io Switch.SelectSubTypeIO
local function select_locked_chest(io)
    if io.subType ~= 0 then
        return
    end

    local rng = io.rng

    if rng:RandomInt(1600) == 0 then
        io.variant = PickupVariant.PICKUP_ETERNALCHEST
    end

    select_special_chest(io)
    post_process_chest(io)
end

---@param io Switch.SelectSubTypeIO
local function select_chest(io)
    if io.subType ~= 0 then
        return
    end

    io.variant = get_random_chest_variant(io.rng, io.room) or io.variant

    if io.variant == PickupVariant.PICKUP_GRAB_BAG then
        select_grab_bag(io)
        return
    end

    select_locked_chest(io)
    post_process_chest(io)
end

---@param rng RNG
---@return BatterySubType? batteryType
local function get_random_battery_sub_type(rng)
    if rng:RandomInt(100) == 0 then
        return BatterySubType.BATTERY_MEGA
    end

    if rng:RandomInt(120) == 0 and EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_GOLDEN) then
        return BatterySubType.BATTERY_GOLDEN
    end
end

---@param io Switch.SelectSubTypeIO
local function select_battery(io)
    if io.subType ~= 0 then
        return
    end

    local rng = io.rng
    local batteryType = BatterySubType.BATTERY_NORMAL

    local microSeed = rng:Next()
    local hardMicroSeed = rng:Next()

    if EntityRedirection.IsBasePickupAvailable(PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_MICRO) and (microSeed % 3 ~= 0 or (g_Game:IsHardMode() and hardMicroSeed % 2 ~= 0)) then
        batteryType = BatterySubType.BATTERY_MICRO
    end

    io.subType = get_random_battery_sub_type(rng) or batteryType
end

---@param collectible CollectibleType | integer
---@param ignoreModifiers boolean
---@return boolean randomize
local function should_forcibly_randomize_collectible(collectible, ignoreModifiers)
    if collectible == 0 then
        return true
    end

    if not g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_TMTRAINER) or ignoreModifiers then
        return false
    end

    return not Lib.ItemConfig.IsQuestItem(g_ItemConfig, collectible)
end

---@param io Switch.SelectSubTypeIO
local function select_collectible(io)
    if io.subType ~= 0 and not should_forcibly_randomize_collectible(io.subType, io.ignoreModifiers) then
        return
    end

    io.subType = VirtualRoomQueries.GetSeededCollectible(io.room, io.rng:Next(), not io.advanceRNG)
end

---@param io Switch.SelectSubTypeIO
local function select_card(io)
    if io.subType ~= 0 then
        return
    end

    local card = g_ItemPool:GetCardEx(io.rng:Next(), 25, 10, 10, true)
    local rng = RNG(); rng:SetSeed(io.rng:Next(), 35)
    card = Isaac.RunCallback(ModCallbacks.MC_GET_CARD, card, rng, true, true, false) or card
    io.subType = card
end

---@param io Switch.SelectSubTypeIO
local function select_pill(io)
    if io.subType ~= 0 then
        return
    end

    local pill = g_ItemPool:GetPill(io.rng:Next())
    io.subType = pill
end

---@param io Switch.SelectSubTypeIO
local function select_trinket(io)
    if io.subType ~= 0 then
        return
    end

    io.subType = g_ItemPool:GetTrinket(not io.advanceRNG)
    if io.subType ~= TrinketType.TRINKET_NULL then
        return
    end

    io.variant = PickupVariant.PICKUP_TAROTCARD
    io.subType = 0
    select_card(io)

    if not g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_LITTLE_BAGGY) or g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_STARTER_DECK) then
        return
    end

    io.variant = PickupVariant.PICKUP_PILL
    io.subType = 0
    select_pill(io)
end

---@param io Switch.SelectSubTypeIO
local function init_broken_shovel(io)
    io.subType = 550
end

local switch_SelectSubType = {
    [PickupVariant.PICKUP_HEART] = select_heart,
    [PickupVariant.PICKUP_COIN] = select_coin,
    [PickupVariant.PICKUP_KEY] = select_key,
    [PickupVariant.PICKUP_BOMB] = select_bomb,
    [PickupVariant.PICKUP_CHEST] = select_chest,
    [PickupVariant.PICKUP_LOCKEDCHEST] = select_locked_chest,
    [PickupVariant.PICKUP_BOMBCHEST] = select_special_chest,
    [PickupVariant.PICKUP_SPIKEDCHEST] = select_special_chest,
    [PickupVariant.PICKUP_ETERNALCHEST] = select_special_chest,
    [PickupVariant.PICKUP_MIMICCHEST] = select_special_chest,
    [PickupVariant.PICKUP_WOODENCHEST] = select_special_chest,
    [PickupVariant.PICKUP_HAUNTEDCHEST] = select_special_chest,
    [PickupVariant.PICKUP_MEGACHEST] = post_process_chest,
    [PickupVariant.PICKUP_OLDCHEST] = post_process_chest,
    [PickupVariant.PICKUP_REDCHEST] = post_process_chest,
    [PickupVariant.PICKUP_MOMSCHEST] = post_process_chest,
    [PickupVariant.PICKUP_GRAB_BAG] = select_grab_bag,
    [PickupVariant.PICKUP_LIL_BATTERY] = select_battery,
    [PickupVariant.PICKUP_COLLECTIBLE] = select_collectible,
    [PickupVariant.PICKUP_TRINKET] = select_trinket,
    [PickupVariant.PICKUP_TAROTCARD] = select_card,
    [PickupVariant.PICKUP_PILL] = select_pill,
    [PickupVariant.PICKUP_THROWABLEBOMB] = switch_break,
    [PickupVariant.PICKUP_POOP] = switch_break,
    [PickupVariant.PICKUP_SHOPITEM] = switch_break,
    [PickupVariant.PICKUP_BIGCHEST] = switch_break,
    [PickupVariant.PICKUP_TROPHY] = switch_break,
    [PickupVariant.PICKUP_BED] = switch_break,
    [PickupVariant.PICKUP_BROKEN_SHOVEL] = init_broken_shovel,
    default = pickup_variant_not_implemented,
}

---@param variant PickupVariant
---@param subType integer
---@param rng RNG
---@param advanceRNG boolean
---@param ignoreModifiers boolean
---@param virtualRoom VirtualRoom
---@return integer newVariant
---@return integer newSubType
local function select_subtype(variant, subType, rng, advanceRNG, ignoreModifiers, virtualRoom)
    ---@type Switch.SelectSubTypeIO
    local io = {
        variant = variant,
        subType = subType,
        rng = rng,
        advanceRNG = advanceRNG,
        ignoreModifiers = ignoreModifiers,
        room = virtualRoom,
    }

    local switch = switch_SelectSubType[variant] or switch_SelectSubType.default
    switch(io)

    return io.variant, io.subType
end

--#endregion

--#region PostSelectionModifiers

---@param variant PickupVariant
---@param seed integer
---@return boolean
local function should_try_double_pack(variant, seed)
    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_HUMBLEING_BUNDLE) and (seed & 0x8000) == 0 then -- A very specific RandomInt(2)
        return true
    end

    if variant == PickupVariant.PICKUP_BOMB and g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BOGO_BOMBS) then
        return true
    end

    return false
end

local s_DoublePacks = {
    [PickupVariant.PICKUP_HEART] = {
        [HeartSubType.HEART_FULL] = HeartSubType.HEART_DOUBLEPACK,
        [HeartSubType.HEART_SCARED] = HeartSubType.HEART_DOUBLEPACK,
    },
    [PickupVariant.PICKUP_COIN] = {
        [CoinSubType.COIN_PENNY] = CoinSubType.COIN_DOUBLEPACK,
    },
    [PickupVariant.PICKUP_KEY] = {
        [KeySubType.KEY_NORMAL] = KeySubType.KEY_DOUBLEPACK,
    },
    [PickupVariant.PICKUP_BOMB] = {
        [BombSubType.BOMB_NORMAL] = BombSubType.BOMB_DOUBLEPACK,
    },
}

---@param variant PickupVariant
---@param subType integer
---@return integer? doublePackSubType
local function get_double_pack(variant, subType)
    return s_DoublePacks[variant] and s_DoublePacks[variant][subType]
end

local s_HaveAHeartBannedHearts = Lib.Table.CreateDictionary({HeartSubType.HEART_FULL, HeartSubType.HEART_HALF, HeartSubType.HEART_DOUBLEPACK, HeartSubType.HEART_SCARED, HeartSubType.HEART_BLENDED, HeartSubType.HEART_ROTTEN})

---@param variant PickupVariant
---@param subType integer
---@return PickupVariant newVariant
---@return integer newSubType
local function apply_have_a_heart_selection_modifier(variant, subType)
    if variant == PickupVariant.PICKUP_HEART and s_HaveAHeartBannedHearts[subType] then
        subType = subType == HeartSubType.HEART_FULL and CoinSubType.COIN_DOUBLEPACK or (subType == HeartSubType.HEART_DOUBLEPACK and CoinSubType.COIN_NICKEL or CoinSubType.COIN_PENNY)
        return PickupVariant.PICKUP_COIN, subType
    end

    return variant, subType
end

---@param variant PickupVariant
---@param subType integer
---@return PickupVariant newVariant
---@return integer newSubType
local function apply_pica_run_selection_modifier(variant, subType, advanceRNG)
    if variant == PickupVariant.PICKUP_COLLECTIBLE then
        local io = {variant = variant, subType = subType, advanceRNG = advanceRNG}
        select_trinket(io)
        return io.variant, io.subType
    end

    return variant, subType
end

---@param variant PickupVariant
---@param subType integer
---@return PickupVariant newVariant
---@return integer newSubType
local function apply_cantripped_selection_modifier(variant, subType, ignoreModifiers)
    if not ignoreModifiers and variant == PickupVariant.PICKUP_COLLECTIBLE and not Lib.ItemConfig.IsQuestItem(g_ItemConfig, subType) then
        variant = PickupVariant.PICKUP_TAROTCARD
        subType = 0
    end

    if variant == PickupVariant.PICKUP_TAROTCARD and (subType & 0x8000) == 0 then
        variant = PickupVariant.PICKUP_TAROTCARD
        subType = 0
    end

    if variant == PickupVariant.PICKUP_PILL or variant == PickupVariant.PICKUP_LIL_BATTERY then
        variant = PickupVariant.PICKUP_TAROTCARD
    end

    return variant, subType
end

---@param variant PickupVariant
---@param subType integer
---@param rng RNG
---@param advanceRNG boolean
---@param shopItem boolean
---@param ignoreModifiers boolean
---@param virtualRoom VirtualRoom
---@return PickupVariant? newVariant
---@return integer? newSubType
local function apply_nuh_uh_selection_modifier(variant, subType, rng, advanceRNG, shopItem, ignoreModifiers, virtualRoom)
    if variant ~= PickupVariant.PICKUP_COIN or variant ~= PickupVariant.PICKUP_KEY then
        return variant, subType
    end

    if g_Game:IsGreedMode() or g_Level:GetStage() <= LevelStage.STAGE3_2 then
        return variant, subType
    end

    local wop = WeightedOutcomePicker()
    if variant == PickupVariant.PICKUP_COIN then
        wop:AddOutcomeWeight(PickupVariant.PICKUP_NULL, 8)
    end

    wop:AddOutcomeWeight(PickupVariant.PICKUP_BOMB, 8)
    wop:AddOutcomeWeight(PickupVariant.PICKUP_HEART, 8)
    wop:AddOutcomeWeight(PickupVariant.PICKUP_PILL, 5)
    wop:AddOutcomeWeight(PickupVariant.PICKUP_TAROTCARD, 5)
    wop:AddOutcomeWeight(PickupVariant.PICKUP_TRINKET, 2)
    wop:AddOutcomeWeight(PickupVariant.PICKUP_LIL_BATTERY, 2)

    local newVariant = Lib.WeightedOutcomePicker.PhantomPickOutcome(wop, rng:Next(), 35)

    if newVariant == PickupVariant.PICKUP_NULL and not shopItem then
        return nil, nil -- The original returns -1 here and makes the SelectPickupType function fail
    end

    return PickupInitializer.select_pickup_type(rng:Next(), newVariant, 0, advanceRNG, shopItem, ignoreModifiers, virtualRoom)
end

---@param seed integer
---@param variant PickupVariant
---@param subType integer
---@param rng RNG
---@param advanceRNG boolean
---@param shopItem boolean
---@param ignoreModifiers boolean
---@param recursiveCount integer
---@param virtualRoom VirtualRoom
---@return integer? newVariant
---@return integer? newSubType
local function apply_post_selection_modifiers(seed, variant, subType, rng, advanceRNG, shopItem, ignoreModifiers, recursiveCount, virtualRoom)
    if should_try_double_pack(variant, seed) and not ignoreModifiers then
        subType = get_double_pack(variant, subType) or subType
    end

    if g_Game.Challenge == Challenge.CHALLENGE_HAVE_A_HEART then
        variant, subType = apply_have_a_heart_selection_modifier(variant, subType)
    end

    if not ignoreModifiers and g_Game.Challenge == Challenge.CHALLENGE_PICA_RUN then
        variant, subType = apply_pica_run_selection_modifier(variant, subType, advanceRNG)
    end

    if g_Game.Challenge == Challenge.CHALLENGE_CANTRIPPED then
        variant, subType = apply_cantripped_selection_modifier(variant, subType, ignoreModifiers)
    end

    if variant == PickupVariant.PICKUP_BOMB and Lib.PlayerManager.AllPlayersType(g_PlayerManager, {PlayerType.PLAYER_BLUEBABY_B}) then
        if subType ~= BombSubType.BOMB_TROLL and subType ~= BombSubType.BOMB_SUPERTROLL and subType ~= BombSubType.BOMB_GOLDENTROLL then
            variant = PickupVariant.PICKUP_POOP
            subType = PoopPickupSubType.POOP_BIG
        end
    end

    if not ignoreModifiers and recursiveCount < 2 and g_PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_NUH_UH) then
        local nuhUhVariant, nuhUhSubType = apply_nuh_uh_selection_modifier(variant, subType, rng, advanceRNG, shopItem, ignoreModifiers, virtualRoom)
        if not nuhUhVariant or not nuhUhSubType then
            return nil, nil
        end

        variant = nuhUhVariant
        subType = nuhUhSubType
    end

    if shopItem and variant == PickupVariant.PICKUP_HEART and Lib.PlayerManager.AllPlayersType(g_PlayerManager, {PlayerType.PLAYER_KEEPER, PlayerType.PLAYER_KEEPER_B}) then
        variant = rng:RandomInt(2) == 0 and PickupVariant.PICKUP_KEY or PickupVariant.PICKUP_BOMB
        subType = 1
    end

    return variant, subType
end

--#endregion

local s_SelectPickupTypeRecursiveCount = 0

---@param seed integer
---@param variant PickupVariant | integer
---@param subType integer
---@param advanceRNG boolean
---@param shopItem boolean
---@param ignoreModifiers boolean
---@param virtualRoom VirtualRoom
---@return PickupVariant | integer | nil newVariant
---@return integer? newSubType
local function select_pickup_type(seed, variant, subType, advanceRNG, shopItem, ignoreModifiers, virtualRoom)
    s_SelectPickupTypeRecursiveCount = s_SelectPickupTypeRecursiveCount + 1
    local rng = RNG(); rng:SetSeed(seed, 35)

    if variant == PickupVariant.PICKUP_NULL then
        variant = select_variant(rng:Next(), subType)
        subType = 0
    end

    variant, subType = apply_variant_modifiers(variant, subType)
    variant, subType = select_subtype(variant, subType, rng, advanceRNG, ignoreModifiers, virtualRoom)
    local newVariant, newSubType = apply_post_selection_modifiers(seed, variant, subType, rng, advanceRNG, shopItem, ignoreModifiers, s_SelectPickupTypeRecursiveCount, virtualRoom)

    s_SelectPickupTypeRecursiveCount = s_SelectPickupTypeRecursiveCount - 1
    return newVariant, newSubType
end

--#region Modifiers

---@seed integer
---@return boolean
local function should_do_wait_what_morph(seed)
    if not g_PersistentGameData:IsItemInCollection(CollectibleType.COLLECTIBLE_BUTTER_BEAN) then
        return false
    end

    local rng = RNG(seed, 77)
    return rng:RandomInt(20) == 0
end

---@return integer
local function get_base_cycle_num()
    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_GLITCHED_CROWN) then
        return 4
    end

    if g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_ISAAC_B) or g_PlayerManager.AnyPlayerTypeHasBirthright(PlayerType.PLAYER_ISAAC) then
        return 1
    end

    return 0
end

---@param seed integer
---@return CollectibleType | integer
local function get_random_food_collectible(seed)
---@diagnostic disable-next-line: param-type-mismatch
    local foodItems = g_ItemConfig:GetTaggedItems(ItemConfig.TAG_FOOD)

    local pool = {}
    for index, value in ipairs(foodItems) do
        if value:IsCollectible() then
            table.insert(pool, value.ID)
        end
    end

    local itemCount = #pool
    if itemCount == 0 then
        return CollectibleType.COLLECTIBLE_BREAKFAST
    end

    local rng = RNG(seed, 9)
    return pool[rng:RandomInt(itemCount) + 1]
end

---@param virtualRoom VirtualRoom
---@param baseCycleSeed integer
---@param bingeEaterSeed integer
---@return CollectibleType[]
local function build_collectible_cycle(virtualRoom, baseCycleSeed, bingeEaterSeed)
    local cycles = {}
    local rng = RNG(baseCycleSeed, 38)

    local cycleNum = get_base_cycle_num()

    -- There should be another check for CanReroll here (most likely because the function was split into multiple smaller functions)
    for i = 1, cycleNum, 1 do
        table.insert(cycles, VirtualRoomQueries.GetSeededCollectible(virtualRoom, rng:Next(), false))
    end

    if g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_BINGE_EATER) then
        table.insert(cycles, get_random_food_collectible(bingeEaterSeed))
    end

    return cycles
end

---@param virtualRoom VirtualRoom
---@param seed integer
---@return boolean
local function should_glitch_collectible(virtualRoom, seed)
    if VirtualRoomQueries.GetFrameCount(virtualRoom) >= 2 or not g_PersistentGameData:Unlocked(Achievement.CORRUPTED_DATA) then
        return false
    end

    if virtualRoom.m_RoomType == RoomType.ROOM_ERROR then
        local rng = RNG(seed, 11)
        return rng:RandomInt(16) == 0
    end

    if virtualRoom.m_RoomType == RoomType.ROOM_SECRET then
        local rng = RNG(seed, 11)
        return rng:RandomInt(60) == 0
    end

    return false
end

---@param virtualPickup VirtualPickup
---@param virtualRoom VirtualRoom
---@return boolean
local function should_force_price(virtualPickup, virtualRoom)
    if g_Seeds:HasSeedEffect(SeedEffect.SEED_ITEMS_COST_MONEY) and not Lib.EntityPickup.IsChest(virtualPickup.Variant) then
        return true
    end

    if ShouldIgnoreModifiers() then
        return false
    end

    if not g_PlayerManager.AnyoneIsPlayerType(PlayerType.PLAYER_KEEPER_B) or virtualPickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        return false
    end

    if virtualPickup.Price ~= 0 or virtualRoom.m_IsInitialized or Lib.ItemConfig.IsQuestItem(g_ItemConfig, virtualPickup.SubType) then
        return false
    end

    return true
end

--#endregion

--#region Init

---@param shop VirtualShop
---@param variant PickupVariant | integer
---@param subtype integer
---@param shopItemId integer
---@return integer|PickupPrice
local function GetShopItemPrice(shop, variant, subtype, shopItemId)
    local price = Shop.GetShopItemPrice(shop, variant, subtype, shopItemId)
    price = Shop.TryGetShopDiscount(shop, shopItemId, price)
    return price
end

---@param virtualPickup VirtualPickup
---@param virtualRoom VirtualRoom
---@param seed integer
---@return ShopItemData
local function make_shop_item(virtualPickup, virtualRoom, seed)
    local advanceRNG = false

    local shopItemData = Shop.MakeShopItem(virtualRoom.m_Shop, seed)
    local shopVariant, shopSubtype = select_pickup_type(seed, shopItemData.variant, shopItemData.subtype, advanceRNG, true, ShouldIgnoreModifiers(), virtualRoom)
    if not ((shopVariant and shopVariant ~= shopItemData.variant) or (shopSubtype and shopSubtype ~= shopItemData.subtype)) then
        return shopItemData
    end

    ---@cast shopVariant integer
    ---@cast shopSubtype integer
    shopItemData.variant = shopVariant
    shopItemData.subtype = shopSubtype
    shopItemData.price = GetShopItemPrice(virtualRoom.m_Shop, shopItemData.variant, shopItemData.subtype, virtualPickup.ShopItemId)
    return shopItemData
end

---@param virtualEntity VirtualPickup
---@param entityType EntityType | integer
---@param variant integer
---@param subtype integer
---@param seed integer
local function init_virtual_entity(virtualEntity, entityType, variant, subtype, seed)
    virtualEntity.m_Type = entityType
    virtualEntity.Variant = variant
    virtualEntity.SubType = subtype
    virtualEntity.InitSeed = seed
    virtualEntity.m_DropRNG = RNG(seed, 30)
end

---@param virtualPickup VirtualPickup
---@param entityType EntityType
---@param variant PickupVariant
---@param subtype integer
---@param seed integer
---@param virtualRoom VirtualRoom
---@return boolean
local function InitVirtualPickup(virtualPickup, entityType, variant, subtype, seed, virtualRoom)
    virtualPickup.m_Room = virtualRoom
    virtualPickup.m_OptionsCycles = {}
    virtualPickup.m_FlipCollectible = nil

    local rng = RNG(seed, 35)

    local advanceRNG = false
    local selectedVariant, selectedSubtype = select_pickup_type(seed, variant, subtype, advanceRNG, false, ShouldIgnoreModifiers(), virtualRoom)
    if not selectedVariant then
        return false -- In this specific instance a fly is spawned and the pickup is removed
    end

    if selectedVariant == PickupVariant.PICKUP_SHOPITEM then
        local shopItem = make_shop_item(virtualPickup, virtualRoom, rng:Next())
        selectedVariant = shopItem.variant
        selectedSubtype = shopItem.subtype
        virtualPickup.ShopItemId = shopItem.shopItemIdx
        virtualPickup.Price = shopItem.price
    end

    ---@cast selectedVariant integer | PickupVariant
    ---@cast selectedSubtype integer

    if selectedVariant == PickupVariant.PICKUP_COLLECTIBLE then
        local collectibleConfig = g_ItemConfig:GetCollectible(selectedSubtype)
        if not collectibleConfig then
            selectedSubtype = VirtualRoomQueries.GetSeededCollectible(virtualRoom, seed, false)
        end

        if not ShouldIgnoreModifiers() and selectedSubtype == CollectibleType.COLLECTIBLE_BUTTER_BEAN and should_do_wait_what_morph(g_Seeds:GetStartSeed()) then
            selectedSubtype = CollectibleType.COLLECTIBLE_WAIT_WHAT
        end
    end

    selectedVariant, selectedSubtype = CustomCallbacks.RunPostPickupSelection(virtualPickup, selectedVariant, selectedSubtype, variant, subtype, seed)

    if selectedVariant == PickupVariant.PICKUP_BOMB and not (selectedSubtype == BombSubType.BOMB_TROLL or selectedSubtype == BombSubType.BOMB_SUPERTROLL) and Lib.PlayerManager.AllPlayersType(g_PlayerManager, {PlayerType.PLAYER_BLUEBABY_B}) then
        selectedVariant = PickupVariant.PICKUP_POOP
        selectedSubtype = 1
    end

    init_virtual_entity(virtualPickup, entityType, selectedVariant, selectedSubtype, seed)

    if virtualPickup.Variant == PickupVariant.PICKUP_COLLECTIBLE then
        if not ShouldIgnoreModifiers() and virtualPickup.Price == 0 and g_PlayerManager.AnyoneHasCollectible(CollectibleType.COLLECTIBLE_DAMOCLES_PASSIVE) then
            virtualPickup.m_Flags = virtualPickup.m_Flags | EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE
            virtualRoom.m_DamoclesItemSpawned = true
        end

        if not ShouldIgnoreModifiers() and Lib.EntityPickup.CanReroll(virtualPickup.Variant, virtualPickup.SubType) then
            virtualPickup.m_OptionsCycles = build_collectible_cycle(virtualRoom, virtualPickup.m_DropRNG:GetSeed(), seed)

            if should_glitch_collectible(virtualRoom, seed) then
                virtualPickup.m_Flags = virtualPickup.m_Flags | EntityFlag.FLAG_GLITCH
            end
        end
    end

    if should_force_price(virtualPickup, virtualRoom) then
        virtualPickup.ShopItemId = -1
        virtualPickup.Price = GetShopItemPrice(virtualRoom.m_Shop, virtualPickup.Variant, virtualPickup.SubType, virtualPickup.ShopItemId)
    end

    if virtualPickup.Variant == PickupVariant.PICKUP_HEART and g_Game.Challenge == Challenge.CHALLENGE_ULTRA_HARD then
        return false
    end

    CustomCallbacks.RunPostPickupInit(virtualPickup)
    if virtualPickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and (virtualPickup.m_Flags & EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE) ~= 0 then
        table.insert(virtualRoom.m_DamoclesItems, virtualPickup)
    end
    return true
end

--#endregion

--#region Module

PickupInitializer.CreateVirtualPickup = CreateVirtualPickup
PickupInitializer.InitVirtualPickup = InitVirtualPickup
PickupInitializer.ShouldIgnoreModifiers = ShouldIgnoreModifiers
PickupInitializer.BeginIgnoreModifiers = BeginIgnoreModifiers
PickupInitializer.EndIgnoreModifiers = EndIgnoreModifiers
PickupInitializer.GetShopItemPrice = GetShopItemPrice
PickupInitializer.select_pickup_type = select_pickup_type
PickupInitializer.should_do_wait_what_morph = should_do_wait_what_morph
PickupInitializer.build_collectible_cycle = build_collectible_cycle
PickupInitializer.should_glitch_collectible = should_glitch_collectible
PickupInitializer.should_force_price = should_force_price

if DATAMINER_DEBUG_MODE then
    PickupInitializer.count_active_virtual_pickups = count_active_virtual_pickups
end

--#endregion

return PickupInitializer