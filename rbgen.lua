local Constants = require("constants")
local Util = require("util")


--- @typedef HexKey12 string[12] hex-encoded surface index and pos hash as "NNNNyyyyxxxx"

--- @class SurfacePosition
--- @field id number Surface index
--- @field pos MapPosition | ChunkPosition | Coordinates

-- TODO: how to doc such table? tycoon_rbgen_stats[name][HexKey12 | .size] = number
--- @class RBGenStats
--- @field [HexKey12] number
--- @field size number Region size for this entity name

--- @array global.tycoon_rbgen_stats[name]
--- @field [] RBGenStats[]


--- @module RBGen
local M = {}

function M.init_globals()
    Util.global_once.tycoon_rbgen_stats = {}

    -- always should set this, but other surfaces may be added outside of this function
    global.tycoon_rbgen_stats[Constants.STARTING_SURFACE_ID] = true

    -- table is mandatory for each name
    for name, params in pairs(Constants.PRIMARY_INDUSTRY_PARAMS) do
        Util.empty_once(global.tycoon_rbgen_stats, name)
        if global.tycoon_rbgen_stats[name].size == nil then
            global.tycoon_rbgen_stats[name].size = params.region_size  -- use cache
        end
    end
    for name, params in pairs(Constants.TOWN_PARAMS) do
        Util.empty_once(global.tycoon_rbgen_stats, name)
        if global.tycoon_rbgen_stats[name].size == nil then
            global.tycoon_rbgen_stats[name].size = params.region_size  -- use cache
        end
    end
end

--- be careful with this function, rbgen::rescan() should be called afterwards
function M._reset_globals()
    global.tycoon_rbgen_stats = {}
    M.init_globals()
end

function M.isSurfaceAllowed(surface_index)
    -- check if this surface is allowed
    return global.tycoon_rbgen_stats[surface_index] == true
end

--- tri-state
function M.getSurfaceAllowed(surface_index)
    return global.tycoon_rbgen_stats[surface_index]
end

function M.setSurfaceAllowed(surface_index, v)
    global.tycoon_rbgen_stats[surface_index] = v
end


--- @field id number Surface index
--- @param ch MapPosition | ChunkPosition | Coordinates
--- @return HexKey12
function M.chunkSurfaceToKey(id, ch)
    -- slow, but at least it should always be 12 chars
    -- chunkToHash() should return uint32-limited number
    return string.format("%04x%08x", id, Util.chunkToHash(ch))
end

--- @param sch SurfaceChunk
function M.surfacePositionToKey(sch)
    return M.chunkSurfaceToKey(sch.id, sch.chunk)
end

--- WARN: this function should never support incorrect keys, except for nil
--- @param key HexKey12 | nil
--- @return SurfacePosition | nil
function M.surfacePositionFromKey(key)
    if key == nil then
        return
    end

    assert(string.len(key) == 12, "wrong key length! should be 12!")
    local id = tonumber(string.sub(key, 1,  4), 16) or 1
    local ch = tonumber(string.sub(key, 5, 12), 16) or 0
    -- if we ever need negative surface index, here it is
    --if id >= 32768 then id = -1 * (65536 - id) end
    return { id = id, pos = Util.chunkFromHash(ch) }
end

--
-- tests
--

-- we need at least 48-bit type
assert(tonumber("10000ffff", 16) == 0x10000ffff)
assert(tonumber("2eeeeffff", 16) == 0x2eeeeffff)
assert(tonumber("07e407e807e9", 16) == 0x07e407e807e9)  -- factorio release year, current and next
assert(tonumber("ffffeeeeffff", 16) == 0xffffeeeeffff)

-- HexKey12
local _tests = {
    --NNNNyyyyxxxx
    ["00001111ffff"] = {     0,     -1,   4369 },
    ["0001fffefffd"] = {     1,     -3,     -2 },
    ["7fff80018000"] = { 32767, -32768, -32767 },
    ["ffff00010002"] = { 65535,      2,      1 },
}
for k, v in pairs(_tests) do
    local t = M.surfacePositionFromKey(k)
    --log("test: surfacePositionFromKey('".. k .."'): ".. serpent.line(t))
    assert(t.id == v[1] and t.pos ~= nil and t.pos.x == v[2] and t.pos.y == v[3], k)
end


function M.add(surface_index, pos, size, name)
    -- count per name per region
    local k = M.chunkSurfaceToKey(surface_index, Util.chunkToRegion(pos, size))
    global.tycoon_rbgen_stats[name][k] = (global.tycoon_rbgen_stats[name][k] or 0) + 1
end

function M.get(surface_index, pos, size, name)
    local k = M.chunkSurfaceToKey(surface_index, Util.chunkToRegion(pos, size))
    return global.tycoon_rbgen_stats[name][k] or 0
end

