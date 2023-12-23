local util = require"__core__.lualib.util"
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
    input  = {
        -- d = direction
        -- b = belt location
        -- i = inserter location
        {d=NORTH, b={x=2, y=3}, i={x=2,y=2}},
        {d=WEST,  b={x=3, y=1}, i={x=2,y=1}},
        {d=SOUTH, b={x=1, y=0}, i={x=1,y=1}},
        {d=EAST,  b={x=0, y=2}, i={x=1,y=2}}
    },
    output = {
        {d=SOUTH, b={x=1, y=3}, ind={x=1, y=3}, control={x=1, y=3}, pulse={x=0, y=3}, lamp={x=1.5, y=3}},
        {d=EAST,  b={x=3, y=2}, ind={x=3, y=2}, control={x=3, y=2}, pulse={x=3, y=3}, lamp={x=3, y=1.5}},
        {d=NORTH, b={x=2, y=0}, ind={x=2, y=0}, control={x=2, y=0}, pulse={x=3, y=0}, lamp={x=1.5, y=0}},
        {d=WEST,  b={x=0, y=1}, ind={x=0, y=1}, control={x=0, y=1}, pulse={x=0, y=0}, lamp={x=0, y=1.5}}
    }
}

local function is_router_outer(entity) return string.find(entity.name, '^router%-.*router$') ~= nil end
local function is_router_smart(entity) return string.find(entity.name, '^router%-.*smart$') ~= nil end
local function is_router_io(entity)    return string.find(entity.name, '^router%-.*io$') ~= nil end
local function is_router_component(entity)  return string.find(entity.name, '^router%-component%-') ~= nil end

local function vector_add(v1,v2) return {x=v1.x+v2.x, y=v1.y+v2.y} end
local function vector_sub(v1,v2) return {x=v1.x-v2.x, y=v1.y-v2.y} end

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

local function fixup_extra_inserters(surface, force, area, prefix, buffer)
    local multiplier = math.ceil(game.entity_prototypes[prefix.."transport-belt"].belt_speed * 8) - 1

    -- game.print("Multiplier = "..tostring(multiplier))
    
    local function idx(e)
        local ret = ""
        ret = ret .. tostring(e.position.x)..","
        ret = ret .. tostring(e.position.y)..","
        ret = ret .. tostring(e.pickup_position.x)..","
        ret = ret .. tostring(e.pickup_position.y)..","
        ret = ret .. tostring(e.drop_position.x)..","
        ret = ret .. tostring(e.drop_position.y)..","
        return ret
    end

    -- Inserter types we care about
    for _,name in ipairs{"router-component-inserter","router-component-nonf-inserter"} do
        local added = 0
        local extras = 0
        local removed =0
        local count_table = {}
        local entities = surface.find_entities_filtered{area=area,force=force,name=name}

        -- Count the entities with each pickup/dropoff position
        for _,e in ipairs(entities) do
            local the_idx = idx(e)
            if count_table[the_idx] ~= nil then
                count_table[the_idx].count = count_table[the_idx].count + 1
            else 
                count_table[the_idx] = {entity=e, count=1}
            end
        end

        -- Multiply the expected counts by the multiplier
        for _,j in pairs(count_table) do
            j.count = j.count*multiplier
        end
        
        -- Count the extras
        entities = surface.find_entities_filtered{force=force,area=area,name=name.."-extra"}

        -- Count the entities with each pickup/dropoff position
        for _,e in ipairs(entities) do
            local the_idx = idx(e)
            extras = extras + 1
            if count_table[the_idx] then
                if count_table[the_idx].count <= 0 then
                    -- We have too many of them ... destroy!
                    if buffer then buffer.insert(e.held_stack) end
                    e.destroy()
                    removed = removed + 1
                else
                    -- Just count down
                    count_table[the_idx].count = count_table[the_idx].count - 1
                end
            else
                -- What?  This shouldn't even be here...
                if buffer then buffer.insert(e.held_stack) end
                e.destroy()
                removed = removed + 1
            end
        end

        -- Create extra entities as necessary
        for the_idx,j in pairs(count_table) do
            for c=1,j.count do
                local ins = surface.create_entity({
                    name = name.."-extra",
                    position = j.entity.position,
                    force = force
                })
                for _,p in ipairs{"pickup_position","drop_position","inserter_stack_size_override"} do
                    ins[p] = j.entity[p]
                end
                if ins.filter_slot_count and ins.filter_slot_count > 0 then
                    ins.inserter_filter_mode = j.entity.inserter_filter_mode
                end
                local con1 = j.entity.get_or_create_control_behavior()
                local con2 = ins.get_or_create_control_behavior()
                for _,p in ipairs{
                    "circuit_mode_of_operation","circuit_read_hand_contents",
                    "circuit_hand_read_mode","circuit_set_stack_size","circuit_stack_control_signal"
                } do
                    if con1[p] then con2[p] = con1[p] end
                end

                added = added+1

                ins.connect_neighbour{wire=circuit.RED,  target_entity=j.entity}
                ins.connect_neighbour{wire=circuit.GREEN,target_entity=j.entity}
            end
        end
        -- game.print("Added "..tostring(added)..", found " .. tostring(extras)..", removed "..tostring(removed))
    end
