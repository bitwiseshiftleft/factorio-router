local util = require "__core__.lualib.util"
local myutil = require "lualib.util"
local protos = require "prototypes.router_proto_table"
local belt_with_no_frames = require "prototypes.belt_with_no_frames" 

local empty_sheet = util.empty_sprite(1)
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
    tint = {1,.35,.25},
    frame_count = 1,
    shift = util.by_pixel(0,-28),
    scale = 0.5,
    draw_as_glow = true
}
local light_on = {
    filename = "__router__/graphics/light.png",
    priority = "very-low",
    width = 32,
    height =32,
    frame_count = 1,
    shift = util.by_pixel(0,-28),
    scale = 0.5,
    draw_as_glow = true
}

local function mk_io_sprites(tint)
    local file = "__router__/graphics/io-entity.png"
    local ns = {filename=file,priority="very-low",width=320,height=160,scale=0.5,frame_count=1}
    local ew = {filename=file,priority="very-low",width=256,height=256,scale=0.5,frame_count=1}
    return {
        south = {layers = {
            util.merge{ns,{shift=util.by_pixel(16,-18),x=0,y=0}},
            util.merge{ns,{shift=util.by_pixel(16,-18),x=0,y=160,tint=tint}},
            util.merge{ns,{shift=util.by_pixel(16,-18),x=0,y=320,draw_as_shadow=true}},
            util.merge{ns,{shift=util.by_pixel(16,-18),x=0,y=480,draw_as_glow=true}},
        }},
        north = {layers = {
            util.merge{ns,{shift=util.by_pixel(16,-10),x=320,y=0}},
            util.merge{ns,{shift=util.by_pixel(16,-10),x=320,y=160,tint=tint}},
            util.merge{ns,{shift=util.by_pixel(16,-10),x=320,y=320,draw_as_shadow=true}},
            util.merge{ns,{shift=util.by_pixel(16,-10),x=320,y=480,draw_as_glow=true}},
        }}, 
        east = {layers = {
            util.merge{ew,{shift=util.by_pixel(0,-10),x=896,y=128}},
            util.merge{ew,{shift=util.by_pixel(0,-10),x=896,y=384,tint=tint}},
            util.merge{ew,{shift=util.by_pixel(0,-10),x=640,y=128,draw_as_shadow=true}},
            util.merge{ew,{shift=util.by_pixel(0,-10),x=640,y=384,draw_as_glow=true}},
        }}, 
        west = {layers = {
            util.merge{ew,{shift=util.by_pixel(0,-10),x=1408,y=128}},
            util.merge{ew,{shift=util.by_pixel(0,-10),x=1408,y=384,tint=tint}},
            util.merge{ew,{shift=util.by_pixel(0,-10),x=1152,y=128,draw_as_shadow=true}},
            util.merge{ew,{shift=util.by_pixel(0,-10),x=1152,y=384,draw_as_glow=true}},
        }}, 
    }
end

local connector_definitions = circuit_connector_definitions.create(
  universal_connector_template,
  {
    { variation = 24, main_offset = {0,0}, shadow_offset = {0,0}, show_shadow = false },
    { variation = 24, main_offset = {0,0}, shadow_offset = {0,0}, show_shadow = false },
    { variation = 24, main_offset = {0,0}, shadow_offset = {0,0}, show_shadow = false },
    { variation = 24, main_offset = {0,0}, shadow_offset = {0,0}, show_shadow = false },
  }
)
local connector_definitions2 = circuit_connector_definitions.create(
  universal_connector_template,
  {
    { variation = 24, main_offset = {-1.2,-0.5}, shadow_offset = {-1.2,-0.5}, show_shadow = false },
    { variation = 24, main_offset = {0.5,0.4}, shadow_offset = {0.5,0.4}, show_shadow = false },
    { variation = 24, main_offset = {1.5,-0.4}, shadow_offset = {1.5,-0.4}, show_shadow = false },
    { variation = 24, main_offset = {0.2,0.5}, shadow_offset = {0.2,0.5}, show_shadow = false },
  }
)

local hidden_combinator = {
    destructible = false,
    max_health = 1,
    flags = { "hidden", "not-blueprintable", "hide-alt-info", "placeable-off-grid", "not-on-map" },
    selectable_in_game = false,
    energy_source = {type = "void"},
    active_energy_usage = "1J",
    collision_box = {{-0.1,-0.1},{0.1,0.1}},
    selection_box = {{-0.1,-0.1},{0.1,0.1}},
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
    activity_led_hold_time = 60,
    circuit_wire_max_distance = 9
}