function M.remove(surface_index, pos, size, name)
    local k = M.chunkSurfaceToKey(surface_index, Util.chunkToRegion(pos, size))
    local n = (global.tycoon_rbgen_stats[name][k] or 0) - 1
    if n <= 0 then
        n = nil
    end
    global.tycoon_rbgen_stats[name][k] = n
end

function M.remove_multiple(surface_index, pos, names)
    for _, name in pairs(names) do
        local size = global.tycoon_rbgen_stats[name].size
        if size == nil then goto continue end

        -- TODO: k could be cached if size == size_prev
        local k = M.chunkSurfaceToKey(surface_index, Util.chunkToRegion(pos, size))
        local n = (global.tycoon_rbgen_stats[name][k] or 0) - 1
        if n <= 0 then
            n = nil
        end

        global.tycoon_rbgen_stats[name][k] = n
        ::continue::
    end
end

-- WARN: this might be slow
function M.count_regions(surface_index, name)
    --assert(global.tycoon_rbgen_stats[name])
    local count = 0
    local hex = string.format("%04x", surface_index)
    for k, _ in pairs(global.tycoon_rbgen_stats[name]) do
        if string.sub(k, 1, 4) == hex then
            count = count + 1
        end
    end
    return count
end

-- WARN: this might be slow
function M.count_surface(surface_index, name)
    --assert(global.tycoon_rbgen_stats[name])
    local count = 0
    local hex = string.format("%04x", surface_index)
    for k, n in pairs(global.tycoon_rbgen_stats[name]) do
        if string.sub(k, 1, 4) == hex then
            count = count + n
        end
    end
    return count
end

function M.count(name)
    -- DEBUG
    assert(global.tycoon_rbgen_stats[name], "should never be nil!!! fix caller or init!")
    return table_size(global.tycoon_rbgen_stats[name])
end

function M.count_all(name)
    local count = 0
    for _, n in pairs(global.tycoon_rbgen_stats[name] or {}) do
        count = count + n
    end
    return count
end

function M._reset_stats(surface_index, name)
    local hex = string.format("%04x", surface_index)
    -- BUG: this will crash if removed while in pairs() loop!!!
    for k, v in pairs(global.tycoon_rbgen_stats[name] or {}) do
        if string.sub(k, 1, 4) == hex then
            global.tycoon_rbgen_stats[name][k] = nil
        end
    end
end

function M._reset_stats_all(surface_index)
    for name, _ in pairs(Constants.PRIMARY_INDUSTRY_PARAMS) do
        M._reset_stats(surface_index, name)
    end
    for name, _ in pairs(Constants.TOWN_PARAMS) do
        M._reset_stats(surface_index, name)
    end
end

function M.rescan(surface_index, name, size)
    M.init_globals()
    M._reset_stats(surface_index, name)

    -- TODO: why rescan() does this?!
    local n = global.tycoon_rbgen_stats[name].size
    if n == nil or n ~= size then
        log("rescan(): size: ".. tostring(n) .." has changed: ".. size .." name: ".. name)
    end
    global.tycoon_rbgen_stats[name].size = size

    local count = 0
    local surface = game.surfaces[surface_index]
    if surface == nil or (not surface.valid) then
        return count
    end

    local entities = surface.find_entities_filtered({name = name})
    for _, entity in pairs(entities or {}) do
        if entity.valid then
            M.add(surface_index, Util.positionToChunk(entity.position), size, name)
            count = count + 1
        else
            log("invalid entity pos: ".. entity.position.x ..", ".. entity.position.y .." name: ".. name)
        end
    end
    log("rescan(): surface: ".. surface.index .." count: ".. count .." name: ".. name)
    return count
end

function M.rescan_all(surface_index)
    for name, params in pairs(Constants.PRIMARY_INDUSTRY_PARAMS) do
        M.rescan(surface_index, name, params.region_size)
    end
    for name, params in pairs(Constants.TOWN_PARAMS) do
        M.rescan(surface_index, name, params.region_size)
    end
end