end

-- Adjustments for outserters to output to different lanes
local lane_adj = {}
lane_adj[NORTH] = {x= 0.25,y=0}
lane_adj[SOUTH] = lane_adj[NORTH]
lane_adj[EAST]  = {x=0, y=0.25}
lane_adj[WEST]  = lane_adj[EAST]

local function create_router(prefix, entity, is_fast_replace, buffer)
    entity.operable = false -- disable its gui

    -- The tricky part: constructing the router
    local epos = entity.position
    local data = router_component_table
    local relative = relative_location(epos, entity.orientation, data)

    local input_ports = {}

    -- Create the input belts
    for i,ipt in ipairs(data.input) do
        input_ports[i] = entity.surface.create_entity({
            name = "router-component-" .. prefix .. "transport-belt",
            position = relative(ipt.b),
            direction = ipt.d,
            force = entity.force,
            fast_replace = is_fast_replace
        })
    end

    local passbands
    local contents_indicator
    if not is_fast_replace then
        -- Create the pass-band combinator network
        passbands = circuit.create_passband(builder, input_ports, #(data.output))

        -- Create the contents-nonempty indicator    
        contents_indicator = entity.surface.create_entity({
            name = "router-component-contents-indicator-lamp", position=vector_add(epos, data.contents_offset), force=entity.force
        })
        contents_indicator.connect_neighbour{wire=circuit.RED,  target_entity=passbands.indicator_combi, target_circuit_id=circuit.OUTPUT}
        contents_indicator.connect_neighbour{wire=circuit.GREEN,target_entity=passbands.indicator_combi, target_circuit_id=circuit.OUTPUT}
        contents_indicator.operable = false
    end

    for i,opt in ipairs(data.output) do
        -- Create the output belts
        local output_belt = entity.surface.create_entity({
            name = "router-component-" .. prefix .. "transport-belt",
            position = relative(opt.b),
            direction = opt.d,
            force = entity.force,
            fast_replace = is_fast_replace
        })

        if not is_fast_replace then
            -- Create indicator inserters
            local indicator_position = relative(opt.ind)
            local ins = entity.surface.create_entity({
                name = "router-component-indicator-inserter",
                position = indicator_position,
                force = entity.force
            })
            local control = ins.get_or_create_control_behavior()
            ins.pickup_position = epos
            ins.drop_position = epos
            ins.inserter_filter_mode = "whitelist"
            control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.set_filters

            ins.connect_neighbour{wire=circuit.RED,  target_entity=passbands.input_control[i],target_circuit_id=circuit.INPUT}
            ins.connect_neighbour{wire=circuit.GREEN,target_entity=passbands.input_control[i],target_circuit_id=circuit.INPUT}

            -- Create port control
            local control_combi = entity.surface.create_entity({
                name = "router-component-port-control-combinator",
                position = relative(opt.control),
                force = entity.force
            })
            control_combi.connect_neighbour{wire=circuit.RED,target_entity=ins}
            control_combi.connect_neighbour{wire=circuit.GREEN,target_entity=ins}

            -- Create output pulse interface
            local lamp_pulse = entity.surface.create_entity({
                name = "router-component-output-indicator-lamp",
                position = relative(opt.pulse),
                force = entity.force
            })
            lamp_pulse.operable = false -- disable its gui
            control = output_belt.get_or_create_control_behavior()
            control.enable_disable = false
            control.read_contents = true
            control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.pulse
            output_belt.connect_neighbour{wire=circuit.RED,target_entity=lamp_pulse}
            output_belt.connect_neighbour{wire=circuit.GREEN,target_entity=lamp_pulse}

            -- Create the movement inserters
            for j,ipt in ipairs(data.input) do
                for lane=1,2 do
                    -- Create and configure the inserter
                    ins = entity.surface.create_entity({
                        name = "router-component-inserter",
                        position = relative(ipt.i),
                        force = entity.force
                    })
                    ins.pickup_position = relative(ipt.b)
                    ins.inserter_stack_size_override = 1 -- TODO: but perf...
                    if lane==1 then
                        ins.drop_position = relative(vector_add(opt.b, lane_adj[opt.d]))
                    else
                        ins.drop_position = relative(vector_sub(opt.b, lane_adj[opt.d]))
                    end

                    control = ins.get_or_create_control_behavior()
                    ins.inserter_filter_mode = "whitelist"
                    control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.set_filters
                    -- control.circuit_read_hand_contents = true
                    -- control.circuit_hand_read_mode = defines.control_behavior.inserter.hand_read_mode.pulse

                    ins.connect_neighbour{wire=circuit.RED,   target_entity=passbands.output_dropoff[i], target_circuit_id=circuit.OUTPUT}
                    ins.connect_neighbour{wire=circuit.GREEN, target_entity=passbands.output_pickup[j],  target_circuit_id=circuit.OUTPUT}
                end
            end
        end
    end
    fixup_extra_inserters(entity.surface, entity.force, entity.bounding_box, prefix, buffer)
end

local function create_smart_router(prefix, entity, is_fast_replace, buffer)
    entity.operable = false -- disable its gui

    local epos = entity.position
    local data = router_component_table -- TODO: make multiple of these
    local builder=circuit.Builder:new(entity.surface,entity.position,entity.force)
    local relative = relative_location(epos, entity.orientation, data)
    local input_belts = {}
    local output_belts = {}
    
    local count_color_combi
    if not is_fast_replace then
        count_color_combi = builder:constant_combi{
            {signal=circuit.COUNT,count=2*circuit.DEMAND_FACTOR},
            {signal=circuit.LEAF, count=circuit.DEMAND_FACTOR}
        }
    end

    -- Create the input and output belts, and lamps
    for i,ipt in ipairs(data.input) do
        input_belts[i] = entity.surface.create_entity{
            name = "router-component-" .. prefix .. "transport-belt",
            position = relative(ipt.b),
            direction = ipt.d,
            force = entity.force,
            fast_replace = is_fast_replace
        }
    end
    for i,opt in ipairs(data.output) do
        output_belts[i] = entity.surface.create_entity{
            name = "router-component-" .. prefix .. "transport-belt",
            position = relative(opt.b),
            direction = opt.d,
            force = entity.force,
            fast_replace = is_fast_replace
        }

        local port = builder:create_or_find_entity{
            name = "router-component-smart-port-lamp",
            position = relative(opt.lamp)
        }
        port.operable = false -- disable its gui

        -- Light if the other port is on
        local control = port.get_or_create_control_behavior()
        control.use_colors = true
        control.circuit_condition = {condition = {comparator="!=",first_signal=circuit.COUNT,second_signal=circuit.LEAF}}
        output_belts[i].connect_neighbour{wire=circuit.GREEN, target_entity=port}
        if not is_fast_replace then
            port.connect_neighbour{wire=circuit.RED, target_entity=count_color_combi}
        end
    end

    -- Fast replace: all the electronics should exist: we're done here!
    -- TODO: make extra inserters / or cull
    if is_fast_replace then
        fixup_extra_inserters(entity.surface, entity.force, entity.bounding_box, prefix, buffer)
        return
    end

    -- Create the comms and port control network
    local passbands = circuit.create_smart_comms(builder, input_belts, output_belts)

    -- Create the movement inserters
    for i,opt in ipairs(data.output) do
        for j,ipt in ipairs(data.input) do
            for lane=1,2 do
                -- Create and configure the inserter
                ins = entity.surface.create_entity({
                    name = "router-component-inserter",
                    position = relative(ipt.i),
                    force = entity.force
                })
                ins.pickup_position = relative(ipt.b)
                ins.inserter_stack_size_override = 1 -- TODO: but perf...
                if lane==1 then
                    ins.drop_position = relative(vector_add(opt.b, lane_adj[opt.d]))
                else
                    ins.drop_position = relative(vector_sub(opt.b, lane_adj[opt.d]))
                end

                control = ins.get_or_create_control_behavior()
                ins.inserter_filter_mode = "whitelist"
                control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.set_filters
                -- control.circuit_read_hand_contents = true
                -- control.circuit_hand_read_mode = defines.control_behavior.inserter.hand_read_mode.pulse

                ins.connect_neighbour{wire=circuit.RED,   target_entity=passbands.output_dropoff[i], target_circuit_id=circuit.OUTPUT}
                ins.connect_neighbour{wire=circuit.GREEN, target_entity=passbands.output_pickup[j],  target_circuit_id=circuit.OUTPUT}
            end
        end
    end
    fixup_extra_inserters(entity.surface, entity.force, entity.bounding_box, prefix, buffer)
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
    
    local count_color_combi
    if not is_fast_replace then
        count_color_combi = builder:constant_combi{
            {signal=circuit.COUNT,count=circuit.DEMAND_FACTOR}
        }
    end
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
        input_belts[i] = entity.surface.create_entity{
            name = "router-component-" .. prefix .. "underground-belt",
            position = relative({x=0.5-i,y=0}),
            direction = opposite_orientation,
            force = entity.force,
            fast_replace = is_fast_replace,
            type = "input"
        }
    end

    -- Fast replace: all the electronics should exist: we're done here!
    -- TODO: make extra inserters / or cull
    if is_fast_replace then
        fixup_extra_inserters(entity.surface, entity.force, entity.bounding_box, prefix, nil)
        return
    end

    -- TODO: auto-connect on place
    local chest_inventory = builder:create_or_find_entity{
        name = "router-component-chest-contents-lamp",
        direction = orientation,
        position = relative({x=-n_lanes-0.3,y=0.2})
    }
    chest_inventory.get_or_create_control_behavior().circuit_condition = {
        condition = {comparator="=",first_signal=circuit.ZERO,second_signal=circuit.ZERO}
    }
    chest_inventory.operable = false
    local threshold_trim = builder:create_or_find_entity{
        name = "router-component-port-trim-combinator",
        direction = orientation,
        position = relative({x=n_lanes+0.3,y=0.2})
    }
    threshold_trim.get_or_create_control_behavior().set_signal(1,{signal=circuit.THRESHOLD,count=10})
    local port = builder:create_or_find_entity{
        name = "router-component-smart-port-lamp",
        direction = orientation,
        position = relative({x=0,y=0})
    }
    local control = port.get_or_create_control_behavior()
    control.use_colors = true
    control.circuit_condition = {condition = {comparator="!=",first_signal=circuit.COUNT,second_signal=circuit.LEAF}}
    if not is_fast_replace then
        port.connect_neighbour{wire=circuit.RED, target_entity=count_color_combi}
    end

    -- Create the comms and port control network
    local comm_circuit = circuit.create_smart_comms_io(
        entity, builder,chest_inventory,demand,threshold_trim
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
            ins.pickup_position = input_belts[i].position
            ins.inserter_stack_size_override = 1 -- TODO: but perf...
            ins.drop_position = relative({x=0.5-i,y=1}) -- box
            control = ins.get_or_create_control_behavior()
            control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.none
            control.circuit_read_hand_contents = true
            control.circuit_hand_read_mode = circuit.PULSE
            ins.connect_neighbour{wire=circuit.RED,target_entity=comm_circuit.input,target_circuit_id=circuit.INPUT}

            -- TODO: disable input inserters (and belt??) if not connected?
            -- Or route belt sideways (but draw sprites normally)
            -- Or just make the port bigger

            -- Output inserter
            ins = entity.surface.create_entity({
                name = "router-component-inserter",
                position = output_belts[i].position,
                force = entity.force
            })
            ins.pickup_position = relative({x=i-0.5,y=1})
            ins.inserter_stack_size_override = 1 -- TODO: but perf...
            ins.drop_position = relative({x=i+lane/2-1.25,y=0})
            control = ins.get_or_create_control_behavior()
            ins.inserter_filter_mode = "whitelist"
            control.circuit_read_hand_contents = true
            control.circuit_hand_read_mode = circuit.PULSE
            control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.set_filters
            ins.connect_neighbour{wire=circuit.GREEN, target_entity=comm_circuit.output, target_circuit_id=circuit.OUTPUT}
            ins.connect_neighbour{wire=circuit.RED,   target_entity=comm_circuit.outreg, target_circuit_id=circuit.INPUT}
        end
    end
    fixup_extra_inserters(entity.surface, entity.force, entity.bounding_box, prefix, nil)
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
                elseif buffer and string.match(child.name, "transport%-belt$") ~= nil then
                    for line_idx=1,2 do
                        local line = child.get_transport_line(line_idx)
                        for j=1,math.min(#line, 256) do
                            buffer.insert(line[j])
                        end
                        line.clear()
                    end
                end
                child.destroy()
            end
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
    end
    fast_replace_state = nil -- we got the built event; clear it
end

local function on_rotated(ev)
    local entity = ev.entity
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
