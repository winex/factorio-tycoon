local Constants = require("constants")
local PrimaryIndustries = require("primary-industries")
local CityPlanning = require("city-planner")
local Util = require("util")
local TagsQueue = require("tags-queue")
local RBGen = require("rbgen")

local function randomPrimaryIndustry()
    return Constants.PRIMARY_INDUSTRIES[global.tycoon_global_generator(#Constants.PRIMARY_INDUSTRIES)]
end

local function insideStartingArea(chunk)
    -- NOTE: slider thingy, but can be changed only when biters are enabled and docs says it's circular
    -- a. looks like 1 means something like 256x256[8x8], so radius could be 4 chunks
    -- b. restart shows 512x512[16x16] generated map, so it could be even 8

    -- fit [100%;600%] into [1;multiplier]
    local sa = Constants.STARTING_RADIUS_CHUNKS * Util.lerp(Util.factorioSliderInverse(
        Util.clamp(game.surfaces[Constants.STARTING_SURFACE_ID].map_gen_settings.starting_area, 1, 6)
    ), 1, Constants.STARTING_AREA_MULTIPLIER)

    -- we want [-sa;sa), but abs() include positive ones
    --return math.abs(chunk.x) <= sa and math.abs(chunk.y) <= sa
    return chunk.x >= -sa and chunk.x < sa and chunk.y >= -sa and chunk.y < sa
end

-- TODO: we can use similar (another option?) when city builds, to refresh map
--- forces to chart chunk if enabled in settings
local function chartChunk(surface, chunk)
    if (settings.global["tycoon-reveal-spawned"] or {}).value then
        local p = Util.chunkToPosition(chunk)
        game.forces.player.chart(surface, {p, p})
    end
end


--
-- event handlers: on_chunk_*()
--

local function on_chunk_generated(event)
    -- WARN: not a typo: '.surface.index', not '.surface_index'! see docs...
    if event.surface.index == Constants.STARTING_SURFACE_ID and insideStartingArea(event.position) then
        return
    end

    --- NOTE: DISABLES EVERYTHING BELOW this block!
    if not Constants.RBGEN_ENABLED then
        return
    end

    -- TODO: someone should set something for other surfaces to work
    --- tri-state, nil means it will be set by on_chunk_generated()
    if RBGen.getSurfaceAllowed(event.surface.index) == false then
        return
    end

    -- rbgen: generate primary industries
    for name, params in pairs(Constants.PRIMARY_INDUSTRY_PARAMS) do
        local entity = RBGen.on_chunk_generated(event, params, name, PrimaryIndustries.place_primary_industry_at_position)
        if entity == nil then
            goto continue
        end

        -- chart
        chartChunk(event.surface, event.position)

        -- already checks for nil, but why it is separate func? do we need it?
        PrimaryIndustries.add_to_global_primary_industries(entity)

        -- should be last!
        ::continue::
    end

    ---
    --- NOTE: returns below! town logic should be last

    -- limit towns globally
    local towns_total = RBGen.count("tycoon-town-hall")
    if towns_total >= Constants.TOWN_LIMIT then
        return
    end

    -- rbgen: generate towns
    for name, params in pairs(Constants.TOWN_PARAMS) do
        -- limit towns per region of this "type"
        if RBGen.get(event.surface.index, event.position, params.region_size, name) > 0 then
            return
        end

        -- TODO: fix addCityCallback(), use more sophisticated placing, but don't go out of region
        local city_name = RBGen.on_chunk_generated(event, params, name, CityPlanning.addCityCallback)
        if city_name == nil then
            goto continue
        end

        -- chart
        chartChunk(event.surface, event.position)

        local p = Util.chunkToPosition(event.position)
        local r = Util.chunkToRegion(event.position, params.region_size)
        log(string.format("town added: pos: %d, %d ch: %d;%d rg: %d;%d name: %s",
            p.x, p.y, event.position.x, event.position.y, r.x, r.y, city_name
        ))

        -- this can happen only once, so we can avoid global *_displayed var
        if towns_total == Constants.TOWN_LIMIT then
            game.print({ "",
                "[color=orange]Factorio Tycoon:[/color] ", { "tycoon-warning-limit-reached-city", Constants.TOWN_LIMIT },
            })
        end

        -- should be last!
        ::continue::
    end
end

-- WARN: might be called very frequently, for ex: when there are biters wandering - avoid useless stuff
local function on_chunk_charted(event)
    if event.surface_index == Constants.STARTING_SURFACE_ID and insideStartingArea(event.position) then
        return
    end

    -- if not allowed, don't do anything
    if Constants.RBGEN_ENABLED and (not RBGen.isSurfaceAllowed(event.surface_index)) then
        return
    end

    -- place pending tags
    -- TODO: support tagging everything else here, like cities
    local pos_name = TagsQueue.get(event.position, event.surface_index)
    if pos_name ~= nil then
        PrimaryIndustries.tagIndustry(pos_name[1], pos_name[2], event.surface_index)
    end

    --- NOTE: DISABLES EVERYTHING BELOW this block!
    if Constants.RBGEN_ENABLED then
        return
    end

    if global.tycoon_global_generator() < 0.25 then
        local entity_name = randomPrimaryIndustry()
        local position
        if entity_name == "tycoon-fishery" then
            local water_tile_count = game.surfaces[event.surface_index].count_tiles_filtered{
                area = event.area,
                name = { "water", "deepwater" }
            }

            local water_ratio = (water_tile_count / Constants.CHUNK_SIZE^2)
            local has_enough_water = water_ratio > 0.25 and water_ratio < 0.9
            if not has_enough_water then
                return
            end

            position = game.surfaces[event.surface_index].find_non_colliding_position(entity_name, event.area.left_top, 100, 1, true)
        else
            position = game.surfaces[event.surface_index].find_non_colliding_position_in_box(entity_name, event.area, 2, true)
        end

        if position ~= nil then
            local min_distance = 500
            if entity_name == "tycoon-fishery" then
                -- map_gen_settings.water is a percentage value. As the amount of water on the map decreases, we want to spawn more fisheries per given area.
                -- Don't go below 50 though.
                -- The game slider allows between 17% and 600%.
                -- 17% * 200 = 34
                -- 600% * 200 = 1200
                min_distance = math.max(200 * game.surfaces[event.surface_index].map_gen_settings.water, 50)
            end
            local nearby_same_primary_industries_count = game.surfaces[event.surface_index].count_entities_filtered{
                position=position,
                radius=min_distance,
                name=entity_name,
                limit=1
            }
            if nearby_same_primary_industries_count == 0 then
                local entity = PrimaryIndustries.place_primary_industry_at_position(position, entity_name, event.surface_index)
                PrimaryIndustries.add_to_global_primary_industries(entity)
            end
        end
    end
end

local function on_chunk_deleted(event)
    -- if event.surface_index ~= Constants.STARTING_SURFACE_ID then
    --     return
    -- end

    PrimaryIndustries.cleanup_global_primary_industries()

    local count = 0
    for i, chunk in pairs(event.positions) do
        -- remove pending tags
        local t = TagsQueue.get(chunk, event.surface_index)
        if t ~= nil then
            TagsQueue.delete(chunk, event.surface_index)
            count = count + 1
        end
    end
    log("tycoon_tags_queue removed: ".. tostring(count))

    -- why is this so hard?!
    local all_names = {}
    for _, name in pairs(Constants.PRIMARY_INDUSTRIES) do table.insert(all_names, name) end
    table.insert(all_names, "tycoon-town-hall")

    for _, chunk in pairs(event.positions) do
        RBGen.remove_multiple(event.surface_index, chunk, all_names)
    end
end


return {
    on_chunk_generated = on_chunk_generated,
    on_chunk_charted = on_chunk_charted,
    on_chunk_deleted = on_chunk_deleted,
}