local create_router = require "lualib.create_router"
local math2d = require "__core__.lualib.math2d"

local M = {}

local function insert_or_spill(surface, force, position, chests, stack)
    -- insert items into one of the listed chests, or spill them onto the ground at the given location
    local c1 = stack.count
    for _,chest in ipairs(chests) do
        local inventory = chest.get_inventory(defines.inventory.chest)
        local c2 = inventory.insert(stack)
        c1 = c1-c2
        if c1 <= 0 then break end
        stack.count = c1
    end
    if c1 > 0 then
        surface.spill_item_stack{
            position=position,
            stack=stack,
            force=force,
            enable_looted=true,
            allow_belts=false,
            use_start_position_on_failure=true
        }
    end
end

local function clean_out_router_for_rebuild(entity, chests)
    -- remove all non-interface router components of `entity`
    -- Try to insert them into the given inventories, or spill them onto the ground if not
    local surface = entity.surface
    local force = entity.force
    local position = entity.position

    -- find and destroy all children, putting their hand contents into the buffer
    local children = entity.surface.find_entities_filtered{area=entity.bounding_box}
    for _,child in ipairs(children) do
        if child ~= entity and create_router.is_router_component(child) then
            -- inserters and belts get their items transfered to the chest
            if child.type == "inserter" then
                insert_or_spill(surface,force,position,chests,child.held_stack)
            elseif child.type == "transport-belt"
                or child.type == "underground-belt"
                or child.type == "loader-1x1"  then
                for line_idx=1,2 do
                    local line = child.get_transport_line(line_idx)
                    for j=1,math.min(#line, 256) do
                        insert_or_spill(surface,force,position,chests,line[j])
                    end
                    line.clear()
                end
            end
            local is_in_chests = false
            for _,chest in ipairs(chests) do
                is_in_chests = is_in_chests or child == chest
            end
            if      child.name ~= "router-component-smart-port-lamp"
                and child.name ~= "router-component-io-connection-lamp"
                and child.name ~= "router-component-port-trim-combinator"
                and not is_in_chests then
                -- the lamps, trim combinators and their connections can stay
                child.destroy()
            end
        end
    end
end

local function adjust_stack_sizes(entity)
    -- fix all the output loader stack sizes in `entity`
    if not script.feature_flags.space_travel then return end
    local care_about_quality = settings.startup["router-use-quality"].value
    -- Try to insert them into the given inventories, or spill them onto the ground if not
    local surface = entity.surface
    local force = entity.force
    local position = entity.position
    local stack_size = care_about_quality and 1+(entity.quality.level or 0) or 255

    -- find and destroy all children, putting their hand contents into the buffer
    local children = entity.surface.find_entities_filtered{area=entity.bounding_box}
    for _,child in ipairs(children) do
        if child ~= entity and create_router.is_router_component(child) then
            if child.type == "loader" and string.find(child.name, '^router%-component%-output') ~= nil then
                child.loader_belt_stack_size_override = stack_size
            end
        end
    end
end

-- can be run on_configuration_changed
local function migrate_all_stack_sizes()
    if not script.feature_flags.space_travel then return end
    local nio = 0
    local nsmart = 0
    for _,surface in pairs(game.surfaces) do
        for _,e in pairs(surface.find_entities_filtered{type="constant-combinator"}) do
            if e.valid and create_router.is_router_io(e) then
                adjust_stack_sizes(e)
            end
        end
        for _,e in pairs(surface.find_entities_filtered{type="lamp"}) do
            if e.valid and create_router.is_router_smart(e) then
                adjust_stack_sizes(e)
            end
        end
    end
end

local function rebuild_router_smart(entity)
    -- create the chest first so that we can transfer inventory
    local sz = "4x4" -- FUTURE
    local chest = entity.surface.create_entity{
        name = "router-component-container-for-"..sz,
        position = entity.position,
        force = entity.force,
        fast_replace = true
    }

    -- remove all the internal components and items
    clean_out_router_for_rebuild(entity, {chest})

    -- rebuild it
    local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
    prefix = string.gsub(prefix, "smart$", "")
    create_router.create_smart_router(prefix, entity, false, true)
end

local function rebuild_router_io(entity)
    -- create the chest first so that we can transfer inventory
    local sz = "4x4" -- FUTURE

    -- grab a list of the router's inserters and loaders
    local inserters = entity.surface.find_entities_filtered{
        area=entity.bounding_box, type="inserter"
    }
    local loaders = entity.surface.find_entities_filtered{
        area = entity.bounding_box, type="loader-1x1"
    }

    -- find chests
    local chests = {}
    local box = {
        left_top={
            x=entity.bounding_box.left_top.x-1,
            y=entity.bounding_box.left_top.y-1
        }, right_bottom={
            x=entity.bounding_box.right_bottom.x+1,
            y=entity.bounding_box.right_bottom.y+1
        }
    }
    for _,chest in ipairs(entity.surface.find_entities_filtered{
        type="container", area=box, force=entity.force
    }) do
        local attached = false
        for _,ins in ipairs(inserters) do
            attached = (attached
                or math2d.bounding_box.contains_point(chest.bounding_box, ins.drop_position)
                or math2d.bounding_box.contains_point(chest.bounding_box, ins.pickup_position)
            )
        end
        for _,ldr in ipairs(loaders) do
            attached = (attached or ldr.loader_container == chest)
        end
        if attached then table.insert(chests,chest) end
    end

    -- remove all the internal components and items
    clean_out_router_for_rebuild(entity, chests)

    -- rebuild it
    local prefix = string.gsub(entity.name, "^router%-.x.%-", "")
    prefix = string.gsub(prefix, "io$", "")
    create_router.create_smart_router_io(prefix, entity, false)
end

M.insert_or_spill = insert_or_spill
M.rebuild_router_io = rebuild_router_io
M.rebuild_router_smart = rebuild_router_smart
M.adjust_stack_sizes = adjust_stack_sizes
M.migrate_all_stack_sizes = migrate_all_stack_sizes
return M
