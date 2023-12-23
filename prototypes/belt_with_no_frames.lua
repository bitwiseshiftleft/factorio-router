-- Based on code from bloodbelt by AliceCengal
-- https://github.com/AliceCengal/factorio-mod-bloodbelt

M = {}

local invisible_sprite = {
    filename    = "__router__/graphics/empty34.png",
    frame_count = 1,
    line_length = 1,
    priority    = "low",
    width       = 34,
    height      = 34,
    x           = 0,
    y           = 0,
    shift = {0,0}
  }

local invisible_sheet = {
    draw_as_shadow = true,
    filename = "__router__/graphics/empty34.png",
    frame_count = 1,
    height = 4,
    line_length = 1,
    priority = "low",
    scale = 0.5,
    shift = {0,0},
    variation_count = 7,
    width = 34
}

function create_belt(belt_type)
    local entity = table.deepcopy(data.raw["transport-belt"][belt_type])

    entity.name           = "router-component-"  .. belt_type
    entity.minable.result = nil
    entity.selectable_in_game = false
    entity.flags = { "not-rotatable", "not-blueprintable", "hidden" }
    entity.destructible = false
    entity.draw_circuit_wires = false

    local framesprites                    = table.deepcopy(entity.connector_frame_sprites)
    framesprites.frame_main.sheet         = invisible_sheet
    framesprites.frame_shadow.sheet       = invisible_sheet
    framesprites.frame_main_scanner       = invisible_sprite
    framesprites.frame_main_scanner_nw_ne = invisible_sprite
    framesprites.frame_main_scanner_sw_se = invisible_sprite
    framesprites.frame_back_patch         = nil
    framesprites.frame_front_patch        = nil
    entity.connector_frame_sprites      = framesprites

    local circuitsprites = table.deepcopy(entity.circuit_connector_sprites)
    for index,sprite in ipairs(circuitsprites) do
        sprite.connector_main     = nil
        sprite.connector_shadow   = nil
        sprite.wire_pins          = nil
        sprite.wire_pins_shadow   = nil
        sprite.led_blue_off       = nil
        sprite.frame_main_scanner = invisible_sprite
        sprite.led_red            = invisible_sprite
        sprite.led_green          = invisible_sprite
        sprite.led_blue           = invisible_sprite
        sprite.led_light          = { type="basic", intensity=0, size=0 }
    end
    entity.circuit_connector_sprites = circuitsprites

    entity.collision_mask = { "transport-belt-layer" }
    entity.next_upgrade = nil
    entity.fast_replaceable_group = "router-component-transport-belt"

    wirepoints = table.deepcopy(entity.circuit_wire_connection_points)
    for index,point in ipairs(wirepoints) do
        point.wire.red     = {0,0}
        point.shadow.red   = {0,0}
        point.wire.green   = {0,0}
        point.shadow.green = {0,0}
    end
    -- Remove excess wirepoints
    while #wirepoints > #circuitsprites do
        table.remove(wirepoints)
    end
    entity.circuit_wire_connection_points = wirepoints
    return entity
end

function create_underneathie(belt_type)
    local entity = table.deepcopy(data.raw["underground-belt"][belt_type])
    entity.name = "router-component-"  .. belt_type
    entity.max_distance = 0
    entity.minable.result = nil
    entity.selectable_in_game = false
    entity.flags = { "not-rotatable", "not-blueprintable", "hidden" }
    entity.destructible = false
    entity.collision_mask = { "transport-belt-layer" }
    entity.next_upgrade = nil
    entity.fast_replaceable_group = "router-component-underground-belt"
    return entity
end

M.create_belt = create_belt
M.create_underneathie = create_underneathie
return M