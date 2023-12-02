local belt_with_no_frames = require "prototypes.belt_with_no_frames" 

local empty_sheet = {
    filename = "__router__/graphics/empty1.png",
    priority = "very-low",
    width = 1,
    height = 1,
    frame_count = 1
}
local empty_sheet_32 = {
    filename = "__router__/graphics/empty32.png",
    priority = "very-low",
    width = 1,
    height = 1,
    frame_count = 1
}
local empty_sheet_128 = {
    filename = "__router__/graphics/empty128.png",
    priority = "very-low",
    width = 1,
    height = 1,
    frame_count = 1
}
local empty_sheet_4_128 = { north=empty_sheet_128, south=empty_sheet_128, east=empty_sheet_128, west=empty_sheet_128 }
local empty_sheet_4 = { north=empty_sheet, south=empty_sheet, east=empty_sheet, west=empty_sheet }

local function mk_empty(color,size)
    return {
        filename = "__router__/graphics/empty" .. color .. size .. ".png",
        priority = "very-low",
        width = size,
        height = size,
        frame_count = 1
    }
end
local empty_red = mk_empty("red",1)
local empty_green16 = mk_empty("green",16)
local empty_green_sheet_32 = {
    filename = "__router__/graphics/emptygreen128.png",
    priority = "very-low",
    width = 32,
    height =32,
    frame_count = 1
}
local empty_green_sheet_128 = {
    filename = "__router__/graphics/emptygreen128.png",
    priority = "very-low",
    width = 128,
    height =128,
    frame_count = 1
}
local empty_green_sheet_4_128 = { north=empty_green_sheet_128, south=empty_green_sheet_128, east=empty_green_sheet_128, west=empty_green_sheet_128 }
local wow = {
    filename = "__router__/graphics/wow.png",
    priority = "very-low",
    width = 128,
    height =128,
    frame_count = 1
}
local wow_4 = { north=wow, south=wow, east=wow, west=wow }
local light_off = {
    filename = "__router__/graphics/light.png",
    priority = "very-low",
    width = 32,
    height =32,
    frame_count = 1
}
local light_on = {
    filename = "__router__/graphics/light.png",
    priority = "very-low",
    width = 32,
    height =32,
    x = 32,
    frame_count = 1
}

local connector_definitions = circuit_connector_definitions.create(
  universal_connector_template,
  {
    { variation = 24, main_offset = {0.5,0.5}, shadow_offset = {0.5,0.5}, show_shadow = false },
    { variation = 24, main_offset = {0.5,0.5}, shadow_offset = {0.5,0.5}, show_shadow = false },
    { variation = 24, main_offset = {0.5,0.5}, shadow_offset = {0.5,0.5}, show_shadow = false },
    { variation = 24, main_offset = {0.5,0.5}, shadow_offset = {0.5,0.5}, show_shadow = false },
  }
)

local hidden_combinator = {
    destructible = false,
    max_health = 1,
    flags = { "hidden", "not-blueprintable", "hide-alt-info" },
    selectable_in_game = false,
    energy_source = {type = "void"},
    active_energy_usage = "1J",
    collision_box = {{0,0},{0,0}},
    collision_mask = {},
    input_connection_bounding_box = {{0,0},{0,0}},
    output_connection_bounding_box = {{0,0},{0,0}},
    activity_led_offsets = {},
    rotatable = false,
    draw_circuit_wires = false,
    sprites = empty_sheet_4,
    input_connection_points = connector_definitions.points,
    output_connection_points = connector_definitions.points,
    circuit_connector_sprites = connector_definitions.sprites,
    activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} },
    activity_led_sprites = empty_sheet_4,
    screen_light_offsets = { {0,0},{0,0},{0,0},{0,0} },
    circuit_wire_max_distance = 9
}

function merge_tables(t1,t2)
    t1 = util.table.deepcopy(t1)
    for x,y in pairs(t2) do t1[x] = y end
    return t1
end

