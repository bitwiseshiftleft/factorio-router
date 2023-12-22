local protos = require "prototypes.router_proto_table"

-- TODO: make appropriate ingredients
function create_router_recipe(size,prefix,manual_ingredients,smart_ingredients,io_ingredients)
    if protos.enable_manual then
        data:extend({
            { -- Manual router
                type = "recipe",
                name = "router-"..size.."-"..prefix.."router",
                enabled = "false",
                ingredients = manual_ingredients,
                energy_required = 30,
                result = "router-"..size.."-"..prefix.."router",
                fast_replaceable_group = "router-"..size.."-router"
            }
        })
    end
    
    if protos.enable_smart then
        data:extend({
            { -- Smart router
                type = "recipe",
                name = "router-"..size.."-"..prefix.."smart",
                enabled = "false",
                ingredients = smart_ingredients,
                energy_required = 30,
                result = "router-"..size.."-"..prefix.."smart",
                fast_replaceable_group = "router-"..size.."-smart"
            }
        })
        data:extend({
            { -- Smart router I/O point
                type = "recipe",
                name = "router-"..size.."-"..prefix.."io",
                enabled = "false",
                ingredients = io_ingredients,
                energy_required = 30,
                result = "router-"..size.."-"..prefix.."io",
                fast_replaceable_group = "router-"..size.."-io"
            }
        })
    end
end

for prefix,router in pairs(protos.table) do
    create_router_recipe("4x4",prefix,router.manual_ingredients,router.smart_ingredients,router.io_ingredients)
end
