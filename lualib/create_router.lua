local util = require "__core__.lualib.util"
local math2d = require "__core__.lualib.math2d"
local myutil = require "lualib.util"
local circuit = require "lualib.circuit"

local M = {}

local NORTH = defines.direction.north;
local SOUTH = defines.direction.south;
local EAST  = defines.direction.east;
local WEST  = defines.direction.west;

-- FUTURE: could have multiple shapes and look up in a table
local router_component_table = {
    offset = { x=-1.5, y=-1.5 },
    contents_offset = {x=0, y=0},
    combi_offset = {x=1, y=1},
    ibelts  = {
        -- d = direction, b = belt location
        {d=NORTH, b={x=2, y=3}},
        {d=WEST,  b={x=3, y=1}},
        {d=SOUTH, b={x=1, y=0}},
        {d=EAST,  b={x=0, y=2}}
    },
    iloaders = {
        -- d = direction, b = belt location
        {d=NORTH, b={x=2, y=2}},
        {d=WEST,  b={x=2, y=1}},
        {d=SOUTH, b={x=1, y=1}},
        {d=EAST,  b={x=1, y=2}}
    },
    xbelts  = {
        -- Nothing in the small version
    },
    oloaders = {
        -- d = direction, b = belt location
        {d=SOUTH, b={x=1, y=3}, lamp={x=1.5, y=2.3359375}},
        {d=EAST,  b={x=3, y=2}, lamp={x=2.3359375, y=1.5}},
        {d=NORTH, b={x=2, y=0}, lamp={x=1.5, y=0.6640625}},
        {d=WEST,  b={x=0, y=1}, lamp={x=0.6640625, y=1.5}}
    },
    lamp_distance = 0.86
}


M.is_router_belt                 = function(entity) return string.find(entity.name, '^router%-component%-.*belt$') ~= nil end
M.is_router_loader               = function(entity) return string.find(entity.name, '^router%-component%-.*loader$') ~= nil end
M.is_router_outer                = function(entity) return string.find(entity.name, '^router%-.*router$') ~= nil end
M.is_router_smart                = function(entity) return string.find(entity.name, '^router%-.*smart$') ~= nil end
M.is_router_io                   = function(entity) return string.find(entity.name, '^router%-.*io$') ~= nil end
M.is_router_component            = function(entity) return string.find(entity.name, '^router%-component%-') ~= nil end
M.is_ghost_router_outer          = function(entity) return string.find(entity.ghost_name, '^router%-.*router$') ~= nil end
M.is_ghost_router_smart          = function(entity) return string.find(entity.ghost_name, '^router%-.*smart$') ~= nil end
M.is_ghost_router_io             = function(entity) return string.find(entity.ghost_name, '^router%-.*io$') ~= nil end
M.is_ghost_router_component      = function(entity) return string.find(myutil.name_or_ghost_name(entity), '^router%-component%-') ~= nil end
M.is_maybeghost_router_outer     = function(entity) return string.find(myutil.name_or_ghost_name(entity), '^router%-.*router$') ~= nil end
M.is_maybeghost_router_smart     = function(entity) return string.find(myutil.name_or_ghost_name(entity), '^router%-.*smart$') ~= nil end
M.is_maybeghost_router_io        = function(entity) return string.find(myutil.name_or_ghost_name(entity), '^router%-.*io$') ~= nil end
M.is_maybeghost_router_component = function(entity) return string.find(myutil.name_or_ghost_name(entity), '^router%-component%-') ~= nil end
local visible_subentity_names = {
    ["router-component-port-trim-combinator"] = true,
    ["router-component-io-connection-lamp"] = true,
    ["router-component-smart-port-lamp"] = true,
    ["router-component-port-control-combinator"] = true
}
M.is_maybeghost_invisible_router_component = function(entity)
    if M.is_maybeghost_router_component(entity) then
        if M.is_maybeghost_router_smart(entity) then return false end
        if M.is_maybeghost_router_outer(entity) then return false end
        if M.is_maybeghost_router_io(entity) then return false end
        return not visible_subentity_names[myutil.name_or_ghost_name(entity)]
    end
    return false