local hidden_arith = merge_tables(hidden_combinator,{
    type = "arithmetic-combinator",
    name = "router-component-arithmetic-combinator"
})
local hidden_decider = merge_tables(hidden_combinator,{
    type = "decider-combinator",
    name = "router-component-decider-combinator"
})

-- Prototype base for hidden widgets
local hidden_widget_proto = {
    flags = { "hidden", "not-blueprintable", "hide-alt-info", "placeable-off-grid" },
    destructible = false,
    max_health = 1,
    rotatable = false,
	minable = nil,
    selectable_in_game = false,
    collision_box = {{-0.3,-0.3},{0.3,0.3}},
    selection_box = {{-0.3,-0.3},{0.3,0.3}},
    collision_mask = {},
    draw_circuit_wires = false
}

-- Prototype base for interface combinators
local control_combinator_proto = {
    type = "constant-combinator",
    flags = { "placeable-off-grid", "player-creation" },
    destructible = false,
    max_health = 1,
	minable = nil,
    allow_copy_paste = true,
    selectable_in_game = true,
    selection_priority = 70,
    collision_box = {{-0.5,-0.5},{0.5,0.5}},
    selection_box = {{-0.5,-0.5},{0.5,0.5}},
    collision_mask = {},
    circuit_wire_max_distance = 16,
}

local interface_lamp_proto = {
    type = "lamp",
    flags = { "placeable-off-grid", "player-creation" },
    collision_box = {{-0.5,-0.5},{0.5,0.5}},
    selection_box = {{-0.5,-0.5},{0.5,0.5}},
    collision_mask = {},
    allow_copy_paste = true,
    selectable_in_game = true,
    selection_priority = 70,
    energy_source = { type = "void", },
    minable = nil,
    energy_usage_per_tick = "1J",
    circuit_wire_max_distance = 16,
    glow_size = 0
}

-- Super inserter
local super_inserter = merge_tables(hidden_widget_proto,{
    type = "inserter",
    name = "router-component-inserter",
    hand_base_picture = empty_sheet,
    hand_open_picture = empty_sheet,
    hand_closed_picture = empty_sheet,
    allow_custom_vectors = true,
    energy_per_movement = "1J",
    energy_per_rotation = "1J",
    energy_source = { type = "void", }, -- TODO: require power
    extension_speed = 1,
    rotation_speed = 2,
    pickup_position = {0, 0},
    insert_position = {0, 0},
    filter_count = 5,
    draw_held_item = false,
    draw_inserter_arrow = false,
    draw_circuit_wires = false,
    circuit_wire_max_distance = 9,
    platform_picture = {sheets={empty_sheet_32}}
})

local indicator_inserter = merge_tables(super_inserter,{
    name = "router-component-indicator-inserter",
    flags = { "hidden", "not-blueprintable" },
    energy_source = { type = "void", },
    filter_count = 4
})

-- generate base storehouse and warehouse
data:extend({

    -- Hidden control combinator
    merge_tables(control_combinator_proto,{
        type = "constant-combinator",
        name = "router-component-port-control-combinator",
        item_slot_count = 20,
        sprites = empty_sheet_4,
        circuit_wire_connection_points = connector_definitions.points,
        circuit_connector_sprites = connector_definitions.sprites,
        circuit_wire_max_distance = 4,
        activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} },
        fast_replaceable_group = "router-component-port-control-combinator"
    }),

    merge_tables(control_combinator_proto,{
        type = "constant-combinator",
        name = "router-component-hidden-constant-combinator",
        flags = { "hidden", "not-blueprintable", "hide-alt-info", "placeable-off-grid" },
        selectable_in_game = false,
        item_slot_count = 20,
        sprites = empty_sheet_4,
        circuit_wire_connection_points = connector_definitions.points,
        circuit_connector_sprites = connector_definitions.sprites,
        circuit_wire_max_distance = 4,
        draw_circuit_wires = false,
        activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} }
    }),

    -- Smart port control lamp
    merge_tables(interface_lamp_proto,{
        name = "router-component-smart-port-lamp",
        picture_off = light_off,
        picture_on = merge_tables(light_on,{apply_runtime_tint=true}),
        signal_to_color_mapping = {
            {type="virtual",name="router-signal-link",color={r=0.65,b=1,g=0.8}},
            {type="virtual",name="router-signal-leaf",color={r=0.7,b=0.6,g=1}}
        },
        fast_replaceable_group = "router-component-smart-port-lamp"
    }),

    -- Contents lamp
    merge_tables(interface_lamp_proto,{
        name = "router-component-contents-indicator-lamp",
        picture_off = empty_sheet_128,
        picture_on = empty_sheet_128,
        always_on = true
    }),

    -- Output lamp
    merge_tables(interface_lamp_proto,{
        name = "router-component-output-indicator-lamp",
        picture_off = empty_sheet_128,
        picture_on = empty_sheet_128,
        always_on = true
    }),

    -- Super inserters
    super_inserter, indicator_inserter,

    -- Hidden combinators
    hidden_arith, hidden_decider
})

