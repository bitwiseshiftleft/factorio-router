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

function create_belt(belt_type,postfix)
    local postfix = postfix or ""
    local entity = table.deepcopy(data.raw["transport-belt"][belt_type .. postfix])

    entity.name           = "router-component-"  .. belt_type
    entity.minable = nil
    entity.selectable_in_game = false
    entity.flags = { "not-rotatable", "not-blueprintable" }
    entity.hidden = true
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

    entity.collision_mask = {layers={transport_belt=true}}
    entity.next_upgrade = nil
    entity.fast_replaceable_group = "router-component-transport-belt"
    entity.se_allow_in_space = true

    return entity
end

function LEGACY_create_underneathie(belt_type,postfix)
    local postfix = postfix or ""
    local entity = table.deepcopy(data.raw["underground-belt"][belt_type .. postfix])
    entity.name = "router-component-"  .. belt_type
    entity.max_distance = 0
    entity.minable = nil
    entity.selectable_in_game = false
    entity.flags = { "not-rotatable", "not-blueprintable" }
    entity.hidden = true
    entity.destructible = false
    entity.collision_mask = {layers={transport_belt=true}}
    entity.next_upgrade = nil
    entity.fast_replaceable_group = "router-component-underground-belt"
    return entity
end

M.create_belt = create_belt
M.create_underneathie = LEGACY_create_underneathie
return M