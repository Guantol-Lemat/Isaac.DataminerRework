local LayoutData = require("datamine_bubble.layout_data")
local CollectibleSpriteUtils = require("datamine_bubble.sprites.collectible_sprite")
local BossSpriteUtils = require("datamine_bubble.sprites.boss_sprite")
local MinibossSpriteUtils = require("datamine_bubble.sprites.miniboss_sprite")

local VANILLA_ANM2_COLLECTIBLE = "gfx/dataminer_rework/dataminer_bubble/collectibles.anm2"
local VANILLA_ANM2_BOSS = "gfx/dataminer_rework/dataminer_bubble/bosses.anm2"
local VANILLA_ANM2_MINIBOSS = "gfx/dataminer_rework/dataminer_bubble/minibosses.anm2"

local GLITCHED_ITEM_ID = -1
local BOSS_NULL = 0
local NUM_BOSSES = 104
local NUM_MINIBOSSES = 16

LayoutData.InitLayoutData()

for i = CollectibleType.COLLECTIBLE_NULL, CollectibleType.NUM_COLLECTIBLES - 1, 1 do
    CollectibleSpriteUtils.AddCollectibleSpriteData(i, VANILLA_ANM2_COLLECTIBLE, i)
end

---@diagnostic disable-next-line: param-type-mismatch
CollectibleSpriteUtils.AddCollectibleSpriteData(GLITCHED_ITEM_ID, VANILLA_ANM2_COLLECTIBLE, CollectibleType.NUM_COLLECTIBLES)

for i = BOSS_NULL, NUM_BOSSES, 1 do
    BossSpriteUtils.AddBossSpriteData(i, VANILLA_ANM2_BOSS, i)
end

for i = 0, NUM_MINIBOSSES, 1 do
    MinibossSpriteUtils.AddMinibossSpriteData(i, VANILLA_ANM2_MINIBOSS, i)
end