end

local vector_add = myutil.vector_add
local vector_sub = myutil.vector_sub

local function bust_ghosts(entity)
    -- Delete all router component ghosts overlapping the entity.
    -- Return undo information
    local undo_info = {}
    for _,ghost in ipairs(entity.surface.find_entities_filtered{
        area = entity.bounding_box,
        force = entity.force,
        type = "entity-ghost"
    }) do
        if string.find(ghost.ghost_name, '^router%-') then
            local connector_table = {}
            for id,connector in pairs(ghost.get_wire_connectors(false)) do
                for _,connection in pairs(connector.connections) do
                    local connid = connection.target.wire_connector_id
                    local ent = connection.target.owner
                    if not M.is_maybeghost_invisible_router_component(ent) then
                        table.insert(connector_table,{id,myutil.name_or_ghost_name(ent),ent.position,connid})
                    end
                end
            end
            if next(connector_table) then
                table.insert(undo_info, {myutil.name_or_ghost_name(ghost),ghost.position,connector_table})
            end
            if ghost ~= entity then ghost.destroy() end
        end
    end
    -- game.print("Bust ghosts: return " .. serpent.line(undo_info))
    return undo_info
end

local function relative_location(epos, orientation, data)
    local re = ({[0]=1, [0.25]=0, [0.5]=-1, [0.75]=0})[orientation]
    local im = ({[0]=0, [0.25]=1, [0.5]=0, [0.75]=-1})[orientation]
    local data_offset = (data and data.offset) or {x=0,y=0}
    local function inner(obj_offset)
        local rel_offset = vector_add(obj_offset, data_offset)
        return {
            x=epos.x + re*rel_offset.x - im*rel_offset.y,
            y=epos.y + re*rel_offset.y + im*rel_offset.x
        }
    end
    return inner
end

local function create_smart_router(prefix, entity, is_fast_replace, is_migration)
    entity.operable = false -- disable its gui

    local sz = "4x4" -- TODO
    local epos = entity.position
    local surf = entity.surface
    local data = router_component_table -- TODO: make multiple of these
    local builder=circuit.Builder:new(entity.surface,entity.position,entity.force)
    local relative = relative_location(epos, entity.orientation, data)
    local my_orientation = entity.orientation*16
    local input_belts = {}
    local input_loaders = {}
    local output_loaders = {}
    local lamps = {}

    -- local count_color_combi
    -- if not is_fast_replace then
    --     count_color_combi = builder:constant_combi{
    --         {signal=circuit.COUNT,count=2*circuit.DEMAND_FACTOR},
    --         {signal=circuit.LEAF, count=circuit.DEMAND_FACTOR}
    --     }
    -- end

    local stack_size = 1+(entity.quality.level or 0)
    if not settings.startup["router-use-quality"].value then stack_size = 255 end

    local function mkbelt(ipt)
        local name = "router-component-" .. prefix .. "transport-belt"
        local xb = surf.create_entity{
            name = name,
            position = relative(ipt.b),
            direction = (my_orientation + ipt.d)%16,
            force = entity.force,
            fast_replace = is_fast_replace
        }
        if xb then
            xb.rotatable = false
            return xb
       else
            return surf.find_entities_filtered{
                name=name,
                position=relative(ipt.b),
                force=entity.force,
                limit=1
            }[1]
       end
            
    end

    local function mkldr(ipt,dir)
        local tweak = (dir == "input") and 8 or 0 -- because setting loader_type will reverse it
        local xb = surf.create_entity{
            name = ("router-component-" .. dir .. "-" .. prefix .. "loader"),
            position = relative(ipt.b),
            direction = (my_orientation + ipt.d + tweak)%16,
            force = entity.force,
            fast_replace = is_fast_replace
        }
        if dir == "output" then
            xb.loader_belt_stack_size_override = stack_size
        end
        if xb then
            xb.rotatable = false
            xb.loader_type = dir
        end
        return xb
    end

    for i,ipt in ipairs(data.ibelts) do
        input_belts[i] = mkbelt(ipt)
    end
    for i,extra in ipairs(data.xbelts) do
        input_belts[i] = mkbelt(extra)
    end
    for i,ild in ipairs(data.iloaders) do
        input_loaders[i] = mkldr(ild,"input")
    end
    for i,old in ipairs(data.oloaders) do
        output_loaders[i] = mkldr(old,"output")
    end

    local speed_rel_yellowbelt = 32*input_belts[1].prototype.belt_speed
    local jam_scale = speed_rel_yellowbelt * stack_size

    ----------------------------------------------------------------------
    -- If fast replace: all the electronics should exist.
    -- Fix up the power consumption and jam scale, and we're done!
    ----------------------------------------------------------------------
    if is_fast_replace then
        circuit.fixup_power_consumption(
            builder, entity,
            "router-component-"..sz.."-"..prefix.."power-combinator-smart"
        )
        circuit.set_jam_scale(builder, entity,jam_scale)
        return
    end

    -- Create the input and output belts and container
    local chest = surf.create_entity{
        name = "router-component-container-for-"..sz,
        position = epos,
        force = entity.force,
        fast_replace = is_fast_replace or is_migration
    }

    -- Create port lamps
    for i,old in ipairs(data.oloaders) do
        local lamp = builder:create_or_find_entity{
            name = "router-component-smart-port-lamp",
            position = relative(old.lamp)
        }
        lamp.operable = false -- disable its gui
        lamps[i] = lamp
    end

    -- Create the comms and port control network
    circuit.create_smart_comms(builder, prefix, chest, input_belts, input_loaders, output_loaders, lamps, jam_scale, sz, entity.quality)
    bust_ghosts(entity)