-- Blinkenlights version of combinator
local blinkensprites = {
    north = {
        filename = "__router__/graphics/blinken.png",
        priority = "very-low",
        width = 3, height = 3, scale=0.5,
        shift = util.by_pixel(9,-13),
        tint = {0.3,0.8,0.1,1}
    },
    south = {
        filename = "__router__/graphics/blinken.png",
        priority = "very-low",
        width = 3, height = 3, scale=0.5,
        shift = util.by_pixel(9,-13),
        tint = {0.3,0.7,0.1,1}
    },
    east = {
        filename = "__router__/graphics/blinken.png",
        priority = "very-low",
        width = 3, height = 3, scale=0.5,
        shift = util.by_pixel(9,-13),
        tint = {0.2,0.8,0.1,1}
    },
    west = {
        filename = "__router__/graphics/blinken.png",
        priority = "very-low",
        width = 3, height = 3, scale=0.5,
        shift = util.by_pixel(9,-13),
        tint = {0.8,0.8,0.6,1}
    },
}
local hidden_combinator_blinkenlights = util.merge{hidden_combinator,{}}
if settings.startup["router-enable-blinkenlights"].value then
    hidden_combinator_blinkenlights.activity_led_sprites = blinkensprites
end

local hidden_arith = util.merge{hidden_combinator,{
    type = "arithmetic-combinator",
    name = "router-component-arithmetic-combinator"
}}
local hidden_decider = util.merge{hidden_combinator,{
    type = "decider-combinator",
    name = "router-component-decider-combinator"
}}

local hidden_arith_blinken = util.merge{hidden_combinator_blinkenlights,{
    type = "arithmetic-combinator",
    name = "router-component-arithmetic-combinator-blinken"
}}
local hidden_decider_blinken = util.merge{hidden_combinator_blinkenlights,{
    type = "decider-combinator",
    name = "router-component-decider-combinator-blinken"
}}

-- Prototype base for hidden widgets
local hidden_widget_proto = {
    flags = { "hidden", "not-blueprintable", "hide-alt-info", "placeable-off-grid", "not-on-map" },
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
    flags = { "placeable-off-grid", "player-creation", "not-on-map", "hide-alt-info" },
    destructible = false,
    max_health = 1,
	minable = nil,
    allow_copy_paste = true,
    selectable_in_game = true,
    selection_priority = 70,
    collision_box = {{-0.45,-0.45},{0.45,0.45}},
    selection_box = {{-0.5,-0.5},{0.5,0.5}},
    collision_mask = {},
    circuit_wire_max_distance = 16,
}

local interface_lamp_proto = {
    type = "lamp",
    flags = { "placeable-off-grid", "player-creation", "not-on-map" },
    collision_box = {{-0.45,-0.45},{0.45,0.45}},
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
local super_inserter = util.merge{hidden_widget_proto,{
    type = "inserter",
    name = "router-component-inserter",
    hand_base_picture   = util.empty_sprite(1),
    hand_open_picture   = util.empty_sprite(1),
    hand_closed_picture = util.empty_sprite(1),
    hand_base_shadow    = nil,
    hand_open_shadow    = nil,
    hand_closed_shadow  = nil,
    allow_custom_vectors = true,
    energy_per_movement = "1J",
    energy_per_rotation = "1J",
    energy_source = { type = "void", },
    extension_speed = 2,
    rotation_speed = 2,
    pickup_position = {0, 0},
    insert_position = {0, 0},
    draw_held_item = false,
    draw_inserter_arrow = false,
    circuit_wire_max_distance = 9,
    chases_belt_frames = false,
    stack_size_bonus = 0,
    platform_picture = empty_sheet_4
}}
local super_inserter_nonfilter = util.merge{super_inserter,{
    name = "router-component-nonf-inserter"
}}
super_inserter.filter_count = 5

-- These are the same but for "extra" inserters on super-fast belts
local super_inserter_2 = util.merge{super_inserter,{
    name = "router-component-inserter-extra"
}}
local super_inserter_nonfilter_2 = util.merge{super_inserter_nonfilter,{
    name = "router-component-nonf-inserter-extra"
}}

local indicator_inserter = util.merge{super_inserter,{
    name = "router-component-indicator-inserter",
    flags = { "hidden", "not-blueprintable", "not-on-map" },
    energy_source = { type = "void", },
    filter_count = 4
}}

if protos.enable_manual or protos.enable_smart then
    -- Common elements
    data:extend{
        -- Hidden control combinator
        util.merge{control_combinator_proto,{
            type = "constant-combinator",
            name = "router-component-hidden-constant-combinator",
            flags = { "hidden", "not-blueprintable", "hide-alt-info", "placeable-off-grid", "not-on-map" },
            selectable_in_game = false,
            item_slot_count = 20,
            sprites = empty_sheet_4,
            circuit_wire_connection_points = connector_definitions.points,
            circuit_connector_sprites = connector_definitions.sprites,
            circuit_wire_max_distance = 4,
            draw_circuit_wires = false,
            activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} }
        }},

        -- Hidden combinators
        hidden_arith, hidden_decider,
        hidden_arith_blinken, hidden_decider_blinken,

        -- Super filter inserters
        super_inserter, super_inserter_2
    }
