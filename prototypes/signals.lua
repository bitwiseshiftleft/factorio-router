local protos = require "prototypes.router_proto_table"

if protos.enable_manual or protos.enable_smart then
    data:extend{
        {
            type="item-subgroup",
            name="router-signals",
            order="h[router-signals]",
            group="signals"
        },
        {
            type="virtual-signal",
            name="router-signal-default",
            subgroup="router-signals",
            order="h[router-signals]-a[default]",
            icon="__router__/graphics/default.png",
            icon_size=128,
            icon_mipmaps=3
        }
    }
end

if protos.enable_smart then
    data:extend{
        {
            type="virtual-signal",
            name="router-signal-link",
            subgroup="router-signals",
            order="h[router-signals]-b[link]",
            icon="__router__/graphics/connected.png",
            icon_size=128,
            icon_mipmaps=3
        },
        {
            type="virtual-signal",
            name="router-signal-leaf",
            subgroup="router-signals",
            order="h[router-signals]-c[leaf]",
            icon="__router__/graphics/leaf.png",
            icon_size=128,
            icon_mipmaps=3
        },
        {
            type="virtual-signal",
            name="router-signal-threshold",
            subgroup="router-signals",
            order="h[router-signals]-c[threshold]",
            icon="__router__/graphics/threshold.png",
            icon_size=128,
            icon_mipmaps=3
        }
    }
end