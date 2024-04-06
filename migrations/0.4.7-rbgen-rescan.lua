local Constants = require("constants")
local RBGen = require("rbgen")
local Util = require("util")

-- WARN: migrations are run BEFORE any init(), always need this here
Util.global_once.tycoon_rbgen_stats =  {}

local n = table_size(global.tycoon_rbgen_stats)
if n > 0 then
    log("WARNING: tycoon_rbgen_stats: ".. n .." was not empty: ".. serpent.block(global.tycoon_rbgen_stats))
end

--
-- force reset ALL stats
--
RBGen._reset_globals()

-- only dev saves may exist before this script is written
local surface_index = Constants.STARTING_SURFACE_ID

-- rescan
RBGen.rescan_all(surface_index)