end

if protos.enable_manual then
    data:extend{
        -- Non-hidden control combinator
        util.merge{control_combinator_proto,{
            type = "constant-combinator",
            name = "router-component-port-control-combinator",
            item_slot_count = 20,
            sprites = empty_sheet_4,
            circuit_wire_connection_points = connector_definitions.points,
            circuit_connector_sprites = connector_definitions.sprites,
            circuit_wire_max_distance = 9,
            activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} },
            fast_replaceable_group = "router-component-port-control-combinator"
        }},

        -- Contents lamp
        util.merge{interface_lamp_proto,{
            name = "router-component-contents-indicator-lamp",
            picture_off = util.empty_sprite(1),
            picture_on = util.empty_sprite(1),
            always_on = true
        }},

        -- Output lamp
        util.merge{interface_lamp_proto,{
            name = "router-component-output-indicator-lamp",
            picture_off = util.empty_sprite(1),
            picture_on = util.empty_sprite(1),
            always_on = true
        }},

        indicator_inserter
    }
end

if protos.enable_smart then
    local trimpoint = {
        wire = { red={0,-0.40}, green={0,-0.35} },
        shadow = { red={0.08,-0.35}, green={0.08,-0.30} },
    }
    data:extend{
        -- Smart port control lamp
        util.merge{interface_lamp_proto,{
            name = "router-component-smart-port-lamp",
            picture_off = light_off,
            picture_on = util.merge{light_on,{apply_runtime_tint=true}},
            -- Done in data-final-fixes so that Dectorio and similar can't change it
            -- signal_to_color_mapping = {
            --     {type="virtual",name="router-signal-link",color={r=0.65,b=1,g=0.8}},
            --     {type="virtual",name="router-signal-leaf",color={r=0.7,b=0.6,g=1}}
            -- },
            selection_box = {{-0.5,-1.26},{0.5,-0.26}},
            circuit_wire_connection_point = {
                wire = { red={0,-0.64}, green={0,-0.64} },
                shadow = { red={0.08,-0.56}, green={0.08,-0.56} },
            },
            icon = "__router__/graphics/connected.png", icon_size=128,
            fast_replaceable_group = "router-component-smart-port-lamp"
        }},
        -- IO port lamp.  Invisible but can be interacted with.
        util.merge{interface_lamp_proto,{
            picture_off = util.empty_sprite(1),
            picture_on = util.empty_sprite(1),
            name = "router-component-io-connection-lamp",
            fast_replaceable_group = "router-component-io-connection-lamp",
            selection_box = {{-0.5,-1.1},{0.5,-0.1}},
            circuit_wire_connection_point = {
                wire = { red={0,-0.40}, green={0,-0.35} },
                shadow = { red={0.08,-0.35}, green={0.08,-0.30} },
            },
            icon = "__router__/graphics/leaf.png", icon_size=128,
        }},
        -- IO indicator lamp.  Visible but cannot be interacted with
        util.merge{interface_lamp_proto,{
            name = "router-component-io-indicator-lamp",
            selectable_in_game = false,
            draw_circuit_wires=false,
            picture_off = util.merge{light_off,{shift=util.by_pixel(0,-21)}},
            picture_on = util.merge{light_on,{apply_runtime_tint=true,shift=util.by_pixel(0,-21)}},
            -- Done in data-final-fixes so that Dectorio and similar can't change it
            -- signal_to_color_mapping = {
            --     {type="virtual",name="router-signal-link",color={r=0.65,b=1,g=0.8}},
            --     {type="virtual",name="router-signal-leaf",color={r=0.7,b=0.6,g=1}}
            -- },
        }},
        -- TODO: make sprites for this
        util.merge{interface_lamp_proto,{
            name = "router-component-is-default-lamp",
            selectable_in_game = false,
            picture_off = util.empty_sprite(1),
            picture_on = util.empty_sprite(1), -- TODO
        }},
        -- I/O point trim control
        util.merge{control_combinator_proto,{
            type = "constant-combinator",
            name = "router-component-port-trim-combinator",
            selection_box = {{-0.25,-0.65},{0.25,-0.15}},
            item_slot_count = 20,
            sprites = empty_sheet_4,
            rotatable = false,
            circuit_wire_connection_points = {
                north=trimpoint, south=trimpoint, east=trimpoint, west=trimpoint
            },
            circuit_connector_sprites = connector_definitions.sprites,
            circuit_wire_max_distance = 9,
            activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} },
            fast_replaceable_group = "router-component-port-control-combinator",
            icon = "__router__/graphics/threshold.png", icon_size=128,
        }},
        super_inserter_nonfilter, super_inserter_nonfilter_2
    }
