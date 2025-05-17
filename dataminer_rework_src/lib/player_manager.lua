---@class Lib.PlayerManager
local Lib_PlayerManager = {}

--#region Dependencies

local g_Game = Game()

--#endregion

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

---@param playerType PlayerType | integer
---@param allowedTypes PlayerType[] | integer[]
local function is_any_player_type(playerType, allowedTypes)
    for index, value in ipairs(allowedTypes) do
        if playerType == value then
            return true
        end
    end

    return false
end

---@param playerManager PlayerManager
---@param playerTypes PlayerType[] | integer[]
---@return boolean allPlayersType
local function AllPlayersType(playerManager, playerTypes)
    for index, player in ipairs(playerManager.GetPlayers()) do
        if player.Variant == 0 and not player:IsCoopGhost() and not is_any_player_type(player:GetPlayerType(), playerTypes) then
            return false
        end
    end

    return true
end

--#region Module

Lib_PlayerManager.RandomCollectibleOwner = RandomCollectibleOwner
Lib_PlayerManager.AllPlayersType = AllPlayersType

--#endregion

return Lib_PlayerManager