local util = require "__core__.lualib.util"
local myutil = require "lualib.util"
local M = {}


-- Wire definitions
local WRED   = defines.wire_type.red
local WGREEN = defines.wire_type.green
local CRED   = defines.wire_connector_id.circuit_red
local CGREEN = defines.wire_connector_id.circuit_green
local IRED   = defines.wire_connector_id.combinator_input_red
local IGREEN = defines.wire_connector_id.combinator_input_green
local ORED   = defines.wire_connector_id.combinator_output_red
local OGREEN = defines.wire_connector_id.combinator_output_green

local NGREEN = {green=true,red=false}
local NRED   = {green=false,red=true}
local NBOTH  = {green=true,red=true}
local NNONE  = {green=false,red=false}

-- Signal definitions
local EACH = {type="virtual",name="signal-each"}
local ANYTHING = {type="virtual",name="signal-anything"}
local EVERYTHING = {type="virtual",name="signal-everything"}
local THRESHOLD = {type="virtual",name="router-signal-threshold"}
local DEFAULT = {type="virtual",name="router-signal-default"}
local ZERO = {type="virtual",name="signal-0"}
local SIGC = {type="virtual",name="signal-C"}
-- local INPUT = defines.circuit_connector_id.combinator_input
-- local OUTPUT = defines.circuit_connector_id.combinator_output

