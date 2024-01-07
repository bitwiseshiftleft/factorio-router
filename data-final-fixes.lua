if mods["space-exploration"] then
    local se_data_util = require("__space-exploration__.data_util")
    -- Ban routers for being placed in space etc.
    for name, prototype in pairs(data.raw["constant-combinator"]) do
        if string.find(name, '^router%-.*router$') ~= nil
            or string.find(name, '^router%-.*smart$') ~= nil
            or string.find(name, '^router%-.*io$') ~= nil then
            se_data_util.collision_description(prototype)
        end
    end
end

if data.raw.lamp["router-component-smart-port-lamp"] then
    -- Done in here instead of in entities.lua so that Dectorio can't change it
    data.raw.lamp["router-component-smart-port-lamp"].signal_to_color_mapping = {
        {type="virtual",name="router-signal-link",color={r=0.65,b=1,g=0.8}},
        {type="virtual",name="router-signal-leaf",color={r=0.7,b=0.6,g=1}}
    }
end