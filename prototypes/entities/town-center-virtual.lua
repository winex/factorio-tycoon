local roads_inc = 4

data:extend{
    {
        type = "container",
        name = "tycoon-town-center-virtual",
        icon = "__tycoon__/graphics/entity/town-hall/town-hall.png",
        icon_size = 64,
        inventory_size = 0,
        -- TEST: from real town-hall, increased to include roads
        collision_box = { {-2 - roads_inc, -2 - roads_inc}, {3 + roads_inc, 3 + roads_inc} },
        picture = {
            layers = {
                {
                    filename = "__tycoon__/graphics/entity/town-hall/town-hall.png",
                    priority = "high",
                    width = 250,
                    height = 250,
                    scale = 0.8,
                    shift = {0.55, 0.2}
                },
            }
        },
    }
}