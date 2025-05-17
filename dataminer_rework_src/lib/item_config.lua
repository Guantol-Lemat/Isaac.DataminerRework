---@class Lib.ItemConfig
local Lib_ItemConfig = {}

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

--#region Module

Lib_ItemConfig.IsQuestItem = IsQuestItem

--#endregion

return Lib_ItemConfig