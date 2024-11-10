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
        {d=SOUTH, b={x=1, y=3}},
        {d=EAST,  b={x=3, y=2}},
        {d=NORTH, b={x=2, y=0}},
        {d=WEST,  b={x=0, y=1}}
    },
    lamp_distance = 0.86
}

local function is_router_belt(entity) return string.find(entity.name, '^router%-component%-.*belt$') ~= nil end
local function is_router_loader(entity) return string.find(entity.name, '^router%-component%-.*loader$') ~= nil end
local function is_router_outer(entity) return string.find(entity.name, '^router%-.*router$') ~= nil end
local function is_router_smart(entity) return string.find(entity.name, '^router%-.*smart$') ~= nil end
local function is_router_io(entity)    return string.find(entity.name, '^router%-.*io$') ~= nil end
local function is_router_component(entity)  return string.find(entity.name, '^router%-component%-') ~= nil end
local function is_ghost_router_outer(entity) return string.find(entity.ghost_name, '^router%-.*router$') ~= nil end
local function is_ghost_router_smart(entity) return string.find(entity.ghost_name, '^router%-.*smart$') ~= nil end
local function is_ghost_router_io(entity)    return string.find(entity.ghost_name, '^router%-.*io$') ~= nil end
local function is_ghost_router_component(entity)  return string.find(entity.ghost_name, '^router%-component%-') ~= nil end

local vector_add = myutil.vector_add
local vector_sub = myutil.vector_sub

local function bust_ghosts(entity)
    -- Delete all router component ghosts overlapping the entity.
    for _,ghost in ipairs(entity.surface.find_entities_filtered{
        area = entity.bounding_box,
        force = entity.force,
        type = "entity-ghost"
    }) do
        if string.find(ghost.ghost_name, '^router%-') then
            ghost.destroy()
        end
    end
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
    
    -- local count_color_combi
    -- if not is_fast_replace then
    --     count_color_combi = builder:constant_combi{
    --         {signal=circuit.COUNT,count=2*circuit.DEMAND_FACTOR},
    --         {signal=circuit.LEAF, count=circuit.DEMAND_FACTOR}
    --     }
    -- end

    -- Create the input and output belts and container
    local chest = surf.create_entity{
        name = "router-component-container-for-"..sz,
        position = epos,
        force = entity.force,
        fast_replace = is_fast_replace
    }

    local function mkbelt(ipt)
        local xb = surf.create_entity{
            name = "router-component-" .. prefix .. "transport-belt",
            position = relative(ipt.b),
            direction = (my_orientation + ipt.d)%16,
            force = entity.force,
            fast_replace = is_fast_replace
        }
        xb.rotatable = false
        return xb
    end

    local function mkldr(ipt,dir)
        local tweak = (dir == "input") and 8 or 0 -- because setting loader_type will reverse it
        local xb = surf.create_entity{
            name = "router-component-" .. dir .. "-" .. prefix .. "loader",
            position = relative(ipt.b),
            direction = (my_orientation + ipt.d + tweak)%16,
            force = entity.force,
            fast_replace = is_fast_replace
        }
        xb.rotatable = false
        xb.loader_type = dir
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

    -- Fast replace: all the electronics should exist: we're done here!
    if is_fast_replace then
        circuit.fixup_power_consumption(
            builder, entity,
            "router-component-"..prefix.."power-combinator-smart"
        )
        return
    end

    -- Create the comms and port control network
    circuit.create_smart_comms(builder, prefix, chest, input_belts, input_loaders, output_loaders)
    bust_ghosts(entity)
end

