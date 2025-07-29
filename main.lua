if not REPENTOGON then
    local message = "Dataminer Rework requires REPENTOGON!, mod cannot be loaded."
    Isaac.DebugString(message)
    print(message)

    return
end

DataminerRework = {}

--#region Setup

local old_require = require
local old_include = include
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
    loadedModule[2], loadedModule[3] = old_include(SRC_DIRECTORY .. "." .. modname)
    loadedModule[1] = true

    return loadedModule[2], loadedModule[3]
end

function include(modname)
    return old_include(SRC_DIRECTORY .. "." .. modname)
end

local old_dataminer_debug_mode = DATAMINER_DEBUG_MODE
DATAMINER_DEBUG_MODE = true

--#endregion

local Log = require("log")

local success, result = pcall(require, "startup")
if not success then
    Log.LogFull(Log.LogType.ERROR, "Failed to load mod:" .. result)
    DataminerRework = nil
else
    DataminerRework = result
end

--#region Cleanup

require = old_require
include = old_include
DATAMINER_DEBUG_MODE = old_dataminer_debug_mode

--#endregion