-- TODO: make new virtual signal for reset
-- (if I'm going to use it at all)
local RESET = {type="virtual",name="signal-red"}
local LINK  = {type="virtual",name="router-signal-link"}
local LEAF  = {type="virtual",name="router-signal-leaf"}
local POWER = LEAF -- I guess

local PULSE = defines.control_behavior.transport_belt.content_read_mode.pulse
local HOLD  = defines.control_behavior.transport_belt.content_read_mode.hold

-- When used as a builder interface, takes input from itself
local ITSELF = "__ITSELF__"
local Builder = {}

function Builder:constant_combi(signals,description)
    -- Create a constant combinator with the given signals
    local entity = self.surface.create_entity{
        name="router-component-hidden-constant-combinator",
        position=self.position, force=self.force
    }
    local con = entity.get_or_create_control_behavior()
    local section = con.get_section(1)
    for i,sig in ipairs(signals) do
        section.set_slot(i,{value=util.merge{sig[1],{comparator="=",quality="normal"}},min=sig[2]})
    end
    entity.combinator_description = description or ""
    return entity
end

function Builder:make_blinken_combi(args)
    local blinken = args.blinken
    local blinken_suffix = blinken and "-blinken" or ""

    if args.arithmetic then
        name = args.combinator_name or (args.visible and "arithmetic-combinator") or "router-component-arithmetic-combinator" .. blinken_suffix
    else
        name = args.combinator_name or (args.visible and "decider-combinator") or "router-component-decider-combinator" .. blinken_suffix
    end
    
    -- Lay out blinkenlights on a grid
    local x_offset, y_offset, orientation = 0
    if args.blinken then
        x_offset = self.blinken_base_x + self.blinken_offset_x*self.blinken_xi
        y_offset = self.blinken_base_y + self.blinken_offset_y*self.blinken_yi
        self.blinken_xi = self.blinken_xi + 1
        if self.blinken_xi >= self.blinken_cols then
            self.blinken_xi = 0
            self.blinken_yi = self.blinken_yi + 1
        end

        -- arbitrary
        orientation = (self.rngstate*4) % 16
        self.rngstate = bit32.bxor(bit32.lrotate(self.rngstate,3),self.rngstate + 0xb96e43d2)
    else
        x_offset = 0
        y_offset = 0
    end

    local ret = self.surface.create_entity{
        name=name, position=myutil.vector_add(self.position,{x=x_offset,y=y_offset}), force=self.force,
        direction = args.orientation or orientation
    }
    ret.combinator_description = args.description or ""

    return ret
end

function Builder:left_and_right(args,is_decider)
    -- Parse out shorthand args like L=7, R=THRESHOLD or whatever
    local condition = {}
    local L = args.L or EACH
    local R = args.R or EACH
    if type(L) == 'table' then
        condition.first_signal = L
        condition.first_signal_networks = args.NL or NBOTH
    else
        condition.first_constant = L
        condition.first_signal_networks = NNONE
    end
    if type(R) == 'table' then
        condition.second_signal = R
        condition.second_signal_networks = args.NR or NBOTH
    elseif is_decider then
        condition.constant = R
    else
        condition.second_constant = R
    end
    return condition
end

function Builder:connect_inputs(args, combi)
    -- Connect up the inputs
    for j,args_color in ipairs({
        {args.red or {},WRED,ORED,CRED,IRED},
        {args.green or {},WGREEN,OGREEN,CGREEN,IGREEN}
    }) do
        local my_connector = combi.get_wire_connector(args_color[5])
        local wire = args_color[2]
        local their_connector
        for i,conn in ipairs(args_color[1]) do
            if conn then
                if conn == ITSELF then conn = combi end

                if     conn.type == "arithmetic-combinator"
                    or conn.type == "decider-combinator"
                    or conn.type == "selector-combinator" then
                    their_connector = conn.get_wire_connector(args_color[3],true)
                else
                    their_connector = conn.get_wire_connector(args_color[4],true)
                end
                my_connector.connect_to(their_connector,false,defines.wire_origin.script)
            end
        end
    end
    return combi
end

function Builder:decider(args)
    -- Create a decider combinator
    local combi = self:make_blinken_combi(args)

    local behavior = combi.get_or_create_control_behavior()
    for i,clause in ipairs(args.decisions or {args}) do
        local condition = self:left_and_right(clause,true)
        condition.comparator=clause.op
        condition.compare_type=clause.and_ and "and" or "or"
        if i > 1 then
            behavior.add_condition(condition)
        else
            behavior.set_condition(1,condition)
        end
    end
    for i,clause in ipairs(args.output or {args}) do
        local output = { networks=clause.WO or WBOTH, copy_count_from_input=not clause.set_one, signal=clause.out or EACH }
        if i > 1 then
            behavior.add_output(output)
        else
            behavior.set_output(1,output)
        end
    end

    return self:connect_inputs(args, combi)
end

function Builder:arithmetic(args)
    -- Create an arithmetic combinator
    local combi = self:make_blinken_combi(util.merge{args,{arithmetic=true}})
    local behavior = combi.get_or_create_control_behavior()
    local params = self:left_and_right(args)
    params.operation=args.op or "+"
    params.output_signal=args.out or EACH
    behavior.parameters = params
    return self:connect_inputs(args, combi)
end

function Builder:new(surface,position,force)
    local o = {surface=surface,position=position,force=force}
    setmetatable(o, self)
    self.__index = self
    self.blinken_xi = 0
    self.blinken_yi = 0
    self.blinken_cols = 8
    self.blinken_base_x = 0
    self.blinken_base_y = 0
    self.blinken_offset_x = 0
    self.blinken_offset_y = 0
    self.rngstate = 0x6ff4cd3d
    return o
end

function Builder:create_or_find_entity(args)
    -- TODO: do we have issues with direction or whatever here?
    local position = args.position or self.position
    
    -- Is it already there?
    local entity = self.surface.find_entity(args.name,position)
    if entity then return entity end

    -- Is it a ghost?
    entity = self.surface.find_entities_filtered{
        ghost_name=args.name,
        position=position,
        force=self.force,
        limit=1
    }
    if entity and entity[1] then
        -- un-ghost it
        local a,e,c = entity[1].revive()
        return e
    end

    -- Nope, create it
    return self.surface.create_entity(
        util.merge({{position=position,force=self.force}, args})
    )
end

-- Make a circuit that draws power, and outputs on GREEN based on power.
-- The outputs are based on the offset arg
--   (offset ^ INT_MAX) if power; offset if no power
--   default offset = INT_MAX
local function power_consumption_combi(builder, prefix, suffix, orientation, offset)
    local name = "router-component-"..prefix.."power-combinator-"..suffix
    local c1 = builder:combi{
        combinator_name=name,op="+",L=-0x80000000,R=POWER,out=POWER,red={ITSELF},
        orientation = orientation
    }
    local c2 = builder:combi{op="+",L=offset or -0x80000000,R=POWER,out=POWER,red={c1}}
    builder:connect_outputs(c1,c2,GREEN)
    return c2
end

-- 
local function fixup_power_consumption(builder, entity, name)
    for _,e in ipairs(entity.surface.find_entities_filtered{
        type="arithmetic-combinator",
        area=entity.bounding_box,
        force=builder.force
    }) do
        if string.find(e.name,"power%-combinator") then
            local c1 = builder:combi{
                combinator_name=name,op="+",L=-0x80000000,R=POWER,out=POWER,red={ITSELF},
                orientation = 8*entity.orientation
            }
            local c2 = e.circuit_connected_entities.green[1]
            builder:connect_outputs(c1,c2,GREEN)
            c1.connect_neighbour{target_entity=c2,wire=RED,source_circuit_id=OUTPUT,target_circuit_id=INPUT}
            e.destroy()
            return true
        end
    end
    return false
end

-- TODO: rename
local function create_passband(builder,input_belts,n_outputs)
    -- Create a passband for user-controlled routers that sets the belts
    -- Return several arrays:
    -- input_control[i]  should be connected to the control signals for direction[i]
    -- output_dropoff[i] should be connected to each inserter TO direction[i]
    -- output_pickup[i]  should be connected to each inserter FROM direction[i]
    
    -- This has the following behavior:
    -- Each signal that's > 0 will be mapped to 0x80000000 = INT_MIN
    -- Adding -1 to that signal will give a positive value for setting a filter
    -- Each signal that's < 0 will be mapped to 0 or a negative value other than INT_MIN
    -- However, rets[0][1] is an "unhandled inputs" combinator
    local ret = {
        input_control  = {},
        output_pickup  = {},
        output_dropoff = {}
    }

    -- For unhandled inputs: each = ((-1)|each) & -0x40000000
    -- = -4.. if present and unhandled
    -- = 0 otherwise
    local ipt0 = builder:combi{op="OR",L=-1}
    local unhandled = builder:combi{op="AND",R=-0x40000000,red={ipt0}}

    -- Create green_combi: DEFAULT = 0 + 32
    local green_combi = builder:constant_combi({{signal=DEFAULT,count=32}})

    -- Crreate a buffer for the circuit contents
    ret.indicator_combi = builder:combi{op="+",R=0}
    builder:connect_inputs(ipt0,ret.indicator_combi,RED)

    -- Create control for handled inputs
    for i,the_belt in ipairs(input_belts) do
        -- First, configure the belt
        local control = the_belt.get_or_create_control_behavior()
        control.enable_disable = false
        control.read_contents = true
        control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.hold

        -- check combinators: -256 (or more) for each item present
        local from = builder:combi{op="*",R=-0x10000,green={the_belt}}
        the_belt.connect_neighbour{wire=RED, target_entity=ipt0, target_circuit_id=INPUT}

        ret.output_pickup[i] = from
    end

    for i=1,n_outputs do
        -- For handled inputs: each = (0xC0...) << (each > 0)
        -- = 0x80... if present, or else 0
        -- but also wire up G = 32, so that G nonpresent = 0xC...
        local ipt = builder:combi{op=">",R=0,set_one=true}
        builder:connect_outputs(ipt,ipt0,RED)
        nxt = builder:combi{op="<<",L=-0x40000000,red={green_combi},green={ipt}}

        -- output = DEFAULT & each
        local to = builder:combi{op="AND",R=DEFAULT,red={unhandled},green={nxt}}

        ret.input_control[i] = ipt
        ret.output_dropoff[i] = to
    end

    return ret
end
    
-- Smart router demand is multiplied by this
-- Must a power of 2
-- Must be > 2 * maximum number of items that can be placed per tick
-- Hopefully multiple inserters with the same drop point can't drop more
-- than one stack per lane per tick?  If so, we would have
-- 2 directions of communication
-- * 2 lanes per belt
-- * 2 belts if we do 2x2 routers
-- * 4 items per stack (in Vanilla)
-- = 32 items per tick
--
-- The leakage rate is inversely proportional to the DEMAND_FACTOR (unless
-- I set it higher than 1, and adjust the circuit to fix the resulting bugs)
-- Since the equilibrium value of the network is scaled by 1/leakage, the
-- true demands are scaled by DEMAND_FACTOR for the representation, and by
-- another DEMAND_FACTOR for 1/leakage = DEMAND_FACTOR^2 = 2^12, times another
-- 2 for the lag combinator.  This leaves 2^18 less in a signed word.  So don't
-- request more than 200000 of any given resource, I guess.
local LEAK_FACTOR = 64

local function create_smart_comms(builder,prefix,chest,input_belts,input_loaders,output_loaders,lamps)
    -- Create communications system.

    -- Set up the builder's blinkendata
    builder.blinken_cols = 6
    builder.blinken_base_x = 0.43
    builder.blinken_base_y = 0.38
    builder.blinken_offset_x = 0.08
    builder.blinken_offset_y = 0.070

    ------------------------------------------------------------------------------
    -- Disable the input loaders if too much stuff is in the chest (it's jammed)
    -- FUTURE: in v0.1, individual input belts could jam without jamming the whole router
    --   Should we preserve this behavior in v2?  Probably not worth?
    --   But the new behavior probably makes the whole network more vulnerable to jamming.
    ------------------------------------------------------------------------------
    for _,b in ipairs(input_belts) do
        local control = b.get_or_create_control_behavior()
        control.read_contents = true
        control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.entire_belt_hold
        -- TODO: enable/disable the belt on low power for show, or maybe that's too expensive?
    end
    local jammed = builder:arithmetic{L=EACH,NL=NGREEN,R=0,out=SIGC,green={chest},description="jammed"}
    local jammed_max = 4*8*8 -- TODO set based on stacked belts
    for _,l in ipairs(input_loaders) do
        local control = l.get_or_create_control_behavior()
        control.circuit_enable_disable = true
        control.circuit_condition = {first_signal = SIGC, comparator="<", constant = jammed_max}
        l.get_wire_connector(CGREEN,true).connect_to(jammed.get_wire_connector(OGREEN,true))
    end

    ------------------------------------------------------------------------------
    -- Signal transmission
    ------------------------------------------------------------------------------
    local BIG_MASK = 0x3fffffff
    local HALF_BIG_MASK = 0x1fffffff
    -- == BIGMASK if in chest inventory, 0 if not
    local inventory_bigmask = builder:arithmetic{blinken=true,NL=NGREEN,op="OR",R=BIG_MASK,green={chest},description="inventory masked"}

    local scaled_inv = builder:arithmetic{blinken=true,op="*",R=-5,green={chest},red=input_belts,description="scaled inventory"} -- negative: current and incoming inventory

    -- Bus for demand.  Has positive feedback so that it quiesces faster (TODO: is there a point to this?)
    local my_demand = builder:arithmetic{blinken=true,op="/",R=5,red={ITSELF},description="damper"}               -- damping term to help the network quiesce faster (?)
    builder:arithmetic{blinken=true,L=LINK,op="/",R=-5,out=LINK,red={my_demand,ITSELF},description="undamp link"} -- don't damp the link

    -- Negative leak terms.  These don't feed back into the my_demand terms because we want to keep them away from the "uncalimed" detector
    local mini_damp = builder:arithmetic{blinken=true,op="OR",R=-1,red={my_demand},description="leak decrement"}
    mini_damp.get_wire_connector(OGREEN,true).connect_to(scaled_inv.get_wire_connector(OGREEN,true))
    mini_damp = builder:arithmetic{blinken=true,op="/",R=-LEAK_FACTOR,red={my_demand},description="leak div"}   -- leak term: /leak_factor
    mini_damp.get_wire_connector(OGREEN,true).connect_to(scaled_inv.get_wire_connector(OGREEN,true))

    local cancel_my_output = builder:arithmetic{blinken=true,op="/",R=-5,description="cancel my output",red={my_demand},green={scaled_inv}}
    local inventory_bigmask_minus_my_output = builder:decider{blinken=true,op="<",R=0,red={cancel_my_output},description="minus my output"}
    inventory_bigmask_minus_my_output.get_wire_connector(ORED,true).connect_to(inventory_bigmask.get_wire_connector(ORED,true))

    -- 1 for each unclaimed item in the chest
    local unclaimed = builder:decider{
        blinken=true,
        decisions = {
            {NL=NRED,   L=EACH, op="=", R=0},
            {and_=true, NL=NGREEN, L=EACH, op=">", R=0},
        },
        red = {my_demand},
        green = {chest},
        output = {{set_one=true}},
        description = "unclaimed"
    }
    unclaimed.get_wire_connector(ORED,true).connect_to(inventory_bigmask_minus_my_output.get_wire_connector(ORED,true))

    for i,l in ipairs(output_loaders) do
        local lamp = lamps[i]
        
        -- Set the lamp to enable when link >= 2 (one from me, one from them))
        local control = lamp.get_or_create_control_behavior()
        control.use_colors = true
        control.color_mode = defines.control_behavior.lamp.color_mode.color_mapping
        control.circuit_enable_disable = true
        control.circuit_condition = {first_signal=LINK, comparator=">=", constant=2}

        -- Drive my demand / 4 ==> lamp (connected via their_demand)
        local port_driver = builder:arithmetic{op="/",R=5,red={my_demand},green={scaled_inv},description="port driver"}
        -- Cancel out any output link signal
        local port_driver_no_link = builder:arithmetic{
            blinken=true,
            L=LINK,op="/",R=-5,out=LINK,
            red={my_demand},green={scaled_inv},
            description="port driver no link"
        }

        -- Combinator to hold link = 1
        local constant_link = builder:constant_combi(
            {{LINK,1}},
            "constant link"
        )

        -- The lamp has (their_demand + my_output)
        -- Set their_demand = (their_demand + my_output + cancel_my_output) if > 0
        local their_demand = builder:decider{
            blinken=true,
            decisions = {{NL=NBOTH, op=">", R=0}},
            output = {{WO=WBOTH,signal=EACH}},
            green = {lamp,port_driver,port_driver_no_link,constant_link},
            red = {cancel_my_output},
            description="input filter"
        }
        my_demand.get_wire_connector(ORED,true).connect_to(their_demand.get_wire_connector(ORED,true)) -- connect to demand bus

        local demand_reflector = builder:decider{
            blinken=true,
            decisions = {
                {NL=NGREEN,  L=LINK, op="=", R=1},
                {and_=true, NL=NRED, L=EACH, op=">", R=0},
                -- OR --
                {NL=NGREEN,  L=LEAF, op="=", R=1},
                {and_=true, NL=NRED, L=EACH, op=">", R=0}
            }, -- if neighbor isn't there, or is an I/O point, reflect my demand back to me
            output = {{WO=NRED,signal=EACH}},
            green = {port_driver},
            red = {port_driver},
            description="demand reflector"
        }
        my_demand.get_wire_connector(ORED,true).connect_to(demand_reflector.get_wire_connector(ORED,true)) -- connect to demand bus
        
        ------------------------------------------------------------------------------
        -- Output belt control
        ------------------------------------------------------------------------------
        -- green: their_demand + BIG_MASK
        -- red:   (inventory|BIG_MASK) + (1 if unclaimed) - my_demand
        local output_controller = builder:decider{
            blinken=true,
            decisions = {
                {NL=NRED, op=">", R=0},                     -- inventory > 0
                -- {and_=true,L=LINK, NL=NRED, op=">", R=0},   -- link > 0
                {and_=true,NL=NGREEN, op=">", R=0},         -- their demand > 0
                {and_=true, NL=NBOTH, op=">", R=BIG_MASK}, -- their demand + (mask - mine) > mask
                -- OR --
                {NL=NRED, op="=", R=BIG_MASK+1},              -- inventory > 0 and unclaimed and my demand = 0
                -- {and_=true,L=LINK, NL=NRED, op=">", R=0},  -- link > 0
                {and_=true,NL=NGREEN,L=DEFAULT,op=">",R=0},   -- their demand[default] > 0
                {and_=true,NL=NBOTH,L=DEFAULT,op=">",R=0}     -- their demand[default] >= mine
            },
            output = {{set_one=true,signal=EACH}},
            red = {inventory_bigmask_minus_my_output},
            green = {their_demand,demand_reflector},
            description="output_controller"
        }

        -- Set output loader filter behavior
        l.loader_filter_mode = "whitelist"
        local control = l.get_or_create_control_behavior()
        control.circuit_set_filters = true
        l.get_wire_connector(CGREEN,true).connect_to(output_controller.get_wire_connector(OGREEN,true))
    end
end

-- Construct module
M.create_passband = create_passband
M.create_smart_comms = create_smart_comms
M.create_smart_comms_io = create_smart_comms_io
M.power_consumption_combi = power_consumption_combi
M.fixup_power_consumption = fixup_power_consumption
M.RED = RED
M.GREEN = GREEN
M.DEFAULT = DEFAULT
M.INPUT = INPUT
M.OUTPUT = OUTPUT
M.POWER = POWER
M.EACH = EACH
M.ANYTHING = ANYTHING
M.EVERYTHING = EVERYTHING
M.Builder = Builder
M.LINK = LINK
M.LEAF = LEAF
M.ZERO = ZERO
M.DEMAND_FACTOR = DEMAND_FACTOR
M.THRESHOLD = THRESHOLD
M.PULSE = PULSE
M.HOLD = HOLD

return M
