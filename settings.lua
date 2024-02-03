data:extend{
    {
        type = "bool-setting",
        name = "router-enable-manual",
        setting_type = "startup",
        default_value = false,
        order = "a"
    },
    {
        type = "bool-setting",
        name = "router-enable-smart",
        setting_type = "startup",
        default_value = true,
        order = "b"
    },
    {
        type = "bool-setting",
        name = "router-auto-connect",
        setting_type = "runtime-global",
        default_value = true,
        order = "b"
    },
    {
        type = "int-setting",
        name = "router-power-scale",
        setting_type = "startup",
        minimum_value = 0,
        maximum_value = 10000,
        default_value = 100,
        order = "c"
    },
    {
        type = "bool-setting",
        name = "router-enable-blinkenlights",
        setting_type = "startup",
        default_value = true,
        order = "d"
    },
}