function create_belt_components(prefix)
    data:extend({belt_with_no_frames.create_belt(prefix.."transport-belt")})
end

function create_router(size,prefix,tint)
    create_belt_components(prefix)
    -- doodad is a constant combinator that can't have wires connected to it

    local base_underground_item = data.raw["transport-belt"][prefix .. "transport-belt"]
    local next_upgrade = base_underground_item and base_underground_item.next_upgrade
    if next_upgrade then
        next_upgrade = string.gsub(next_upgrade, "-?transport%-belt$", "")
    end

    local fake_combinator = {
        type = "constant-combinator",
        flags = { "player-creation", "hide-alt-info" },
		max_health = 40,
        rotatable = true,
        item_slot_count = 0,
		collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
		selection_box = {{-1.9, -1.9}, {1.9, 1.9}},
        selection_priority = 30,
        selectable_in_game = true,
        circuit_wire_connection_points = connector_definitions.points,
        circuit_connector_sprites = connector_definitions.sprites,
        circuit_wire_max_distance = 0,
        activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} }
    }

    local wow_smart = {
        layers = {{
            filename = "__router__/graphics/wow-smart.png",
            priority = "very-low",
            width = 256,
            height =256,
            scale = 0.5,
            frame_count = 1
        },{
            filename = "__router__/graphics/wow-smart.png",
            priority = "very-low",
            width = 256,
            height =256,
            scale = 0.5,
            x = 0,
            y = 256,
            frame_count = 1,
            tint = tint
        }}
    }
    -- -- (don't) make it invisible to see hidden graphics issues
    -- local wow_smart = empty_sheet_128 
	data:extend({merge_tables(fake_combinator,{
		name = "router-"..size.."-"..prefix.."router",
        minable = { mining_time = 4, result = "router-"..size.."-"..prefix.."router" },
        sprites = {north=wow,south=wow,west=wow,east=wow},
        icons = {
            {icon="__router__/graphics/router-icon.png", icon_size=128,},
            {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint}
        },
        fast_replaceable_group = "router-"..size.."-router",
        next_upgrade = next_upgrade and ("router-" ..size.."-".. next_upgrade .. "-router")
    }),merge_tables(fake_combinator,{
		name = "router-"..size.."-"..prefix.."smart",
        minable = { mining_time = 4, result = "router-"..size.."-"..prefix.."smart" },
        sprites = {north=wow_smart,south=wow_smart,west=wow_smart,east=wow_smart},
        icons = {
            {icon="__router__/graphics/router-icon.png", icon_size=128,},
            {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint},
            {icon="__router__/graphics/router-icon-ring.png", icon_size=128, tint=tint}
        },
        fast_replaceable_group = "router-"..size.."-smart",
        next_upgrade = next_upgrade and ("router-" ..size.."-".. next_upgrade .. "-smart")
    })})
end

create_router("4x4","",util.color("ffc340D1"))
create_router("4x4","fast-",util.color("e31717D1"))
create_router("4x4","express-",util.color("43c0faD1"))
