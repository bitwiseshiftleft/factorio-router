local protos = require "prototypes.router_proto_table"

local function create_router_technology(prefix, tint, prerequisites, cost)
    local name = "router-" .. prefix .. "router"

    local effects = {}
    if protos.enable_manual then
        table.insert(effects,{type = "unlock-recipe", recipe =  "router-4x4-" .. prefix .. "router"})
    end
    if protos.enable_smart then
        table.insert(effects,{type = "unlock-recipe", recipe =  "router-4x4-" .. prefix .. "smart"})
    end

    local technology = {
        type = "technology",
        name = name,
        icons = {
            {
                icon = "__router__/graphics/router-icon.png",
                icon_size = 128,
            },
            {
                icon = "__router__/graphics/router-icon-mask.png",
                icon_size = 128,
                tint = tint,
            },
        },
        effects = effects,
        prerequisites = prerequisites,
        unit = cost,
        order = name
    }

    data:extend{technology}
end

if protos.enable_manual or protos.enable_smart then
    for prefix,router in pairs(protos.table) do
        create_router_technology(prefix,router.tint,router.prerequisites,router.tech_costs)
    end
end
