---@class Lib.Math
local Lib_Math = {}

---@param value number
---@param min number
---@param max number
---@return number clampedValue
local function Clamp(value, min, max)
    return math.max(math.min(value, max),  min)
end

--#region Module

Lib_Math.Clamp = Clamp

--#endregion

return Lib_Math