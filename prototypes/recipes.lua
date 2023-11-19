-- TODO: make appropriate ingredients
function create_router_recipe(size,prefix)
    local ingredients = {
        { prefix.."splitter", 8 },
        { prefix.."transport-belt", 8 }
        -- TODO: circuits?
    }
    data:extend({
        { -- Basic router
            type = "recipe",
            name = "router-"..size.."-"..prefix.."router",
            enabled = "false",
            ingredients = ingredients,
            energy_required = 30,
            result = "router-"..size.."-"..prefix.."router",
            fast_replaceable_group = "router-"..size.."-router"
        },
        { -- Smart router
            type = "recipe",
            name = "router-"..size.."-"..prefix.."smart",
            enabled = "false",
            ingredients =
            { 
                {"router-"..size.."-"..prefix.."router",1},
                {"arithmetic-combinator",20},
                {"decider-combinator",20}
                -- TODO circuits?
            },
            energy_required = 30,
            result = "router-"..size.."-"..prefix.."smart",
            fast_replaceable_group = "router-"..size.."-smart"
        },
    })
end

create_router_recipe("4x4","")
create_router_recipe("4x4","fast-")
create_router_recipe("4x4","express-")