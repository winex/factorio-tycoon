--local Constants = require("constants")
local RBGen = require("rbgen")
--local Util = require("util")


--- @event on_surface_cleared
--- @param surface_index uint
--- @param name @defines.events
--- @param tick uint

--- NOTE: This is not called when the default surface is created as it will always exist.
--- @event on_surface_created
--- @param surface_index uint
--- @param name @defines.events
--- @param tick uint

--- @event on_surface_deleted
--- @param surface_index uint
--- @param name @defines.events
--- @param tick uint

--- @event on_surface_imported
--- @param surface_index uint
--- @param original_name string
--- @param name @defines.events
--- @param tick uint

--- @event on_surface_renamed
--- @param surface_index uint
--- @param old_name string
--- @param new_name string
--- @param name @defines.events
--- @param tick uint


-- module
local M = {}

function M.on_surface_cleared(event)
    log("event: ".. tostring(event.name) .." surface: ".. tostring(event.surface_index))

    -- reset stats for this surface
    RBGen._reset_stats_all(event.surface_index)
end

function M.on_surface_created(event)
    log("event: ".. tostring(event.name) .." surface: ".. tostring(event.surface_index))

    local allowed = nil

    -- check name
    local name = game.surfaces[event.surface_index].name
    if not RBGen.isSurfaceNameAccepted(name) then
        allowed = false
    end

    -- WARN: there is not enough info right now, only set false state, use nil to decide later
    if allowed == false then
        RBGen.setSurfaceAllowed(event.surface_index, allowed)
    end
end

function M.on_surface_deleted(event)
    log("event: ".. tostring(event.name) .." surface: ".. tostring(event.surface_index))

    -- reset stats for this surface
    RBGen._reset_stats_all(event.surface_index)

    -- could use false, but we'll just remove using nil
    RBGen.setSurfaceAllowed(event.surface_index, nil)
end

function M.on_surface_imported(event)
    log("event: ".. tostring(event.name) .." surface: ".. tostring(event.surface_index))
    M.on_surface_created(event)

    -- return just in case it's not allowed
    if not RBGen.isSurfaceAllowed(event.surface_index) then
        return
    end

    -- rescan this surface
    RBGen.rescan_all(event.surface_index)
end

function M.on_surface_renamed(event)
    log("event: ".. tostring(event.name) .." surface: ".. tostring(event.surface_index))

    -- reuse code
    M.on_surface_created(event)
    -- rescan this surface, just in case it's now allowed
    RBGen.rescan_all(event.surface_index)
end


return M
