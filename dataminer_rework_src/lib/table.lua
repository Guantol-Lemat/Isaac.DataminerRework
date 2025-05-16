---@class Lib.Table
local Lib_Table = {}

---@param tbl table
---@return table dictionary
local function CreateDictionary(tbl)
    local dictionary = {}
    for _, value in ipairs(tbl) do
        dictionary[value] = true
    end

    return dictionary
end

--#region Module

Lib_Table.CreateDictionary = CreateDictionary

--#endregion

return Lib_Table