end

local function create_belt_components(prefix,postfix)
    data:extend({belt_with_no_frames.create_belt(prefix.."transport-belt",postfix)})
end

local function create_underground_components(prefix,postfix)
    data:extend({belt_with_no_frames.create_underneathie(prefix.."underground-belt",postfix)})
end

if mods["space-exploration"] then
    empty_space_collision_layer = collision_mask_util_extended.get_make_named_collision_mask("empty-space-tile")
    space_collision_layer = collision_mask_util_extended.get_make_named_collision_mask("space-tile")
    spaceship_collision_layer = collision_mask_util_extended.get_make_named_collision_mask("moving-tile")
end

local function create_router(size,prefix,tint,next_upgrade,is_space,postfix,power)
    create_belt_components(prefix,postfix)
    -- doodad is a constant combinator that can't have wires connected to it

    local base_underground_item = data.raw["transport-belt"][prefix .. "transport-belt"..postfix]
    local base_name = base_underground_item.localised_name or {"entity-name."..base_underground_item.name}
    local space = (is_space and "space-") or ""

    local holding_entity_as_combinator = {
        type = "constant-combinator",
        flags = { "player-creation", "hide-alt-info" },
		max_health = 40,
        rotatable = true,
        item_slot_count = 0,
		collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
		selection_box = {{-2, -2}, {2, 2}},
        selection_priority = 30,
        selectable_in_game = true,
        circuit_wire_connection_points = connector_definitions.points,
        circuit_connector_sprites = connector_definitions.sprites,
        circuit_wire_max_distance = 0,
        activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} }
    }

    local holding_entity_as_lamp = {
        type = "lamp",
        flags = { "player-creation", "hide-alt-info" },
		max_health = 40,
        always_on = true,
        energy_source = { type = "void", },
        energy_usage_per_tick = "1J",
		collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
		selection_box = {{-2, -2}, {2, 2}},
        selection_priority = 30,
        selectable_in_game = true,
        circuit_wire_max_distance = 0,
        circuit_wire_connection_points = { wire={}, shadow={}},
        activity_led_light_offsets = { {0,0},{0,0},{0,0},{0,0} }
    }
    if is_space then
        holding_entity_as_combinator.collision_mask = {"player-layer", "water-tile", empty_space_collision_layer, spaceship_collision_layer}
    elseif mods["space-exploration"] then
        -- Not placeable in space
        holding_entity_as_combinator.collision_mask = {"player-layer", "water-tile", empty_space_collision_layer, space_collision_layer, spaceship_collision_layer}
    end

    local filename_smart = "__router__/graphics/router-entity.png"
    local function frame(args)
        args.y = args.y * 320
        return util.merge{{
            filename = filename_smart,
            priority = "very-low",
            width  = 416,
            height = 320,
            scale  = 0.5,
            shift = util.by_pixel(16,16),
            frame_count = 1
        }, args}
    end

    local sprite_smart = {
        layers = {
            frame{y=0},
            frame{y=1, tint=tint},
            frame{y=2, draw_as_shadow=true},
            frame{y=3, draw_as_glow=true}
        }
    }

    if protos.enable_manual then
        local power_manual = math.floor(power)
        data:extend{util.merge{holding_entity_as_combinator,{
            name = "router-"..size.."-"..prefix.."router",
            minable = { mining_time = 4, result = "router-"..size.."-"..prefix.."router" },
            sprites = {north=wow,south=wow,west=wow,east=wow},
            icons = {
                {icon="__router__/graphics/router-icon.png", icon_size=128,},
                {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint}
            },
            fast_replaceable_group = "router-"..space..size.."-router",
            next_upgrade = next_upgrade and ("router-" ..size.."-".. next_upgrade .. "router"),
            se_allow_in_space = is_space,
            localised_description = {
                "router-templates.router-template",
                base_name,
                myutil.format_power(power_manual*1000)
            }
        }}}
    end
    if protos.enable_smart then
        local power_smart = math.floor(power)
        local power_io = math.floor(power/4)
        create_underground_components(prefix,postfix)
        data:extend{util.merge{holding_entity_as_lamp,{
            name = "router-"..size.."-"..prefix.."smart",
            minable = { mining_time = 4, result = "router-"..size.."-"..prefix.."smart" },
            picture_on = sprite_smart,
            picture_off = sprite_smart,
            icons = {
                {icon="__router__/graphics/router-icon.png", icon_size=128,},
                {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint}
            },
            map_color = {r=0.91,g=0.72,b=0.36},
            fast_replaceable_group = "router-"..space..size.."-smart",
            next_upgrade = next_upgrade and ("router-" ..size.."-".. next_upgrade .. "smart"),
            se_allow_in_space = is_space,
            localised_description = {
                "router-templates.smart-template",
                base_name,
                myutil.format_power(power_smart*1000)
            }
        }}, util.merge{holding_entity_as_combinator,{
            name = "router-"..size.."-"..prefix.."io",
            minable = { mining_time = 4, result = "router-"..size.."-"..prefix.."io" },
            sprites = mk_io_sprites(tint),
            icons = {
                {icon="__router__/graphics/io-icon.png", icon_size=128,},
                {icon="__router__/graphics/io-icon-mask.png", icon_size=128, tint=tint}
            },
            item_slot_count=20,
            collision_box = {{-1.7, -0.45}, {1.7, 0.45}},
            selection_box = {{-1.75, -0.5}, {1.75, 0.5}},
            map_color = {r=0.91,g=0.72,b=0.36},
            fast_replaceable_group = "router-"..space..size.."-io",
            next_upgrade = next_upgrade and ("router-" ..size.."-".. next_upgrade .. "io"),
            circuit_wire_max_distance = 10,
            circuit_wire_connection_points = connector_definitions2.points,
            se_allow_in_space = is_space,
            localised_description = {
                "router-templates.io-template",
                base_name,
                myutil.format_power(power_io*1000)
            }
        }}, util.merge{hidden_combinator,{
            type = "arithmetic-combinator",
            name = "router-component-"..prefix.."power-combinator-smart",
            selection_box = {{-1.9, -1.9}, {1.9, 1.9}},
            collision_box = {{-1.9, -1.9}, {1.9, 1.9}},
            localised_name = {"entity-name.router-"..space..size.."-smart"},
            icons = {
                {icon="__router__/graphics/router-icon.png", icon_size=128,},
                {icon="__router__/graphics/router-icon-mask.png", icon_size=128, tint=tint}
            },
            energy_source = {type = "electric", usage_priority="secondary-input"},
            active_energy_usage = tostring(power).."000W",
            localised_description = {
                "router-templates.smart-internal-template",
                base_name
            }
        }}, util.merge{hidden_combinator,{
            type = "arithmetic-combinator",
            name = "router-component-"..prefix.."power-combinator-io",
            selection_box = {{-1.7, -0.45}, {1.7, 0.45}},
            collision_box = {{-1.7, -0.45}, {1.7, 0.45}},
            icons = {
                {icon="__router__/graphics/io-icon.png", icon_size=128,},
                {icon="__router__/graphics/io-icon-mask.png", icon_size=128, tint=tint}
            },
            localised_name = {"entity-name.router-"..space..size.."-io"},
            energy_source = {type = "electric", usage_priority="secondary-input"},
            active_energy_usage = tostring(math.floor(power/2)).."000W",
            localised_description = {
                "router-templates.io-internal-template",
                base_name
            }
        }}}
    end
end

for prefix,router in pairs(protos.table) do
    create_router("4x4",prefix,router.tint,router.next_upgrade,router.is_space,router.postfix or "",router.power)
end
