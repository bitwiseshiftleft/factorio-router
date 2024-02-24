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

for _,d in ipairs{"router-component-smart-port-lamp","router-component-io-indicator-lamp"} do
    if data.raw.lamp[d] then
        -- Done in here instead of in entities.lua so that Dectorio can't change it
        data.raw.lamp[d].signal_to_color_mapping = {
            {type="virtual",name="router-signal-link",color={r=0.55,b=1,g=0.70}},
            {type="virtual",name="router-signal-leaf",color={r=0.4,b=0.3,g=1}}
        }
    end
end