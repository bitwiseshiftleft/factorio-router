local migrate = require "lualib.migrate"
local create_router = require "lualib.create_router"

local function migrate_027_to_028()
    local nio = 0
    local nsmart = 0
    for _,surface in pairs(game.surfaces) do
        for _,e in pairs(surface.find_entities_filtered{type="constant-combinator"}) do
            if e.valid and create_router.is_router_io(e) then
                migrate.rebuild_router_io(e)
                nio = nio + 1
            end
        end
        for _,e in pairs(surface.find_entities_filtered{type="lamp"}) do
            if e.valid and create_router.is_router_smart(e) then
                migrate.rebuild_router_smart(e)
                nsmart = nsmart + 1
            end
        end
    end

    if nio > 0 then
        game.print("Circuit-Controlled Routers: Adjusted " .. tostring(nsmart) .. " smart router(s) to add jam alerts, and " .. tostring(nio) .. " I/O points for power direction")
    end
end

migrate_027_to_028()
