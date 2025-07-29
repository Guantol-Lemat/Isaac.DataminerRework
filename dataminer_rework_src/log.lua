---@class Log
local Log = {}

local MOD_PREFIX = "[Dataminer Rework]"

---@enum LogType
local LogType = {
    INFO = 1,
    WARNING = 2,
    ERROR = 3,
    ASSERT = 4,
}

local s_LogTypeToString = {
    [LogType.INFO] = "[INFO]",
    [LogType.WARNING] = "[WARNING]",
    [LogType.ERROR] = "[ERROR]",
    [LogType.ASSERT] = "[ASSERT]",
}

local s_TypeToConsoleLog = {
    [LogType.INFO] = print,
    [LogType.WARNING] = Console.PrintWarning,
    [LogType.ERROR] = Console.PrintError,
}

---@param logType LogType
---@param message string
local function LogFile(logType, message, ...)
    Isaac.DebugString(MOD_PREFIX .. " " .. s_LogTypeToString[logType] .. " " .. string.format(message, ...))
end

---@param logType LogType
---@param message string
local function LogConsole(logType, message, ...)
    local consoleLogFunction = s_TypeToConsoleLog[logType]
    consoleLogFunction(MOD_PREFIX .. " " .. s_LogTypeToString[logType] .. " " .. string.format(message, ...))
end

---@param logType LogType
---@param message string
local function LogFull(logType, message, ...)
    LogFile(logType, message, ...)
    LogConsole(logType, message, ...)
end

---@param logType LogType
---@param message string
---@return string
local function Format(logType, message, ...)
    return MOD_PREFIX .. " " .. s_LogTypeToString[logType] .. " " .. string.format(message, ...)
end

--#region Module

Log.LogType = LogType
Log.LogFile = LogFile
Log.LogConsole = LogConsole
Log.LogFull = LogFull
Log.Format = Format

--#endregion

return Log