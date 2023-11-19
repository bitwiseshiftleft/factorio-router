local base_underground_item = data.raw["item"]["underground-belt"]

function create_router_item(size,prefix,tint)
    data:extend({
        {
            type = "item",
            name = "router-"..size.."-"..prefix.."router",
            icons = {
                {icon="__router__/graphics/router-icon.png", icon_size=128,},
                {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint}
            },
            subgroup = base_underground_item.subgroup,
            place_result = "router-"..size.."-"..prefix.."router",
            stack_size = 10
        },
        {
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
        }
    })
end

create_router_item("4x4","",util.color("ffc340D1"))
create_router_item("4x4","fast-",util.color("e31717D1"))
create_router_item("4x4","express-",util.color("43c0faD1"))


data:extend({
    {
        type = "item",
        name = "router-component-smart-port-lamp",
        icon = "__router__/graphics/light.png",
        icon_size = 32,
        place_result = "router-component-smart-port-lamp",
        stack_size = 1
    },
})