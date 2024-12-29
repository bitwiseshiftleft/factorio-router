local util = require "__core__.lualib.util"
local math2d = require "__core__.lualib.math2d"
local myutil = require "lualib.util"
local circuit = require "lualib.circuit"

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


local function name_or_ghost_name(entity)
    if entity.name == "entity-ghost" then
        return entity.ghost_name
    else
        return entity.name
    end
end

local function is_router_belt(entity) return string.find(entity.name, '^router%-component%-.*belt$') ~= nil end
local function is_router_loader(entity) return string.find(entity.name, '^router%-component%-.*loader$') ~= nil end
local function is_router_outer(entity) return string.find(entity.name, '^router%-.*router$') ~= nil end
local function is_router_smart(entity) return string.find(entity.name, '^router%-.*smart$') ~= nil end
local function is_router_io(entity)    return string.find(entity.name, '^router%-.*io$') ~= nil end
local function is_router_component(entity)  return string.find(entity.name, '^router%-component%-') ~= nil end
local function is_ghost_router_outer(entity) return string.find(entity.ghost_name, '^router%-.*router$') ~= nil end
local function is_ghost_router_smart(entity) return string.find(entity.ghost_name, '^router%-.*smart$') ~= nil end
local function is_ghost_router_io(entity)    return string.find(entity.ghost_name, '^router%-.*io$') ~= nil end
local function is_ghost_router_component(entity)       return string.find(name_or_ghost_name(entity), '^router%-component%-') ~= nil end
local function is_maybeghost_router_outer(entity)      return string.find(name_or_ghost_name(entity), '^router%-.*router$') ~= nil end
local function is_maybeghost_router_smart(entity)      return string.find(name_or_ghost_name(entity), '^router%-.*smart$') ~= nil end
local function is_maybeghost_router_io(entity)         return string.find(name_or_ghost_name(entity), '^router%-.*io$') ~= nil end
local function is_maybeghost_router_component(entity)  return string.find(name_or_ghost_name(entity), '^router%-component%-') ~= nil end
local visible_subentity_names = {
    ["router-component-port-trim-combinator"] = true,
    ["router-component-io-connection-lamp"] = true,
    ["router-component-smart-port-lamp"] = true,
    ["router-component-port-control-combinator"] = true
}
local function is_maybeghost_invisible_router_component(entity)
    if is_maybeghost_router_component(entity) then
        if is_maybeghost_router_smart(entity) then return false end
        if is_maybeghost_router_outer(entity) then return false end
        if is_maybeghost_router_io(entity) then return false end
        return not visible_subentity_names[name_or_ghost_name(entity)]
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
                    if not is_maybeghost_invisible_router_component(ent) then
                        table.insert(connector_table,{id,name_or_ghost_name(ent),ent.position,connid})
                    end
                end
            end
            if next(connector_table) then
                table.insert(undo_info, {name_or_ghost_name(ghost),ghost.position,connector_table})
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

-- Adjustments for outserters to output to different lanes
local lane_adj = {}
lane_adj[NORTH] = {x= 0.25,y=0}
lane_adj[SOUTH] = lane_adj[NORTH]
lane_adj[EAST]  = {x=0, y=0.25}
lane_adj[WEST]  = lane_adj[EAST]

local function fixup_loaders(surface, force, area, prefix, buffer)
    -- TODO
end

local function create_smart_router(prefix, entity, is_fast_replace, buffer)
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
            name = ("router-component-" .. dir ..
                    "-stack" .. tostring(stack_size) ..
                    "-" .. prefix .. "loader"),
            position = relative(ipt.b),
            direction = (my_orientation + ipt.d + tweak)%16,
            force = entity.force,
            fast_replace = is_fast_replace
        }
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
        fast_replace = is_fast_replace
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
        if is_router_io(router) then
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