local RBGEN_CHUNKS_MIN = 128 / Constants.CHUNK_SIZE
function M.on_chunk_generated(event, params, name, callback_func)
    if params == nil then
        return
    end

    -- CAPS because it is very important
    local CHUNKS = math.max(RBGEN_CHUNKS_MIN, params.region_size)
    local CHUNKS_AREA = CHUNKS^2

    local p_orig = params.prob or 1.0
    local p = p_orig
    -- adjust overall probability for water coverage: [0.17 ; 6.0]
    -- 600% just makes less industries in total as rnd doesn't hit at all
    -- 17% we want more fisheries, but not others. water_lo_mult helps
    -- 0% assume as 1.0 as it would lead to division by zero ang trigger more false positives
    local w = event.surface.map_gen_settings.water
    if w < 1.0 and w > 0.0 and params.water_lo_mult ~= nil then
        p = p * Util.lerp(-Util.factorioSliderInverse(w), 1, params.water_lo_mult)  -- fit into [water_lo_mult;1]
    elseif w > 1.0 and params.water_hi_mult ~= nil then
        p = p * Util.lerp(Util.factorioSliderInverse(w), 1, params.water_hi_mult)  -- fit into [1;water_hi_mult]
    end

    -- TL;DR we divide prob by region area (chunks), so with 1.0 it SHOULD (but not guaranteed to!) spawn only once
    -- PRNG segmentation by chunk pos, pre-multiplied by n:
    --   always wrap p (p % n) to be statistically correct, so that [;4.5) becomes [;0.5)
    --   ex: n=64 p=64 for any pos should become always-hit: >=0 and <64
    -- n=4 and p=0.5: [0;0.5) [1;1.5) [2;2.5) [3;3.5)  -- easy one, same as p=1.0
    -- n=4 and p=3.7: [0;3.7) [1;0.7) [2;1.7) [3;2.7)  -- wrapped
    local seg_a = Util.chunkToIndex2D(event.position, CHUNKS)
    local seg_b = (seg_a + p) % CHUNKS_AREA
    -- WARN: random(N, M) returns int, but we need float and ALL the random bits here
    local rnd = global.tycoon_global_generator() * CHUNKS_AREA
    -- TODO: simplify this hell
    if seg_a < seg_b then       -- normal, check [a; b)
        if not (rnd >= seg_a and rnd < seg_b) then
            return
        end
    elseif seg_a >= seg_b then  -- wrapped, check ..b) ; ..[a
        if not (rnd >= seg_a or rnd < seg_b) then
            return
        end
    end

    local region = Util.chunkToRegion(event.position, CHUNKS)
    if true then
        log(string.format("p: %.2f (x%.1f) rnd: %.2f [%.1f;%.1f)", p, p/p_orig, rnd, seg_a, seg_b)
            .." rg: ".. region.x ..";".. region.y
            .." ch: ".. event.position.x ..";".. event.position.y
            .." name: ".. name
        )
    end

    -- tiles filtering
    if params.tiles ~= nil then
        local tile_ratio = event.surface.count_tiles_filtered{
            area = event.area,
            name = params.tiles,
        } / Constants.CHUNK_SIZE^2

        if not (tile_ratio > (params.min or 0) and tile_ratio <= (params.max or 1)) then
            --log(string.format("X tile_ratio: %.3f ~= [%.3f, %.3f]", tile_ratio, params.min, params.max or 1) .." name: ".. name)
            return
        end
    end

    --
    -- TODO: too many stuff here, simplify, split, w/e!
    --
    local rect = event.area
    -- expand rect:Position with params.radius, but bound it inside current region
    -- WARN: BoundingBox seems to be [min; max), so we add +1 more to point B
    if params.radius ~= nil then
        local ch = { x = region.x * CHUNKS, y = region.y * CHUNKS }
        local a = { x = event.position.x - params.radius,   y = event.position.y - params.radius   }
        local b = { x = event.position.x + params.radius+1, y = event.position.y + params.radius+1 }
        --log(" unbound [a: ".. serpent.line(a) ..", ".. "b: ".. serpent.line(b) ..")")

        a = { x = math.max(ch.x, a.x), y = math.max(ch.y, a.y) }
        b = { x = math.min(ch.x + CHUNKS, b.x), y = math.min(ch.y + CHUNKS, b.y) }
        log(" ..bound [a: ".. serpent.line(a) ..", ".. "b: ".. serpent.line(b) ..")")
        -- just to make sure, hoping for BoundingBox to be [min; max)
        assert(a.x >= ch.x and a.y >= ch.y and b.x <= ch.x + CHUNKS and b.y <= ch.y + CHUNKS)
        rect = { left_top = Util.chunkToPosition(a), right_bottom = Util.chunkToPosition(b) }
    end
    log("rect: " .. rect.left_top.x .."..".. rect.right_bottom.x ..";".. rect.left_top.y .."..".. rect.right_bottom.y)

    local virtual_name = (name == "tycoon-town-hall") and "tycoon-town-center-virtual" or name
    local pos = event.surface.find_non_colliding_position_in_box(virtual_name, rect, 2, true)
    if pos == nil then
        log("X can't find"
            .." rect: " .. rect.left_top.x .."..".. rect.right_bottom.x ..";".. rect.left_top.y .."..".. rect.right_bottom.y
            .." name: ".. name
        )
        return
    end

    local entity = callback_func(pos, name, event.surface.index)
    if entity == nil then
        log("X can't place" .." pos: ".. pos.x ..", ".. pos.y .." name: ".. name)
        return
    end

    -- add to stats finally
    M.add(event.surface.index, event.position, params.region_size, name)
    return entity
end


return M