end

local function autoconnect_router_io(routers, chests)
    -- automatically connect each of the given routers to
    -- each of the given chests, as appropriate
    local router_tbl = {}
    for i,router in ipairs(routers) do
        if M.is_router_io(router) then
            local tmp = {
                router = router,
                inserters = router.surface.find_entities_filtered{
                    area = router.bounding_box,
                    name = "router-component-nonf-inserter"
                },
                outserters = router.surface.find_entities_filtered{
                    area = router.bounding_box,
                    type = "loader-1x1"
                },
                connectors = router.surface.find_entities_filtered{
                    area = router.bounding_box,
                    name = "router-component-io-connection-lamp"
                }
            }
            table.insert(router_tbl,tmp)
            for _,ldr in ipairs(tmp.outserters) do
                ldr.update_connections() -- else loader_container isn't ready yet
            end
        end
    end
    for _,chest in ipairs(chests) do
        -- lazy logic: connect the chest if its bounding box contains the inserters drop points
        -- or the outserters pickup points
        for _,router in ipairs(router_tbl) do
            local do_connect = false
            for _,ins in ipairs(router.inserters) do
                if math2d.bounding_box.contains_point(chest.bounding_box, ins.drop_position) then
                    do_connect = true
                    break
                end
            end
            for _,ldr in ipairs(router.outserters) do
                if ldr.loader_container == chest then
                    do_connect = true
                    break
                end
            end
            if do_connect then
                for _,c in ipairs(router.connectors) do
                    c.get_wire_connector(circuit.RED,true).connect_to(chest.get_wire_connector(circuit.RED,true))
                end
            end
        end
    end
end