local function create_smart_router_io(prefix, entity, is_fast_replace, n_lanes, buffer)
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

    local input_inserters = {}
    local n_inserters = 4

    for i=1,n_lanes do
        output_loaders[i] = entity.surface.create_entity{
            name = ("router-component-output-stack"
                    .. tostring(stack_size) ..
                    "-" .. prefix .. "loader"),
            position = relative({x=i-0.5,y=0}),
            direction = my_orientation,
            force = entity.force,
            fast_replace = is_fast_replace
        }
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
        fixup_loaders(entity.surface, entity.force, entity.bounding_box, prefix, nil)
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
    fixup_loaders(entity.surface, entity.force, entity.bounding_box, prefix, nil)
    bust_ghosts(entity)
end

-- If not nil: we think this is a fast upgrade
local fast_replace_state = nil
local function on_pre_build(args)
    fast_replace_state = {position=args.position, tick=args.tick, something_died_here = false}
end

local register_event, unregister_event
local undo_info_to_be_attached = {}

local function attach_undo_info(ev)
    -- Fires on the tick after any relevant undo-able event occurs
    -- attaches undo_info_to_be_attached to the undo stack

    for undoer,info in pairs(undo_info_to_be_attached) do
        local stack = game.players[undoer[1]].undo_redo_stack
        local name = undoer[2]
        local surface_index = undoer[3]
        local position = undoer[4]
        local found = false

        -- game.print("Adding undo information: "..serpent.line(info))
        for idx = 1,stack.get_undo_item_count() do
            local item = stack.get_undo_item(idx)
            for jdx,subitem in ipairs(item) do
                if subitem.type == "removed-entity"
                    and subitem.surface_index == surface_index
                    and subitem.target.name == name
                    and subitem.target.position.x == position.x
                    and subitem.target.position.y == position.y
                then
                    -- game.print("Found item at idx,jdx,info = "..serpent.line({idx,jdx,info}))
                    stack.set_undo_tag(idx, jdx, "router_restore_connections", info)
                    found = true
                end
            end
            if found then break end
        end
        -- if not found then
        --     game.print("Undo info not found: "..serpent.line({undoer,info})) -- TODO remove
        -- end
    end
    undo_info_to_be_attached = {} -- hopefully we attached them all?

    -- Remove ourselves until future undo-able events occur
    unregister_event(defines.events.on_tick, attach_undo_info)
end

local function add_undo_destroy_info(player_index, entity, undo_info)
    undo_info_to_be_attached[{player_index, name_or_ghost_name(entity), entity.surface.index, entity.position}] = undo_info
    register_event(defines.events.on_tick, attach_undo_info) -- to fire next tick
end

local function get_undo_restore_connections(subitem)
    if subitem.type ~= "removed-entity" then return {} end
    if subitem.tags and subitem.tags.router_restore_connections then
        -- normally they're stored in the tags
        return subitem.tags.router_restore_connections
    else
        -- possibly we are in the editor, and we have deleted the item but then undone it in the same tick
        -- check through the undo info not yet attached
        for undoer,info in pairs(undo_info_to_be_attached) do
            local name = undoer[2]
            local surface_index = undoer[3]
            local position = undoer[4]
            if subitem.surface_index == surface_index
                and subitem.target.name == name
                and subitem.target.position.x == position.x
                and subitem.target.position.y == position.y
            then return info end
        end
    end
    return {}
end

local function find_entity_or_ghost(surface,name,position,force)
    -- find an entity or ghost with the given parameters
    local search = surface.find_entities_filtered{
        ghost_name=name, position=position, force=force, limit=1
    }
    if search and search[1] then return search[1] end
    search = surface.find_entities_filtered{
        name=name, position=position, force=force, limit=1
    }
    if search and search[1] then return search[1] end
    return nil
end

