local protos = require "prototypes.router_proto_table"
local base_underground_item = data.raw["item"]["underground-belt"]

function create_router_item(size,prefix,tint)
    if protos.enable_manual then
        data:extend{{
            type = "item",
            name = "router-"..size.."-"..prefix.."router",
            icons = {
                {icon="__router__/graphics/router-icon.png", icon_size=128,},
                {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint}
            },
            subgroup = base_underground_item.subgroup,
            place_result = "router-"..size.."-"..prefix.."router",
            stack_size = 10
        }}
    end
    if protos.enable_smart then
        data:extend{{
            type = "item",
            name = "router-"..size.."-"..prefix.."smart",
            icons = {
                {icon="__router__/graphics/router-icon.png", icon_size=128,},
                {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint},
                {icon="__router__/graphics/router-icon-ring.png", icon_size=128, tint=tint}
            },
            subgroup = base_underground_item.subgroup,
            place_result = "router-"..size.."-"..prefix.."smart",
            stack_size = 10
        },{
            type = "item",
            name = "router-"..size.."-"..prefix.."io",
            icons = {
                {icon="__router__/graphics/emptyred128.png", icon_size=128,}
            },
            subgroup = base_underground_item.subgroup,
            place_result = "router-"..size.."-"..prefix.."io",
            stack_size = 10
    }}
    end
end

for prefix,router in pairs(protos.table) do
    create_router_item("4x4",prefix,router.tint)
end

if protos.enable_smart then
    -- For blueprinting
    -- TODO: add regular routers
    data:extend({
        {
            type = "item",
            name = "router-component-smart-port-lamp",
            icon = "__router__/graphics/light.png",
            icon_size = 32,
            place_result = "router-component-smart-port-lamp",
            stack_size = 1
        }, {
            type = "item",
            name = "router-component-port-trim-combinator",
            icon = "__router__/graphics/light.png", -- TODO make graphics
            icon_size = 32,
            place_result = "router-component-port-trim-combinator",
            stack_size = 1
        }, {
            type = "item",
            name = "router-component-chest-contents-lamp",
            icon = "__router__/graphics/light.png", -- TODO make graphics
            icon_size = 32,
            place_result = "router-component-chest-contents-lamp",
            stack_size = 1
        },
    })
end