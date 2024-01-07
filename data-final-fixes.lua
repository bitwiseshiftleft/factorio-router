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