local function on_undo_applied(ev)
    -- When an undo is applied, check whether it's a router being un-destroyed
    -- If so, then restore the router's subentities' connections
    local force = game.players[ev.player_index].force
    for idx,action in ipairs(ev.actions) do
        if action.type == "removed-entity" and action.surface_index ~= nil and game.surfaces[action.surface_index] then
            local surface = game.surfaces[action.surface_index]
            local child_ents = {}
            local info = get_undo_restore_connections(action)

            for idx,child in ipairs(info) do
                -- pre-create or find the child entities as ghosts, in case they are connected to each other
                child_ents[idx] = find_entity_or_ghost(surface,child[1],child[2],force)
                if not child_ents[idx] then
                    child_ents[idx] = surface.create_entity{
                        name="entity-ghost",
                        inner_name=child[1],
                        position=child[2],
                        surface=surface,
                        force=force
                    }
                end
            end
            -- game.print("Undo delete connections " .. serpent.line(info))

            for idx,child in ipairs(info) do
                -- attempt to find and connect the wire to the other entity
                local name      = child[1]
                local position  = child[2]
                local tab       = child[3]
                for _jdx,conn in ipairs(tab) do
                    local other_name = conn[2]
                    local other_position = conn[3]
                    local other_ent = find_entity_or_ghost(surface,other_name,other_position,force)
                    if other_ent then
                        child_ents[idx].get_wire_connector(conn[1],true).connect_to(
                            other_ent.get_wire_connector(conn[4],true)
                        )
                    end
                end
            end
        end
    end
end

local function on_marked_for_deconstruction(ev)
    if ev.player_index == nil then return end
    local entity = ev.entity
    if entity and entity.type ~= "entity-ghost" and (is_router_outer(entity) or is_router_smart(entity) or is_router_io(entity)) then
        local undo_info = {}
        for i,child in ipairs(entity.surface.find_entities_filtered{area=entity.bounding_box}) do
            if ev.player_index ~= nil and
                (   child.name == "router-component-io-connection-lamp"
                    or child.name == "router-component-smart-port-lamp")
            then
                -- add undo information
                local connector_table = {}
                for id,connector in pairs(child.get_wire_connectors(false)) do
                    for _,connection in pairs(connector.connections) do
                        local connid = connection.target.wire_connector_id
                        local ent = connection.target.owner
                        if not is_maybeghost_invisible_router_component(ent) then
                            table.insert(connector_table,{id,name_or_ghost_name(ent),ent.position,connid})
                        end
                    end
                end
                if next(connector_table) then
                    table.insert(undo_info, {name_or_ghost_name(child),child.position,connector_table})
                end
            end
        end
        add_undo_destroy_info(ev.player_index, entity, undo_info)
    end
end

