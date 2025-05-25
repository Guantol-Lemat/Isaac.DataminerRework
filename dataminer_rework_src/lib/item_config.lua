---@class Lib.ItemConfig
local Lib_ItemConfig = {}

local Lib = {
    StringTable = require("lib.stringtable")
}

---@param itemConfig ItemConfig
---@param collectible CollectibleType | integer
---@return boolean
local function IsQuestItem(itemConfig, collectible)
    local collectibleConfig = itemConfig:GetCollectible(collectible)
    if not collectibleConfig then
        return false
    end

    return collectibleConfig:HasTags(ItemConfig.TAG_QUEST)
end


---@param itemConfig ItemConfig
---@param collectibleType CollectibleType | integer
---@param language Language?
---@return string
local function GetCollectibleDisplayName(itemConfig, collectibleType, language)
    language = language or Language.ENGLISH
    local collectibleConfig = itemConfig:GetCollectible(collectibleType)
    if not collectibleConfig then
        return tostring(collectibleType)
    end

    local name = collectibleConfig.Name
    local localizedString = Lib.StringTable.GetLocalizedString("Items", name, language)
    if localizedString then
        name = localizedString
    end

    return name
end

--#region Module

Lib_ItemConfig.IsQuestItem = IsQuestItem
Lib_ItemConfig.GetCollectibleDisplayName = GetCollectibleDisplayName

--#endregion

return Lib_ItemConfig