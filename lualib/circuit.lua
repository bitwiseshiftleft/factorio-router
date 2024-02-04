local util = require "__core__.lualib.util"
local myutil = require "lualib.util"
local M = {}


-- Wire definitions
local RED = defines.wire_type.red
local GREEN = defines.wire_type.green

-- Signal definitions
local EACH = {type="virtual",name="signal-each"}
local ANYTHING = {type="virtual",name="signal-anything"}
local EVERYTHING = {type="virtual",name="signal-everything"}
local THRESHOLD = {type="virtual",name="router-signal-threshold"}
local DEFAULT = {type="virtual",name="router-signal-default"}
local ZERO = {type="virtual",name="signal-0"}
local INPUT = defines.circuit_connector_id.combinator_input
local OUTPUT = defines.circuit_connector_id.combinator_output

-- TODO: make new virtual signal for reset
-- (if I'm going to use it at all)
local RESET = {type="virtual",name="signal-red"}
local COUNT = {type="virtual",name="router-signal-link"}
local LEAF  = {type="virtual",name="router-signal-leaf"}
local POWER = LEAF -- I guess

local PULSE = defines.control_behavior.transport_belt.content_read_mode.pulse
local HOLD  = defines.control_behavior.transport_belt.content_read_mode.hold

-- When used as a builder interface, takes input from itself
local ITSELF = "__ITSELF__"
local Builder = {}

function Builder:constant_combi(signals)
    -- Create a constant combinator with the given signals
    local entity = self.surface.create_entity{
        name="router-component-hidden-constant-combinator",
        position=self.position, force=self.force
    }
    local con = entity.get_or_create_control_behavior()
    for i,sig in ipairs(signals) do
        con.set_signal(i,sig)
    end
    return entity
end

function Builder:combi(args)
    -- Create a combinator.
    -- Args:
    --   op: the operation (default "+")
    --   L, R: the left and right operands (signal or int; default EACH)
    --   out: the output signal (default EACH)
    --   set_one: if a decider combinator, set output=1 instead of input
    --   red: inputs to hook up with red wires
    --   green: inptus to hook up with green wires
    --   visible: actually make it a visible combinator
    local control = {}

    -- Make either a decider or arithmetic combinator
    local name, parameters, is_arithmetic
    local op = args.op or "+"
    local blinken = args.blinken
    local blinken_suffix = blinken and "-blinken" or ""
    if string.find("+-*/ANDORXOR",op) or op==">>" or op=="<<" then
        name = args.combinator_name or (args.visible and "arithmetic-combinator") or "router-component-arithmetic-combinator" .. blinken_suffix
        parameters = {operation=op}
        is_arithmetic = true
    else
        name = args.combinator_name or (args.visible and "decider-combinator") or "router-component-decider-combinator" .. blinken_suffix
        parameters = {comparator=op, copy_count_from_input=not args.set_one}
    end
    parameters.output_signal = args.out or EACH

    -- Lay out blinkenlights on a grid
    local x_offset, y_offset, orientation = 0
    if blinken then
        x_offset = self.blinken_base_x + self.blinken_offset_x*self.blinken_xi
        y_offset = self.blinken_base_y + self.blinken_offset_y*self.blinken_yi
        self.blinken_xi = self.blinken_xi + 1
        if self.blinken_xi >= self.blinken_cols then
            self.blinken_xi = 0
            self.blinken_yi = self.blinken_yi + 1
        end

        -- arbitrary
        orientation = (self.rngstate*2) % 8
        self.rngstate = bit32.bxor(bit32.lrotate(self.rngstate,3),self.rngstate + 0xb96e43d2)
    else
        x_offset = 0
        y_offset = 0
    end

    local entity = self.surface.create_entity{
        name=name, position=myutil.vector_add(self.position,{x=x_offset,y=y_offset}), force=self.force,
        direction = args.orientation or orientation
    }

    -- Set left and right params
    local L = args.L or EACH
    if type(L) == 'table' then
        parameters.first_signal = L
    else
        parameters.first_constant = L
    end

    local R = args.R or EACH
    if type(R) == 'table' then
        parameters.second_signal = R
    elseif is_arithmetic then
        parameters.second_constant = R
    else
        parameters.constant = R
    end
    entity.get_or_create_control_behavior().parameters = parameters

    -- Connect up the inputs
    for i,red in ipairs(args.red or {}) do
        if red then
            if red == ITSELF then red = entity end
            parameters = {wire=RED,target_entity=entity,target_circuit_id=INPUT}
            if red.type == "arithmetic-combinator" or red.type == "decider-combinator" then
                parameters.source_circuit_id=OUTPUT
            end
            red.connect_neighbour(parameters)
        end
    end
    for i,green in ipairs(args.green or {}) do
        if green then
            if green == ITSELF then green = entity end
            parameters = {wire=GREEN,target_entity=entity,target_circuit_id=INPUT}
            if green.type == "arithmetic-combinator" or green.type == "decider-combinator" then
                parameters.source_circuit_id=OUTPUT
            end
            green.connect_neighbour(parameters)
        end
    end

    return entity
end

function Builder:connect_outputs(a,b,color)
    a.connect_neighbour{wire=color or RED,target_entity=b,target_circuit_id=OUTPUT,source_circuit_id=OUTPUT}
    if color==nil then
        -- Both
        a.connect_neighbour{wire=GREEN,target_entity=b,target_circuit_id=OUTPUT,source_circuit_id=OUTPUT}
    end
end

function Builder:connect_inputs(a,b,color)
    a.connect_neighbour{wire=color or RED,target_entity=b,target_circuit_id=INPUT,source_circuit_id=INPUT}
    if color==nil then
        -- Both
        a.connect_neighbour{wire=GREEN,target_entity=b,target_circuit_id=INPUT,source_circuit_id=INPUT}
    end
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
local DEMAND_FACTOR = 64

local function create_smart_comms(builder,prefix,input_belts,output_belts)
    -- Create communications system.

    -- For each output belt, set its mode to {don't enable or disable; read=pulse}
    -- The green wire from that output belt becomes the bus (connect it to a lamp)
    
    -- Return output_pickup and output_dropoff combinators
    -- TODO: add reset control

    local ret = {
        output_pickup  = {},
        output_dropoff = {}
    }


    builder.blinken_cols = 8
    builder.blinken_base_x = 0.43
    builder.blinken_base_y = 0.33
    builder.blinken_offset_x = 0.06
    builder.blinken_offset_y = 0.050

    -----------------------------------------
    -- Construct the counter
    -----------------------------------------
    -- Inbound counter = sum(outbound - inbound) if > RESET
    -- Normally RESET == 0, so this leaves positive items, reducing effective demand
    -- This reduces effective demand because demands are negative
    local inbound_dbl   = builder:combi{blinken=true,op="*",R=-2,red=output_belts}
    local inbound_count = builder:combi{blinken=true,op=">",R=RESET,red={inbound_dbl,ITSELF}}

    -- Decay depends on DECAY_FACTOR / DEMAND_FACTOR.  Tested only with 1.
    local DECAY_FACTOR  = 1
    local MINUS_BIG = -0x40000000

    -----------------------------------------
    -- Construct the comms and control
    -----------------------------------------
    -- Create COUNT = DECAY_FACTOR and COUNT = (ports+1)*DECAY_FACTOR combinators
    local const_count_one  = builder:constant_combi({{signal=COUNT,count=DECAY_FACTOR}})
    local const_nega_ports = builder:constant_combi({
        {signal=COUNT,count=-#(output_belts)},
        {signal=LEAF,count=-#(output_belts)*DEMAND_FACTOR}}
    )

    -- The above would give -(N+ports+1) for the denominator but we actually want -(N+empty ports+1)
    local n_plus_k_shim    = builder:combi{blinken=true,op="/",L=COUNT,R=-DEMAND_FACTOR,out=COUNT,red={const_nega_ports}}

    -- Experimental: average wih a factor of the previous value.  This makes the network
    -- slower to update but might help it quiesce?
    local lag = builder:combi{blinken=true,op="/",R=2,red={const_nega_ports,n_plus_k_shim},green={ITSELF}}

    -- Construct combo nega_average = (each / (N*DEMAND_FACTOR + 4))
    -- Nega average is also at latency 1 after the port.
    local nega_average = builder:combi{blinken=true,op="/",R=COUNT,red={const_nega_ports,n_plus_k_shim},green={lag}}

    -- = +1 and -1 for every positive request (hooked up later)
    -- Assumption: all requests are positive!
    local nega_one_all_requests = builder:combi{blinken=true,op="OR",L=-1,red={const_nega_ports}}
    local plus_one_all_requests = builder:combi{blinken=true,op=">", R=0,set_one=true,red={const_nega_ports}}

    -- Same but only if it's < 0
    local nega_average_negative = builder:combi{blinken=true,op="<",R=0,green={nega_average,inbound_count}}
    
    -- Nega_output_driver = average_negative * DEMAND_FACTOR
    -- Cancels out values that we drive on the regular output drivers
    -- Because the <0 check filters out COUNT=1, need to re-add it here with const_count_one
    local nega_output_driver = builder:combi{
        blinken=true,
        op="*",R=DEMAND_FACTOR,
        red={nega_average_negative,const_count_one}
    }
    
    local power_on = power_consumption_combi(builder, prefix, "smart")

    -----------------------------------------
    -- Input measurement
    -----------------------------------------
    -- Hook up the input belts to read their inputs
    for i,the_belt in ipairs(input_belts) do
        -- First, configure the belt
        local control = the_belt.get_or_create_control_behavior()
        -- control.enable_disable = true
        control.read_contents = true
        control.circuit_condition = {condition={comparator="=",first_signal=POWER}}
        control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.hold

        -- Calculate ((-1 for all requested items) + (this belt contents))>>31
        -- = -1 for all requested items that aren't on this belt
        ret.output_pickup[i] = builder:combi{blinken=true,op=">>",R=31,red={the_belt},green={nega_one_all_requests}}
    end


    -- Unhandled inputs tracking: 
    --   -1 if on any belt or requested (requests are positive so they can't cancel?)
    --   +1 if requested
    --   Sum: -1 if on any belt and unrequested
    local minus_one_unhandled = builder:combi{
        blinken=true,
        op=">>",L=-1,
        green=input_belts, red={plus_one_all_requests}
    }
    power_on.connect_neighbour{target_entity=minus_one_unhandled,wire=GREEN,source_circuit_id=OUTPUT,target_circuit_id=INPUT}
    local minus_one_unhandled_2 = builder:combi{
        blinken=true,
        op="!=", R=0,
        set_one=true, red={plus_one_all_requests}
    }
    builder:connect_outputs(minus_one_unhandled,minus_one_unhandled_2,RED)

    -- Add in default = -2 for reasons seen below
    local default_neg_2 = builder:constant_combi{{signal=DEFAULT,count=-2}}
    default_neg_2.connect_neighbour{wire=RED,target_entity=minus_one_unhandled,target_circuit_id=OUTPUT}

    local LIBERALIZE = 0 -- A fudge factor so that things spread out a bit more

    -----------------------------------------
    -- Bus interface and output determination
    -----------------------------------------
    -- OK, connect up the ports and output belts,
    -- The output belts are also (on the green wire) the bus interface
    -- TODO: extend to multiple pairs of I/O belts?
    for i,bus in ipairs(output_belts) do
        -- set the belt to pulse read mode
        local control = bus.get_or_create_control_behavior()
        control.enable_disable = false
        control.read_contents = true
        control.read_contents_mode = PULSE

        -- bus & DEMAND_FACTOR-1 = inbound items pulse
        local inbound_pulse = builder:combi{blinken=true,op="AND",R=DEMAND_FACTOR-1,green={bus}}
        inbound_pulse.connect_neighbour{wire=RED, target_entity=inbound_count,
            source_circuit_id=OUTPUT, target_circuit_id=INPUT}

        -- bus & -DEMAND_FACTOR = demand from that port
        local inbound_demand = builder:combi{blinken=true,op="AND",R=-DEMAND_FACTOR,red={nega_output_driver},green={bus}}

        -- On the red side, connect to the average input
        inbound_demand.connect_neighbour{wire=RED, target_entity=nega_average,
            source_circuit_id=OUTPUT, target_circuit_id=INPUT}

        -- First level filtering (after the AND): x * (DEMAND_FACTOR+1 or just 1) / DEMAND_FACTOR
        -- on the green side, pass through:
        -- x / DEMAND_FACTOR, always
        -- x itself iff COUNT = 0. (i.e. if it's a leaf)
        local port_value = builder:combi{blinken=true,op="/", R=(DEMAND_FACTOR-LIBERALIZE), green={inbound_demand}}
        local leaf_value = builder:combi{blinken=true,op="=", L=COUNT, R=0, out=EVERYTHING, green={inbound_demand}}
        builder:connect_outputs(port_value,leaf_value,GREEN)

        -- Outputs of this net:
        --   Port wants it: 1
        --   Port doesn't want it: -BIG or 1-BIG
        --   Unhandled (or handled but rounds to zero in average): 0
        local gt_zero = builder:combi{blinken=true,op=">",   R=0, set_one=true, green={port_value}}
        local gt_mean = builder:combi{blinken=true,op="AND", R=MINUS_BIG,       green={port_value}, red={nega_average}}
        builder:connect_outputs(gt_zero,gt_mean)

        -- Inputs to this combinator:
        --   Port wants it: 1
        --   Someone else wants it more, -BIG or 1-BIG
        --   Not present: 0
        --   Present but unhandled: -1
        --   Unhandled is incompatible with "port wants it" and "someone else wants it more"
        --
        -- DEFAULT:
        --   Port wants it: 1-2 = -1
        --   Someone else wants it more: -BIG-2 or -1-BIG
        --   Not present: -2
        --   Present but unhandled: impossible
        --
        -- The only collision between these is:
        --   Present but unhandled = Port wants default = -1
        --
        -- And of course default=1
        local handle_by_default = builder:combi{
            blinken=true,
            op="=", R=DEFAULT, set_one=true,
            green={gt_zero}, red={minus_one_unhandled}
        }

        -- Feed it back on the red channel
        builder:connect_outputs(handle_by_default,gt_zero,RED)
        ret.output_dropoff[i] = gt_zero

        -- Drive output to the bus (also drives const_count_one which is already hooked up)
        local output_driver = builder:combi{blinken=true,op="*",R=-DEMAND_FACTOR,red={nega_average_negative}}
        output_driver.connect_neighbour{wire=GREEN, target_entity=bus, source_circuit_id=OUTPUT}
    end

    -- Whew
    return ret
end

local function create_smart_comms_io(
    prefix,entity,builder,chest,demand,threshold_trim,orientation
)
    ----------------------------
    -- Design of this circuit
    ----------------------------
    --[[
    Unlike the regular design, we are going to use underneathies here.
    This allows the I/O port to be only 1 deep without letting things
    pass through to the other side.

    Since underneathies can't connect to the circuit network, we need
    to read info from the inserters.

    For the "in"serters sending things to the chest, this is fine: they
    aren't filter inserters anyway, and don't have an enable condition,
    so they can all be wired together without interfering

    For the "out"serters sending things from the chest, it's tricky.
    The problem is that one inserter's hand read will send a positive
    signal to the other inserter, thus causing it to trigger when
    perhaps it shouldn't.  This is only a problem for things that
    are in the chest: if something isn't in the chest, the signal is
    only transient, so it will only clog the filter list for one tick.

    To mitigate this issue, we want to set everything that's in supply
    to a negative value.  The way I chose is to set it to:
    
        -MAX   if supply >  my_demand
        -MAX/2 if supply <  my_demand
        0      if supply == my_demand
    
    +   -MAX/2 if threshold != 0 and their_demand >= threshold

    This wraps around to be positive if both are satisfied, and is
    definitely negative if supply < my_demand.

    It's still not quite safe to connect the outserters directly
    to the bus, but maybe almost? (FUTURE?) The basic problem is
    if an item arrives this tick, and the bus requests (or sends it
    to me) this tick, then it will be set in the filter with no
    convenient way to suppress it.  Therefore the outserters are
    buffered onto the bus.
    
    --]]


    -- TODO: add reset control

    local MINUS_HMAX = -0x40000000
    local MINUS_MAX  = -0x80000000

    -- Outreg drives the bus (on green)
    -- Outreg is driven by the outserters (on red)
    -- (This is set up in control.lua)
    local outreg = builder:combi{op="+",R=0}

    local power = power_consumption_combi(builder, prefix, "io", orientation, 0)

    -- Construct the inbound counter counter
    -- Counts +1 on bus % DEMAND_FACTOR
    -- Counts -1 on outreg [red, so it's not connected to the bus]
    -- Counts -1 on inbound stuff (connected by control)
    local inbound_neg   = builder:combi{op="*",R=-1,red={outreg}}
    local inbound_and   = builder:combi{op="AND",R=DEMAND_FACTOR-1,green={outreg}}
    local inbound_count = builder:combi{op=">",R=RESET,green={inbound_neg,inbound_and},red={ITSELF}}

    -- burst suppression
    local BURST_FACTOR = DEMAND_FACTOR/8
    local BURST_FALLOFF = DEMAND_FACTOR
    local scale_before_burst = builder:combi{op="*",R=-DEMAND_FACTOR*BURST_FACTOR}
    builder:connect_inputs(scale_before_burst,outreg,RED) -- connected to outserters
    local burst_hold = builder:combi{op="+", R=1, green={scale_before_burst,ITSELF}}
    local burst_falloff = builder:combi{op="/", R=-BURST_FALLOFF, green={scale_before_burst,ITSELF}}

    -- OK, create the comms
    local internal_combi = builder:constant_combi{{signal=LEAF,count=-1}}
    local demand_pos     = builder:combi{op=">",R=0,green={entity}}
    local demand1        = builder:combi{op="-",L=0,R=EACH,green={demand_pos}}
    local demand2        = builder:combi{op="-",L=0,R=EACH,green={demand_pos}} -- separate to not mix with inbound_count
    -- demand each item whose net supply is < 0
    local supply_neg     = builder:combi{op="<",R=0,red={chest},green={inbound_count,internal_combi,demand1}}

    -- Set one output control according to supply and demand
    -- The setting is MINUS_MAX for things the network demands more than us
    -- and MINUS_HMAX for things we demand more
    -- This will be added to { -HMAX if threshold > 0 } resulting in underflow
    --    ==> positive ==> filter will be set
    --
    -- If 0 < x < 0x40000000 then x | MINUS_HMAX = (x + MINUS_HMAX)
    -- If MINUS_HMAX <= x < 0 then x | MINUS_HMAX = x
    -- Thus (MINUS_HMAX - x) + (x | MINUS_HMAX) = {
    --   MINUS_MAX if 0 < x < 0x40000000
    --   MINUS_HMAX if MINUS_HMAX <= x < 0
    --   0 if x isn't in the combinator
    -- }
    local mm_one         = builder:combi{op="OR", L=MINUS_HMAX,R=EACH,red={chest},green={demand2}}
    local mm_two         = builder:combi{op="-",  L=MINUS_HMAX,R=EACH,red={chest},green={demand2}}
    builder:connect_outputs(mm_one,mm_two,GREEN)

    -- Scale threshold by DEMAND, and trim by -DEMAND
    local trim_scaler = builder:combi{op="*",R=-DEMAND_FACTOR,green={threshold_trim}}
    local threshold_scaler = builder:combi{op="*",L=THRESHOLD,R=2*DEMAND_FACTOR,out=THRESHOLD,green={threshold_trim}}

    -- Set threshold = -HMAX-1 if threshold != 0
    -- This will get added to +1 below, resulting in -HMAX
    -- = -HMAX-1 if power is on
    -- = -1 if power is off
    local power_adjust = builder:combi{op=">>",L=POWER,R=1,out=POWER,green={power}} -- -HMAX if power is off
    local power_adjust_2 = builder:constant_combi{{signal=POWER,count=-1}}
    local threshold_nonzero = builder:combi{op="!=",L=THRESHOLD,R=0,out=THRESHOLD,set_one=true,green={threshold_trim}}
    local threshold_test     = builder:combi{op="*",L=THRESHOLD,R=POWER,out=THRESHOLD,green={threshold_nonzero},red={power_adjust,power_adjust_2}}

    -- drive the bus according to demand
    local driver        = builder:combi{op="*",R=-DEMAND_FACTOR,green={supply_neg}}
    builder:connect_outputs(driver,outreg,GREEN)

    -- output MINUS_HMAX if > threshold and threshold != 0
    local in_demand_1   = builder:combi{op=">=",R=THRESHOLD,green={driver},red={
        threshold_scaler,trim_scaler,burst_hold,scale_before_burst
    },set_one=true}
    local in_demand_2   = builder:combi{op="*",R=THRESHOLD,green={in_demand_1,threshold_test}}
    builder:connect_outputs(mm_one,in_demand_2,GREEN)

    return {output=in_demand_2, outreg=outreg, input=inbound_neg, power=power}
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
M.COUNT = COUNT
M.LEAF = LEAF
M.ZERO = ZERO
M.DEMAND_FACTOR = DEMAND_FACTOR
M.THRESHOLD = THRESHOLD
M.PULSE = PULSE
M.HOLD = HOLD

return M
