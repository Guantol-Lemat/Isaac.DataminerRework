if not REPENTOGON then
    local message = "Dataminer Rework requires REPENTOGON!, mod cannot be loaded."
    Isaac.DebugString(message)
    print(message)

    return
end

DataminerRework = {}

--#region Setup

local s_Callbacks = {}

local oldAddCallback = DataminerRework.AddCallback
---@param self ModReference
---@param callbackId string | ModCallbacks
---@param callbackfn function
---@param param any
DataminerRework.AddCallback = function(self, callbackId, callbackfn, param)
    s_Callbacks[callbackId] = s_Callbacks[callbackId] or {}
    table.insert(s_Callbacks[callbackId], callbackfn)
    oldAddCallback(self, callbackId, callbackfn, param)
end

local oldAddPriorityCallback = DataminerRework.AddPriorityCallback
---@param self ModReference
---@param callbackId string | ModCallbacks
---@param priority CallbackPriority | integer
---@param callbackFunction function
---@param param any
DataminerRework.AddPriorityCallback = function(self, callbackId, priority, callbackFunction, param)
    s_Callbacks[callbackId] = s_Callbacks[callbackId] or {}
    table.insert(s_Callbacks[callbackId], callbackFunction)
    return oldAddPriorityCallback(self, callbackId, priority, callbackFunction, param)
end

local function UnloadMod(mod)
	Isaac.RunCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, mod)

	for index, value in ipairs(s_Callbacks) do
        DataminerRework:RemoveCallback(value[1], value[2])
    end

    s_Callbacks = {}
end

local old_require = require
local SRC_DIRECTORY = "dataminer_rework_src"
local s_LoadedModules = {}

function require(modname)
    local loadedModule = s_LoadedModules[modname]
    if loadedModule then
        assert(loadedModule[1] == true, string.format("Module %s has caused a recursive dependency", modname))
        return loadedModule[2], loadedModule[3]
    end

    loadedModule = {false, nil, nil}
    s_LoadedModules[modname] = loadedModule
    loadedModule[2], loadedModule[3] = include(string.format("%s.%s", SRC_DIRECTORY, modname))
    loadedModule[1] = true

    return loadedModule[2], loadedModule[3]
end

local old_dataminer_debug_mode = DATAMINER_DEBUG_MODE
DATAMINER_DEBUG_MODE = true

--#endregion

local success, result = pcall(require, "startup")
if not success then
    local message = string.format("Dataminer Rework failed to load: %s", result)
    Isaac.DebugString(message)
    Console.PrintError(message)
else
    DataminerRework = result
end

--#region Cleanup

require = old_require
DATAMINER_DEBUG_MODE = old_dataminer_debug_mode

--#endregion
