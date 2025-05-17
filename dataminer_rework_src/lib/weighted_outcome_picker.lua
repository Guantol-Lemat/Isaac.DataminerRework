---@class Lib.WeightedOutcomePicker
local Lib_Wop = {}

---@param wop WeightedOutcomePicker
---@param seed integer
---@param shiftIdx integer
---@return integer outcome
local function PhantomPickOutcome(wop, seed, shiftIdx)
    local rng = RNG(seed, shiftIdx)
    return wop:PickOutcome(rng)
end

--#region Module

Lib_Wop.PhantomPickOutcome = PhantomPickOutcome

--#endregion

return Lib_Wop