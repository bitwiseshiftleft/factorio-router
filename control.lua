local create_router = require "lualib.create_router"
local undo = require "lualib.undo"
local event = require "lualib.event"
local disable_picker_dollies = require "lualib.disable_picker_dollies"

-- If not nil: we think this is a fast upgrade
local fast_replace_state = nil
local function on_pre_build(args)
    fast_replace_state = {position=args.position, tick=args.tick, something_died_here = false}
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
            local info = undo.get_undo_restore_connections(action)

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
    if entity and entity.type ~= "entity-ghost" and (
        create_router.is_router_outer(entity) or create_router.is_router_smart(entity) or create_router.is_router_io(entity)
    ) then
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
                        if not create_router.is_maybeghost_invisible_router_component(ent) then
                            table.insert(connector_table,{id,name_or_ghost_name(ent),ent.position,connid})
                        end
                    end
                end
                if next(connector_table) then
                    table.insert(undo_info, {name_or_ghost_name(child),child.position,connector_table})
                end
            end
        end
        undo.add_undo_destroy_info(ev.player_index, entity, undo_info)
    end
end

local function on_died(ev, mined_by_robot)
    local entity = ev.entity or ev.ghost
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

    if entity and entity.type ~= "entity-ghost" and (
        create_router.is_router_outer(entity)
        or create_router.is_router_smart(entity)
        or create_router.is_router_io(entity)
    ) then
        if is_fast_replace then
            fast_replace_state.something_died_here = true
            return -- TODO: is there anything to mine here?
        end

        local children = entity.surface.find_entities_filtered{area=entity.bounding_box}
        local undo_info = {}
        for i,child in ipairs(children) do
            if create_router.is_router_component(child) then
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
                            if not create_router.is_maybeghost_invisible_router_component(ent) then
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
            undo.add_undo_destroy_info(ev.player_index, entity, undo_info)
        end
    elseif entity and entity.type == "entity-ghost" and (
        create_router.is_ghost_router_outer(entity)
        or create_router.is_ghost_router_io(entity)
        or create_router.is_ghost_router_smart(entity)
    ) then
        local undo_info = create_router.bust_ghosts(entity)
        if ev.player_index ~= nil then
            undo.add_undo_destroy_info(ev.player_index, entity, undo_info)
        end
    end
end

local function on_robot_mined(ev)
    on_died(ev,true) -- If a robot mined it and it's marked for upgrade then we're upgrading
end

local function on_built(ev)
    local entity = ev.created_entity
    if entity == nil then entity = ev.entity end

    -- game.print("build " .. entity.name.." "..tostring(entity.direction).." o "..tostring(entity.orientation) .. " @" .. entity.position.y)

    local is_fast_replace = false
    if fast_replace_state and fast_replace_state.tick == ev.tick and entity
        and fast_replace_state.position.x == entity.position.x and fast_replace_state.position.y == entity.position.y
    then
        is_fast_replace = fast_replace_state.something_died_here
    end

    if entity and entity.type ~= "entity-ghost" and create_router.is_router_outer(entity) then
        local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
        prefix = string.gsub(prefix, "router$", "")
        create_router.create_router(prefix, entity, is_fast_replace)
    elseif entity and entity.type ~= "entity-ghost" and create_router.is_router_smart(entity) then
        local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
        prefix = string.gsub(prefix, "smart$", "")
        create_router.create_smart_router(prefix, entity, is_fast_replace)
    elseif entity and entity.type ~= "entity-ghost" and create_router.is_router_io(entity) then
        local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
        prefix = string.gsub(prefix, "io$", "")
        create_router.create_smart_router_io(prefix, entity, is_fast_replace)
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
        create_router.autoconnect_router_io(entity.surface.find_entities_filtered{
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
local register_event = event.register_event
register_event(defines.events.on_built_entity, on_built)
register_event(defines.events.on_robot_built_entity, on_built)
register_event(defines.events.on_pre_build, on_pre_build)
register_event(defines.events.script_raised_built, on_built)
register_event(defines.events.script_raised_revive, on_built)

register_event(defines.events.on_entity_died, on_died)
register_event(defines.events.on_player_mined_entity, on_died)
register_event(defines.events.on_pre_ghost_deconstructed, on_died)
register_event(defines.events.on_robot_mined_entity, on_robot_mined)
register_event(defines.events.script_raised_destroy, on_died)

register_event(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
register_event(defines.events.on_undo_applied, on_undo_applied)

-- register_event(defines.events.on_entity_settings_pasted, on_settings_pasted)
register_event(defines.events.on_player_rotated_entity, on_rotated)


local function init()
    disable_picker_dollies.disable_picker_dollies()
end

script.on_load(init)