local function create_smart_router_io(prefix, entity, is_fast_replace, n_lanes)
    -- entity.operable = false -- Nope, GUI is enabled
    -- TODO: custom GUI?
    entity.rotatable = false

    n_lanes = n_lanes or 1
    local sz = "4x4"
    local epos = entity.position
    local data = nil
    local builder=circuit.Builder:new(entity.surface,entity.position,entity.force)
    local relative = relative_location(epos, entity.orientation, data)
    
    local input_belts = {}
    local output_loaders = {}
    local my_orientation = entity.orientation*16
    local opposite_orientation = (8+entity.orientation*16)%16
    local stack_size = 1+(entity.quality.level or 0)
    if not settings.startup["router-use-quality"].value then stack_size = 255 end

    local input_inserters = {}
    local n_inserters = 4

    for i=1,n_lanes do
        output_loaders[i] = entity.surface.create_entity{
            name = ("router-component-output"..
                    "-" .. prefix .. "loader"),
            position = relative({x=i-0.5,y=0}),
            direction = my_orientation,
            force = entity.force,
            fast_replace = is_fast_replace
        }
        output_loaders[i].loader_belt_stack_size_override = stack_size
        if output_loaders[i] then
            output_loaders[i].rotatable = false
        end
        input_belts[i] = entity.surface.create_entity{
            name = "router-component-" .. prefix .. "transport-belt",
            position = relative({x=0.5-i,y=0}),
            direction = opposite_orientation,
            force = entity.force,
            fast_replace = is_fast_replace
        }
        if input_belts[i] then
            input_belts[i].rotatable = false
        end
    end

    -- Fast replace: all the electronics should exist: we're done here!
    if is_fast_replace then
        circuit.fixup_power_consumption(
            builder, entity,
            "router-component-"..sz.."-"..prefix.."power-combinator-io"
        )
        -- fixup_loaders(entity.surface, entity.force, entity.bounding_box, prefix, nil)
        return
    end

    for i=1,n_lanes do
        for count=1,n_inserters do
            -- Input inserter
            -- Just make a few of them because I can't be bothered to make an updater
            -- FUTURE: use input loaders?  But can't read belt contents
            local ins = entity.surface.create_entity({
                name = "router-component-nonf-inserter",
                position = input_belts[i].position,
                force = entity.force
            })
            ins.pickup_position = input_belts[i].position
            ins.inserter_stack_size_override = 4 -- because perf I guess
            ins.drop_position = relative({x=0.5-i,y=1}) -- box
            table.insert(input_inserters,ins)
        end
    end

    local threshold_trim = builder:create_or_find_entity{
        name = "router-component-port-trim-combinator",
        -- direction = my_orientation,
        position = relative({x=n_lanes-0.3,y=0})
    }
    threshold_trim.direction = 0.0 -- This is so that we can displace its selection box
    threshold_trim.get_or_create_control_behavior().get_section(1).
        set_slot(1,{value=util.merge{circuit.THRESHOLD,{comparator="=",quality="normal"}},min=10})
    local port = builder:create_or_find_entity{
        name = "router-component-io-connection-lamp",
        direction = my_orientation,
        position = relative({x=0,y=0})
    }
    local indicator = builder:create_or_find_entity{
        name = "router-component-io-indicator-lamp",
        direction = my_orientation,
        position = relative({x=0,y=0})
    }
    port.operable = false -- disable its gui
    indicator.operable = false

    -- Create the comms and port control network
    circuit.create_smart_comms_io(
        builder,sz,prefix,entity,
        input_belts,input_inserters,output_loaders,
        port,indicator,threshold_trim
    )
    
    if settings.global["router-auto-connect"].value then
        local p1 = relative{x=n_lanes-0.5,y=1}
        local p2 = relative{x=0.5-n_lanes,y=1}
        local box = {
            left_top={x=math.min(p1.x,p2.x),y=math.min(p1.y,p2.y)},
            right_bottom={x=math.max(p1.x,p2.x),y=math.max(p1.y,p2.y)}
        }
        autoconnect_router_io({entity},entity.surface.find_entities_filtered{
            type="container",
            area=box,
            force=entity.force
        })
    end
    -- fixup_loaders(entity.surface, entity.force, entity.bounding_box, prefix, nil)
    bust_ghosts(entity)
end

M.create_smart_router = create_smart_router
M.create_smart_router_io = create_smart_router_io
M.autoconnect_router_io = autoconnect_router_io
M.bust_ghosts = bust_ghosts

return M
