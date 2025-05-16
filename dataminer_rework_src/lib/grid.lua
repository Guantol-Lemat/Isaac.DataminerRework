---@class Lib.Grid
local Lib_Grid = {}

---@param gridIdx integer
---@param gridWidth integer
---@return Vector coordinates
local function GetCoordinatedFromGridIdx(gridIdx, gridWidth)
    local x = gridIdx % gridWidth
    local y = gridIdx / gridWidth
    return Vector(x, y)
end

---@param coordinates Vector
---@param gridWidth integer
---@return integer
local function GetGridIdxFromCoordinates(coordinates, gridWidth)
    return coordinates.X * gridWidth + coordinates.Y
end

---@param coordinates Vector
---@param other Vector
---@return number
local function ManhattanDistance(coordinates, other)
    local distance = coordinates - other
    distance.X = math.abs(distance.X)
    distance.Y = math.abs(distance.Y)
    return distance.X + distance.Y
end

--#region

Lib_Grid.GetCoordinatesFromGridIdx = GetCoordinatedFromGridIdx
Lib_Grid.GetGridIdxFromCoordinates = GetGridIdxFromCoordinates
Lib_Grid.ManhattanDistance = ManhattanDistance

--#endregion

return Lib_Grid