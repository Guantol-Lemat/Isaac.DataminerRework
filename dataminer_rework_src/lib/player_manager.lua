---@class Lib.PlayerManager
local Lib_PlayerManager = {}

---@param playerManager PlayerManager
---@param collectible CollectibleType | integer
---@return {[1]: EntityPlayer?, [2]: integer?}
local function RandomCollectibleOwner(playerManager, collectible, seed)
    local rng = RNG(seed, 22)
    local score = -1.0
    local randomPlayer = nil
    local collectibleRNG = nil

    for index, player in ipairs(playerManager.GetPlayers()) do
        if player.Variant ~= 0 or player:HasCollectible(collectible, false) then
            goto continue
        end

        local randomFloat = rng:RandomFloat()
        if randomFloat > score then
            randomPlayer = player
            score = randomFloat
        end
        ::continue::
    end

    if randomPlayer then
        collectibleRNG = randomPlayer:GetCollectibleRNG(collectible)
    end

    return {randomPlayer, collectibleRNG}
end

--#region Module

Lib_PlayerManager.RandomCollectibleOwner = RandomCollectibleOwner

--#endregion

return Lib_PlayerManager