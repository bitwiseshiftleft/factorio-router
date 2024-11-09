local protos = require "prototypes.router_proto_table"

local function verbosify_recipe(recipe)
    local ret = {}
    for idx,ing in ipairs(recipe) do
        ret[idx] = {type="item",name=ing[1],amount=ing[2]}
    end
    return ret
end

-- TODO: make appropriate ingredients
local function create_router_recipe(size,prefix,manual_ingredients,smart_ingredients,io_ingredients)
    if protos.enable_manual then
        data:extend({
            { -- Manual router
                type = "recipe",
                name = "router-"..size.."-"..prefix.."router",
                enabled = false,
                ingredients = verbosify_recipe(manual_ingredients),
                energy_required = 30,
                results = {{type="item", name="router-"..size.."-"..prefix.."router", amount=1}},
                fast_replaceable_group = "router-"..size.."-router"
            }
        })
    end
    
    if protos.enable_smart then
        data:extend({
            { -- Smart router
                type = "recipe",
                name = "router-"..size.."-"..prefix.."smart",
                enabled = false,
                ingredients = verbosify_recipe(smart_ingredients),
                energy_required = 30,
                results = {{type="item", name="router-"..size.."-"..prefix.."smart", amount=1}},
                fast_replaceable_group = "router-"..size.."-smart"
            }
        })
        data:extend({
            { -- Smart router I/O point
                type = "recipe",
                name = "router-"..size.."-"..prefix.."io",
                enabled = false,
                ingredients = verbosify_recipe(io_ingredients),
                energy_required = 30,
                results = {{type="item", name="router-"..size.."-"..prefix.."io", amount=1}},
                fast_replaceable_group = "router-"..size.."-io"
            }
        })
    end
end

for prefix,router in pairs(protos.table) do
    create_router_recipe("4x4",prefix,router.manual_ingredients,router.smart_ingredients,router.io_ingredients)
end
