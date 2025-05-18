---@class Lib.RNG
local Lib_RNG = {}

---@generic V
---@param array V[]
---@param rng RNG
---@param startIdx integer?
---@param endIdx integer?
local function RandomShuffle(array, rng, startIdx, endIdx)
    startIdx = startIdx or 1
    endIdx = endIdx or #array

    if startIdx >= endIdx then
        return
    end

    for i = endIdx, startIdx + 1, -1 do
        local count = i - startIdx + 1
        local randomIndex = rng:RandomInt(count)
        local j = startIdx + randomIndex
        array[i], array[j] = array[j], array[i] -- Swap
    end
end

--#region Module

Lib_RNG.RandomShuffle = RandomShuffle

--#endregion

return Lib_RNG