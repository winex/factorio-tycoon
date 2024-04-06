local Constants = require("constants")
local CityPlanning = require("city-planner")
local RecipeCalculator = require("recipe-calculator")
local GuiEventHandler = require("gui-event-handler")
local ShortcutHandler = require("shortcut-handler")
local ResearchHandler = require("research-event-handler")
local OnPlayerEventHandler = require("player-event-handler")
local OnChunkChartedHandler = require("chunk-charted-handler")
local OnConstructionHandler = require("construction-event-handler")
local SurfaceEventHandler = require("surface-event-handler")
local Passengers = require("passengers")
local ChatMessages = require("chat-messages")
local Consumption = require("consumption")
local City = require("city")
local Queue = require("queue")
local PrimaryIndustries = require("primary-industries")
local FloorUpgradesQueue = require("floor-upgrades-queue")
local RBGen = require("rbgen")
local Util = require("util")


--- BOOTSTRAP
local function init_globals()
    -- global_once WILL NOT assign when already exists
    local global_once = Util.global_once
    local empty_once = Util.empty_once

    --- NOTE: all globals should be listed here. in alphabetical order, please!
    global_once.tycoon_cities = {}
    global_once.tycoon_city_buildings = {}
    --global_once.tycoon_city_limit_warning_6
    --global_once.tycoon_enable_debug_logging
    --global_once.tycoon_entity_meta_info
    --XXX global.tycoon_global_generator
    --global_once.tycoon_has_initial_apple_farm
    --global_once.tycoon_house_lights
    --global_once.tycoon_info_message_primary_industries_displayed
    --global_once.tycoon_intro_message_displayed
    --global_once.tycoon_intro_message_treasury_displayed
    --global_once.tycoon_player_renderings
    global_once.tycoon_primary_industries = {}
    global_once.tycoon_tags_queue = {}
    global_once.tycoon_train_station_limits = {}
    global_once.tycoon_train_station_passenger_filters = {}
    global_once.tycoon_warning_mapgen_displayed = false

    -- nested tables are created manually
    for _, name in pairs(Constants.PRIMARY_INDUSTRIES) do
        empty_once(global.tycoon_primary_industries, name)
    end

    RBGen.init_globals()
end

script.on_init(function()
    log("on_init(): v".. game.active_mods["tycoon"])
    global.tycoon_global_generator = game.create_random_generator()
    init_globals()
end)

script.on_configuration_changed(function()
    log("on_configuration_changed(): v".. game.active_mods["tycoon"])
    init_globals()

    -- reset some globals on every update
    global.tycoon_city_limit_warning_6 = false
    global.tycoon_info_message_primary_industries_displayed = false
    --global.tycoon_intro_message_displayed = false
    global.tycoon_intro_message_treasury_displayed = false
end)

-- WARN: never change any globals here - will desync!
script.on_load(function()
end)


--- TICK HANDLERS
local ONE_SECOND = 60;
local FIVE_SECONDS = 5 * ONE_SECOND;
local THIRTY_SECONDS = 30 * ONE_SECOND;
local ONE_MINUTE = 60 * ONE_SECOND;

script.on_nth_tick(ONE_SECOND, function()
    CityPlanning.build_initial_city()
    PrimaryIndustries.spawn_initial_industry()
    City.start_house_construction()
end)

local function handle_passengers()
    for _, city in ipairs(global.tycoon_cities or {}) do
        Passengers.clearPassengers(city)
        Passengers.spawnPassengers(city)
    end
end

local function expand_roads()
    for _, city in ipairs(global.tycoon_cities or {}) do
        if Queue.count(city.buildingLocationQueue) < #city.grid then
            local coordinates = City.growAtRandomRoadEnd(city)
            if coordinates ~= nil then
                City.updatepossibleBuildingLocations(city, coordinates)
            end
        end
    end
end

script.on_nth_tick(FIVE_SECONDS, function()
    expand_roads()
    City.complete_house_construction()
    handle_passengers()
    FloorUpgradesQueue.process()
end)

local function add_more_cities()
    if #(global.tycoon_cities or {}) > 0 then
        CityPlanning.addMoreCities(false, false)
    end
end

script.on_nth_tick(THIRTY_SECONDS, function()
    City.construct_priority_buildings()
    -- todo: implement me later
    -- rediscover_unused_fields()
    add_more_cities()
    CityPlanning.tag_cities()
end)

local function display_intro_messages()
    ChatMessages.show_info_messages()
end

local function consume_resources()
    for _, city in ipairs(global.tycoon_cities or {}) do
        Consumption.consumeBasicNeeds(city)
        Consumption.consumeAdditionalNeeds(city)
        Consumption.update_construction_timers_all(city)
    end
end

script.on_nth_tick(ONE_MINUTE, function()
    consume_resources()
    City.construct_gardens()
    display_intro_messages()
end)

--- EVENT HANDLERS
script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity
}, function(event)
    OnConstructionHandler.on_built(event)
end)

script.on_event({
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    -- Register entities with script.register_on_entity_destroyed(entity) so that this event fires.
    defines.events.on_entity_destroyed,
}, function(event)
    OnConstructionHandler.on_removed(event)
end)

script.on_event(defines.events.on_chunk_generated, function (event)
    OnChunkChartedHandler.on_chunk_generated(event)
end)

script.on_event(defines.events.on_chunk_charted, function (event)
    OnChunkChartedHandler.on_chunk_charted(event)
end)

script.on_event(defines.events.on_chunk_deleted, function (event)
    OnChunkChartedHandler.on_chunk_deleted(event)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    OnPlayerEventHandler.on_player_cursor_stack_changed(event)
end)

script.on_event(defines.events.on_research_finished, function(event)
    ResearchHandler.on_research_finished(event)
end)

script.on_event({defines.events.on_lua_shortcut, "tycoon-cities-overview"}, function(event)
    ShortcutHandler.on_shortcut(event)
end)

script.on_event(defines.events.on_gui_opened, function (event)
    GuiEventHandler.on_gui_opened(event)
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    GuiEventHandler.on_gui_text_changed(event)
end)

script.on_event(defines.events.on_gui_click, function(event)
    GuiEventHandler.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    GuiEventHandler.on_gui_checked_state_changed(event)
end)

-- surface events
script.on_event(defines.events.on_surface_cleared, function (event)
    SurfaceEventHandler.on_surface_cleared(event)
end)
script.on_event(defines.events.on_surface_created, function (event)
    SurfaceEventHandler.on_surface_created(event)
end)
script.on_event(defines.events.on_surface_deleted, function (event)
    SurfaceEventHandler.on_surface_deleted(event)
end)
script.on_event(defines.events.on_surface_imported, function (event)
    SurfaceEventHandler.on_surface_imported(event)
end)
script.on_event(defines.events.on_surface_renamed, function (event)
    SurfaceEventHandler.on_surface_renamed(event)
end)

--- REMOTE INTERFACES
remote.add_interface("tycoon", {
    spawn_city = CityPlanning.addCity,
    calculate_recipes = RecipeCalculator.calculateAllRecipes
})