local function autoconnect_router_io(routers, chests)
    -- automatically connect each of the given routers to
    -- each of the given chests, as appropriate
    local router_tbl = {}
    for i,router in ipairs(routers) do
        if is_router_io(router) then
            table.insert(router_tbl,{
                router = router,
                inserters = router.surface.find_entities_filtered{
                    area = router.bounding_box,
                    name = "router-component-nonf-inserter"
                },
                outserters = router.surface.find_entities_filtered{
                    area = router.bounding_box,
                    name = "router-component-inserter"
                },
                connectors = router.surface.find_entities_filtered{
                    area = router.bounding_box,
                    name = "router-component-io-connection-lamp"
                }
            })
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
            for _,ins in ipairs(router.outserters) do
                if math2d.bounding_box.contains_point(chest.bounding_box, ins.pickup_position) then
                    do_connect = true
                    break
                end
            end
            if do_connect then
                for _,c in ipairs(router.connectors) do
                    c.connect_neighbour{target_entity=chest,wire=circuit.RED}
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
    local epos = entity.position
    local data = nil
    local builder=circuit.Builder:new(entity.surface,entity.position,entity.force)
    local relative = relative_location(epos, entity.orientation, data)
    
    local input_belts = {}
    local output_belts = {}
    local my_orientation = entity.orientation*8
    local opposite_orientation = (4+entity.orientation*8)%8

    for i=1,n_lanes do
        output_belts[i] = entity.surface.create_entity{
            name = "router-component-" .. prefix .. "underground-belt",
            position = relative({x=i-0.5,y=0}),
            direction = my_orientation,
            force = entity.force,
            fast_replace = is_fast_replace,
            type = "output"
        }
        output_belts[i].rotatable = false
        input_belts[i] = entity.surface.create_entity{
            name = "router-component-" .. prefix .. "underground-belt",
            position = relative({x=0.5-i,y=0}),
            direction = opposite_orientation,
            force = entity.force,
            fast_replace = is_fast_replace,
            type = "input"
        }
        input_belts[i].rotatable = false
    end

    -- Fast replace: all the electronics should exist: we're done here!
    if is_fast_replace then
        circuit.fixup_power_consumption(
            builder, entity,
            "router-component-"..prefix.."power-combinator-io"
        )
        fixup_loaders(entity.surface, entity.force, entity.bounding_box, prefix, nil)
        return
    end

    local threshold_trim = builder:create_or_find_entity{
        name = "router-component-port-trim-combinator",
        -- direction = my_orientation,
        position = relative({x=n_lanes-0.3,y=0})
    }
    threshold_trim.direction = 0.0 -- This is so that we can displace its selection box
    threshold_trim.get_or_create_control_behavior().set_signal(1,{signal=circuit.THRESHOLD,count=10})
    local port = builder:create_or_find_entity{
        name = "router-component-io-connection-lamp",
        direction = my_orientation,
        position = relative({x=0,y=0})
    }

    -- indicator lamp for condition of port
    local count_color_combi = builder:constant_combi{
        {signal=circuit.COUNT,count=circuit.DEMAND_FACTOR}
    }
    local indicator = builder:create_or_find_entity{
        name = "router-component-io-indicator-lamp",
        direction = my_orientation,
        position = relative({x=0,y=0})
    }
    indicator.connect_neighbour{target_entity=port,wire=circuit.GREEN}
    indicator.connect_neighbour{target_entity=count_color_combi,wire=circuit.RED}
    local control = indicator.get_or_create_control_behavior()
    control.use_colors = true
    control.circuit_condition = {condition = {comparator="!=",first_signal=circuit.COUNT,second_signal=circuit.LEAF}}

    -- Create the comms and port control network
    local comm_circuit = circuit.create_smart_comms_io(
        prefix, entity, builder,port,demand,threshold_trim,my_orientation
    )
    comm_circuit.outreg.connect_neighbour{wire=circuit.GREEN,source_circuit_id=circuit.OUTPUT,target_entity=port}

    -- Create the movement inserters
    for i=1,n_lanes do
        for lane=1,2 do
            -- Input inserter
            local ins = entity.surface.create_entity({
                name = "router-component-nonf-inserter",
                position = input_belts[i].position,
                force = entity.force
            })
            if ins.filter_slot_count and ins.filter_slot_count > 0 then
                -- FilterInsertersBegone, or some other mod, has replaced it with a filter inserter
                ins.inserter_filter_mode = "blacklist"
            end
            ins.pickup_position = input_belts[i].position
            ins.inserter_stack_size_override = 1 -- TODO: but perf...
            ins.drop_position = relative({x=0.5-i,y=1}) -- box
            control = ins.get_or_create_control_behavior()
            control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable
            control.circuit_condition = {condition={comparator="!=",first_signal=circuit.POWER}}
            control.circuit_read_hand_contents = true
            control.circuit_hand_read_mode = circuit.PULSE
            ins.connect_neighbour{wire=circuit.RED,target_entity=comm_circuit.input,target_circuit_id=circuit.INPUT}
            ins.connect_neighbour{wire=circuit.GREEN,target_entity=comm_circuit.power,target_circuit_id=circuit.OUTPUT}

            -- TODO: disable input inserters (and belt??) if not connected?
            -- Or route belt sideways (but draw sprites normally)
            -- Or just make the port bigger

            -- Output inserter
            ins = entity.surface.create_entity({
                name = "router-component-inserter",
                position = output_belts[i].position,
                force = entity.force
            })
            ins.pickup_position = relative{x=i-0.5,y=1}
            ins.inserter_stack_size_override = 1 -- TODO: but perf...
            ins.drop_position = relative{x=i+lane/2-1.25,y=0}
            control = ins.get_or_create_control_behavior()
            ins.inserter_filter_mode = "whitelist"
            control.circuit_read_hand_contents = true
            control.circuit_hand_read_mode = circuit.PULSE
            control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.set_filters
            ins.connect_neighbour{wire=circuit.GREEN, target_entity=comm_circuit.output, target_circuit_id=circuit.OUTPUT}
            ins.connect_neighbour{wire=circuit.RED,   target_entity=comm_circuit.outreg, target_circuit_id=circuit.INPUT}
        end
    end
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
        for i,child in ipairs(children) do
            if is_router_component(child) then
                -- First, try to mine its contents
                if buffer and string.match(child.name, "inserter$") ~= nil and child.held_stack.valid_for_read then
                    buffer.insert(child.held_stack)
                elseif buffer and (string.match(child.name, "transport%-belt$") ~= nil or string.match(child.name, "loader") ~= nil )then
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
                end
                child.destroy()
            end
        end
    elseif entity and entity.type == "entity-ghost" and (
        is_ghost_router_outer(entity)
        or is_ghost_router_io(entity)
        or is_ghost_router_smart(entity)
    ) then
        bust_ghosts(entity)
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

local function register_event(event, handler)
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

-- TODO:
-- Use event filters to avoid perf cost
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