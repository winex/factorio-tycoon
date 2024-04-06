local OneSecond = 60
-- Factorio's chunk size, in tiles
local CHUNK_SIZE = 32  -- Lua is insane, no access from the same table

local CONSTANTS = {
    CHUNK_SIZE = CHUNK_SIZE,
    -- nothing would be generated inside this area, except for initial farms if enabled
    STARTING_RADIUS_CHUNKS = 128 / CHUNK_SIZE,
    -- NOTE: map_gen_settings.starting_area is mapped as [100%; 600%] => [1; multiplier]
    -- ex: 4(see above) * 4(here) makes SA 600% as 1024x1024 tiles total, 1 disables that setting effect
    STARTING_AREA_MULTIPLIER = 4,

    -- Each cell has 6x6 tiles
    CELL_SIZE = 6,
    CITY_GROWTH_TICKS = OneSecond * 60,
    CITY_STATS_LIFETIME_TICKS = OneSecond * 30,
    CITY_RADIUS = 150,
    -- Minimum ticks until we try adding another city
    MORE_CITIES_TICKS = OneSecond * 120,
    INITIAL_CITY_TICK = 30,
    PASSENGER_SPAWNING_TICKS = OneSecond * 2,

    -- all special buildings, true if required for supply
    CITY_SPECIAL_BUILDINGS = {
        ["tycoon-market"] = true,
        ["tycoon-hardware-store"] = true,
        ["tycoon-water-tower"] = true,
        ["tycoon-treasury"] = false,
        ["tycoon-passenger-train-station"] = false,
    },
    -- recreated from rbgen params to avoid errors, see at the bottom
    PRIMARY_INDUSTRIES = {},
    CITIZEN_COUNTS = {
        simple = 4,
        residential = 20,
        highrise = 100,
    },

    STARTING_SURFACE_ID = 1,

    RESIDENTIAL_HOUSE_RATIO = 3,
    HIGHRISE_HOUSE_RATIO = 5,

    --
    -- Region-Based GENerator
    --
    RBGEN_ENABLED = true,

    PRIMARY_INDUSTRY_CHUNKS = 256 / CHUNK_SIZE,
    -- TODO: could use table.deepcopy() if there is need of changing params at runtime
    --- @class RBGenParams
    --- @field prob number Entity spawn probability [0;1] per region
    --- @field water_hi_mult number Spawn more on [100%;600%] water setting w/o affecting others
    --- @field water_lo_mult number Spawn more on [17%;75%] water setting w/o affecting others
    --- @field (min; max], so >0.0 and <=1.0 of total tiles
    --- @field radius chunks Bounded by region size search: 0 - 1x1, 1 - 3x3, no need to go higher
    --- @field tiles array, see Data.raw#tile. TEST:
    --    dirt-{1..7}        [X] fine
    --    grass-{1..4}       [X] fine
    --    red-desert-{0..3}  [X] fine
    --    sand-{1..3}        [?] what could it be used for?
    --    water, deep-water  [X] of course, FISH! :)
    --- @field region_size number (cache) Region size for this entity name
    PRIMARY_INDUSTRY_PARAMS = {
        ["tycoon-apple-farm"] = { prob = 0.5, water_hi_mult = 1.5,
            min = 0.25,
            tiles = {
                "grass-1", "grass-2", "grass-3", "grass-4",
                "dirt-1", "dirt-2", "dirt-3", "dirt-4", "dirt-5", "dirt-6", "dirt-7",
                "red-desert-1", "red-desert-2", "red-desert-3",
            }
        },
        ["tycoon-wheat-farm"] = { prob = 0.5, water_hi_mult = 1.5,
            min = 0.50,
            tiles = {
                "grass-1", "grass-2", "grass-3", "grass-4",
                "dirt-1", "dirt-2", "dirt-3", "dirt-4", "dirt-5", "dirt-6", "dirt-7",
            },
        },
        ["tycoon-fishery"]    = { prob = 4.0, water_hi_mult = 1.5, water_lo_mult = 1.5,
            min = 0.25, max = 0.90, radius = 1,
            tiles = { "water", "deep-water", },
        },
    },

    -- test
    TOWN_LIMIT = 6,
    TOWN_CHUNKS = 1024 / CHUNK_SIZE,
    TOWN_PARAMS = {
        -- default idlers type :)
        ["tycoon-town-hall"] = { prob = 0.5, radius = 2,
        },
        -- if there would ever be different type of towns, like specialized ones:
        --["tycoon-town-miner"] = { prob = 0.25, radius = 3,
        --},
        --["tycoon-town-production"] = { prob = 0.25, radius = 1,
        --},
    },

    -- or even separate production factories like in RailroadTycoon mod :)
    -- though some kind of town-related secondary industries might be even better
    --...

    -- This array is ordered from most expensive to cheapest, so that
    -- we do expensive upgrades first (instead of just letting the road always expand).
    -- Sepcial buildings (like the treasury) are an exception that should ideally come first.
    CONSTRUCTION_MATERIALS = {
        specialBuildings = {{
            name = "stone-brick",
            required = 1,
        }, {
            name = "iron-plate",
            required = 1,
        }},
        highrise = {{
            name = "concrete",
            required = 50,
        }, {
            name = "steel-plate",
            required = 25,
        }, {
            name = "small-lamp",
            required = 5,
        }, {
            name = "pump",
            required = 2,
        }, {
            name = "pipe",
            required = 10,
        }},
        residential = {{
            name = "stone-brick",
            required = 30,
        }, {
            name = "iron-plate",
            required = 20,
        }, {
            name = "steel-plate",
            required = 10,
        }, {
            name = "small-lamp",
            required = 2,
        }},
        simple = {{
            name = "stone-brick",
            required = 10,
        }, {
            name = "iron-plate",
            required = 5,
        }},
    },

    GROUND_TILE_TYPES = {
        road = "dry-dirt",
        simple = "landfill",
        residential = "stone-path",
        highrise = "concrete",
    },
}

-- avoid copies, so rebuild into a simple array of names for counting and api functions
CONSTANTS.PRIMARY_INDUSTRIES = {}
for name, _ in pairs(CONSTANTS.PRIMARY_INDUSTRY_PARAMS) do
    table.insert(CONSTANTS.PRIMARY_INDUSTRIES, name)
    CONSTANTS.PRIMARY_INDUSTRY_PARAMS[name].region_size = CONSTANTS.PRIMARY_INDUSTRY_CHUNKS  -- cache
end

for name, _ in pairs(CONSTANTS.TOWN_PARAMS) do
    CONSTANTS.TOWN_PARAMS[name].region_size = CONSTANTS.TOWN_CHUNKS  -- cache
end

return CONSTANTS
