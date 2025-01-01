local migrate = require "lualib.migrate"
local create_router = require "lualib.create_router"

local function migrate_01x_to_02()
    local nsmart = 0
    local nio = 0
    for _,surface in pairs(game.surfaces) do
        for _,e in pairs(surface.find_entities_filtered{type="lamp"}) do
            if e.valid and create_router.is_router_smart(e) then
                migrate.rebuild_router_smart(e)
                nsmart = nsmart + 1
            elseif e.valid and create_router.is_router_io(e) then
                migrate.rebuild_router_io(e)
                nio = nio + 1
            end
        end
        for _,e in pairs(surface.find_entities_filtered{type="constant-combinator"}) do
            if e.valid and create_router.is_router_smart(e) then
                migrate.rebuild_router_smart(e)
                nsmart = nsmart + 1
            elseif e.valid and create_router.is_router_io(e) then
                migrate.rebuild_router_io(e)
                nio = nio + 1
            end
        end
    end

    if nsmart > 0 or nio > 0 then
        game.print("Circuit-Controlled Routers: Migrated " .. tostring(nsmart) .. " smart router(s) and " .. tostring(nio) .. " I/O points")
        game.print("Circuit-Controlled Routers: Note that the router control protocol has changed, which might disrupt any extra circuit control you're applying")
    end
end

migrate_01x_to_02()
