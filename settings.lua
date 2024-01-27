data:extend{
    {
        type = "bool-setting",
        name = "router-enable-smart",
        setting_type = "startup",
        default_value = true
    },
    {
        type = "bool-setting",
        name = "router-enable-manual",
        setting_type = "startup",
        default_value = false
    },
    {
        type = "int-setting",
        name = "router-power-scale",
        setting_type = "startup",
        minimum_value = 0,
        maximum_value = 10000,
        default_value = 100
    },
    {
        type = "bool-setting",
        name = "router-enable-blinkenlights",
        setting_type = "startup",
        default_value = true
    },
}
