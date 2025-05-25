---@class Lib.StringTable
local Lib_StringTable = {}

local Lib = {
    Table = require("lib.table")
}

local s_InvalidStrings = Lib.Table.CreateDictionary({
    "StringTable::InvalidLanguage", "StringTable::InvalidCategory",
    "StringTable::InvalidKey", "StringTable::UntranslatedString",
})

---@param category string
---@param key string
---@param language Language
---@return string?
local function GetLocalizedString(category, key, language)
    local localizedString = Isaac.GetLocalizedString(category, key, language)
    if s_InvalidStrings[localizedString] then
        return nil
    end
    return localizedString
end

--#region Module

Lib_StringTable.GetLocalizedString = GetLocalizedString

--#endregion

return Lib_StringTable