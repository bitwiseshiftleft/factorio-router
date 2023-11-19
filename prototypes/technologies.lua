local function create_technology(prefix, tint, prereqs, cost)
    name = "router-" .. prefix .. "router"
    local technology = {
        type = "technology",
        name = name,
        icons = {
            {
                icon = "__router__/graphics/emptyred1.png",
                icon_size = 1,
            },
            {
                icon = "__router__/graphics/emptyred1.png",
                icon_size = 1,
                tint = tint,
            },
        },
        effects = {
            {type = "unlock-recipe", recipe =  "router-4x4-" .. prefix .. "router"},
            {type = "unlock-recipe", recipe =  "router-4x4-" .. prefix .. "smart"}
         },
        -- prerequisites = tech_prereqs, -- TODO
        unit = cost,
        order = name
    }

    data:extend{technology}
end

create_technology("",{r=0.8, g=0.8, b=0, a=1},
    { "circuit-network" },
    {
        count = 50,
        ingredients =
        {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
        },
        time = 30
    }
)

create_technology("fast-",{r=0.8, g=0.8, b=0, a=1},
    { "router" },
    {
        count = 50,
        ingredients =
        {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
        },
        time = 30
    }
)

create_technology("express-",{r=0.8, g=0.8, b=0, a=1},
    { "fast-router" },
    {
        count = 50,
        ingredients =
        {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
        },
        time = 30
    }
)
