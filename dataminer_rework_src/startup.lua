---@class DataminerRework
local DataminerRework = {}

--#region Dependencies

local Dataminer = require("dataminer_rework_src.datamining.datamining")
include("scripts.init_bubble_data")
include("scripts.init_datamine_strategies")

--#endregion

local mod = RegisterMod("Dataminer Rework", 1)

return DataminerRework