local function on_died(ev, mined_by_robot)
    local entity = ev.entity
    local buffer = ev.buffer

    -- Is it a fast upgrade?
    local is_fast_replace = false
    if entity and fast_replace_state and fast_replace_state.tick == ev.tick
        and fast_replace_state.position.x == entity.position.x and fast_replace_state.position.y == entity.position.y
    then
        -- Fast upgraded by player
        is_fast_replace = true
    elseif mined_by_robot and entity.to_be_upgraded() then
        -- Fast-upgraded by a robot
        -- This probably hasn't already created fast_replace_state, so create it now
        is_fast_replace = true
        fast_replace_state = {tick = ev.tick, position = entity.position}
    end

    if entity and entity.type ~= "entity-ghost" and (is_router_outer(entity) or is_router_smart(entity) or is_router_io(entity)) then
        if is_fast_replace then
            fast_replace_state.something_died_here = true
            return -- TODO: is there anything to mine here?
        end

        local children = entity.surface.find_entities_filtered{area=entity.bounding_box}
        local undo_info = {}
        for i,child in ipairs(children) do
            if is_router_component(child) then
                -- First, try to mine its contents
                if buffer and string.match(child.name, "inserter$") ~= nil and child.held_stack.valid_for_read then
                    buffer.insert(child.held_stack)
                elseif buffer and (string.match(child.name, "transport%-belt$") ~= nil or string.match(child.name, "loader") ~= nil) then
                    for line_idx=1,2 do
                        local line = child.get_transport_line(line_idx)
                        for j=1,math.min(#line, 256) do
                            buffer.insert(line[j])
                        end
                        line.clear()
                    end
                elseif buffer and string.match(child.name, "router%-component%-container") ~= nil then
                    local inv = child.get_inventory(defines.inventory.chest)
                    for j=1,#inv do
                        buffer.insert(inv[j])
                    end
                elseif ev.player_index ~= nil and
                    (   child.name == "router-component-io-connection-lamp"
                     or child.name == "router-component-smart-port-lamp") then
                    -- add undo information
                    local connector_table = {}
                    for id,connector in pairs(child.get_wire_connectors(false)) do
                        for _,connection in pairs(connector.connections) do
                            local connid = connection.target.wire_connector_id
                            local ent = connection.target.owner
                            if not is_maybeghost_invisible_router_component(ent) then
                                table.insert(connector_table,{id,name_or_ghost_name(ent),ent.position,connid})
                            end
                        end
                    end
                    if next(connector_table) then
                        table.insert(undo_info, {name_or_ghost_name(child),child.position,connector_table})
                    end
                end
                child.destroy()
            end
        end
        if ev.player_index ~= nil then
            add_undo_destroy_info(ev.player_index, entity, undo_info)
        end
    elseif entity and entity.type == "entity-ghost" and (
        is_ghost_router_outer(entity)
        or is_ghost_router_io(entity)
        or is_ghost_router_smart(entity)
    ) then
        local undo_info = bust_ghosts(entity)
        if ev.player_index ~= nil then
            add_undo_destroy_info(ev.player_index, entity, undo_info)
        end
    end
end

local function on_robot_mined(ev)
    on_died(ev,true) -- If a robot mined it and it's marked for upgrade then we're upgrading
end

local function on_built(ev)
    local buffer = ev.buffer
    local entity = ev.created_entity
    if entity == nil then entity = ev.entity end

    -- game.print("build " .. entity.name.." "..tostring(entity.direction).." o "..tostring(entity.orientation) .. " @" .. entity.position.y)

    local is_fast_replace = false
    if fast_replace_state and fast_replace_state.tick == ev.tick and entity
        and fast_replace_state.position.x == entity.position.x and fast_replace_state.position.y == entity.position.y
    then
        is_fast_replace = fast_replace_state.something_died_here
    end

    if entity and entity.type ~= "entity-ghost" and is_router_outer(entity) then
        local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
        prefix = string.gsub(prefix, "router$", "")
        create_router(prefix, entity, is_fast_replace, buffer)
    elseif entity and entity.type ~= "entity-ghost" and is_router_smart(entity) then
        local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
        prefix = string.gsub(prefix, "smart$", "")
        create_smart_router(prefix, entity, is_fast_replace, buffer)
    elseif entity and entity.type ~= "entity-ghost" and is_router_io(entity) then
        local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
        prefix = string.gsub(prefix, "io$", "")
        create_smart_router_io(prefix, entity, is_fast_replace, buffer)
    elseif entity and entity.type ~= "entity-ghost" and (
            entity.type == "container" or entity.type == "logistic-container"
            or entity.type == "infinity-container" or entity.type == "linked-container"
    ) and settings.global["router-auto-connect"].value then
        -- Look for router IO points in a 1x1 wider radius around this
        local box = {
            left_top={
                x=entity.bounding_box.left_top.x-1,
                y=entity.bounding_box.left_top.y-1
            }, right_bottom={
                x=entity.bounding_box.right_bottom.x+1,
                y=entity.bounding_box.right_bottom.y+1
            }
        }
        autoconnect_router_io(entity.surface.find_entities_filtered{
            type="constant-combinator", -- autoconnect_router_io filters for the io points
            area=box,
            force=entity.force
        }, {entity})
    end
    fast_replace_state = nil -- we got the built event; clear it
end

local function on_rotated(ev)
    local entity = ev.entity
    -- game.print(entity.name.." "..tostring(entity.direction).." o "..tostring(entity.orientation)
    --     .. " p " .. tostring(ev.previous_direction))
    -- Rotating port control combinators: toggle whether the combinator sets DEFAULT
    if entity and entity.type ~= "entity-ghost" and entity.name == "router-component-port-control-combinator" then
        entity.orientation = 0 -- Nope, rotate it back
        -- First sum up the default signals
        local con = entity.get_or_create_control_behavior()
        local def = 0
        for i=1,con.signals_count do
            local sig = con.get_signal(i)
            if sig and sig.signal and sig.signal.type == circuit.DEFAULT.type
                   and sig.signal.name == circuit.DEFAULT.name then
                def = def + sig.count
                con.set_signal(i,nil)
            end
        end

        -- toggle.  If nonzero, well, we already cleared it
        if def % 0x100000000 == 0 then
            for i=1,con.signals_count do
                local sig = con.get_signal(i)
                if sig and sig.signal == nil then
                    con.set_signal(i,{signal=circuit.DEFAULT,count=1})
                    break
                end
            end
        end
    elseif entity and (
        entity.name == "router-component-port-trim-combinator"
        or (entity.type == "entity-ghost" and entity.ghost_name == "router-component-port-trim-combinator")) then
        -- Forbid rotation, so that the offset bounding box still works
        entity.direction = 0
        entity.orientation = 0
    -- elseif entity and entity.type ~= "entity-ghost" and is_router_belt(entity) then
        -- game.print("is belt")
        -- entity.direction = ev.previous_direction
    end
end

-- Cribbed from miniloaders event dispatcher
local handlers_for = {}
local function dispatch(event)
    for handler in pairs(handlers_for[event.name]) do
        handler(event)
    end
end

register_event = function(event, handler)
    local handlers = handlers_for[event]
    if not handlers then
      handlers = {}
      handlers_for[event] = handlers
    end

    if not next(handlers) then
      script.on_event(event, dispatch)
    end

    handlers[handler] = true
end

unregister_event = function(event, handler)
    local handlers = handlers_for[event]
    if not handlers then return end
    handlers[handler] = nil
    if not next(handlers) then
      script.on_event(event, nil)
    end
end

-- TODO:
-- Use event filters to reduce perf cost
--
-- On marked for deconstruction
-- On marked for upgrade
-- On rotate????? probably not
-- Blueprint stuff
-- On built, if connectors already built ...
--
-- TODO: when destroying and reviving, reconnect circuits
register_event(defines.events.on_built_entity, on_built)
register_event(defines.events.on_robot_built_entity, on_built)
register_event(defines.events.on_pre_build, on_pre_build)
register_event(defines.events.script_raised_built, on_built)
register_event(defines.events.script_raised_revive, on_built)

register_event(defines.events.on_entity_died, on_died)
register_event(defines.events.on_player_mined_entity, on_died)
register_event(defines.events.on_robot_mined_entity, on_robot_mined)
register_event(defines.events.script_raised_destroy, on_died)

register_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
register_event(defines.events.on_undo_applied, on_undo_applied)

-- register_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
register_event(defines.events.on_player_rotated_entity, on_rotated)

local function disable_picker_dollies()
    if remote.interfaces["PickerDollies"] and remote.interfaces["PickerDollies"]["add_blacklist_name"] then
        local to_blacklist = {
            "","fast-","express-","se-space-","se-deep-space","kr-advanced-","kr-superior-"
        }
        local sizes = { "4x4" }
        local suffixes = { "io", "smart", "router" }
        for _,prefix in ipairs(to_blacklist) do
            for _,size in ipairs(sizes) do
                for _,suffix in ipairs(suffixes) do
                    remote.call("PickerDollies", "add_blacklist_name", "router-"..size.."-"..prefix..suffix, true)
                end
            end
        end
        local others = {"port-control-combinator", "contents-indicator-lamp", "output-indicator-lamp",
            "is-default-lamp", "port-trim-combinator", "smart-port-lamp",
            "smart-io-indicator-lamp"}
        for _,other in ipairs(others) do
            remote.call("PickerDollies", "add_blacklist_name", "router-component-"..other, true)
        end
    end
end

local function init()
    disable_picker_dollies()
end

script.on_load(init)