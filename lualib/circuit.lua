local util = require"__core__.lualib.util"
local M = {}


-- Wire definitions
local RED = defines.wire_type.red
local GREEN = defines.wire_type.green

-- Signal definitions
local EACH = {type="virtual",name="signal-each"}
local ANYTHING = {type="virtual",name="signal-anything"}
local EVERYTHING = {type="virtual",name="signal-everything"}
local DEFAULT = {type="virtual",name="router-signal-default"}
local INPUT = defines.circuit_connector_id.combinator_input
local OUTPUT = defines.circuit_connector_id.combinator_output

-- TODO: make new virtual signal for reset
-- (if I'm going to use it at all)
local RESET = {type="virtual",name="signal-red"}
local COUNT = {type="virtual",name="router-signal-link"}
local LEAF  = {type="virtual",name="router-signal-leaf"}

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
    if string.find("+-*/ANDORXOR",op) or op==">>" or op=="<<" then
        name = (args.visible and "arithmetic-combinator") or "router-component-arithmetic-combinator"
        parameters = {operation=op}
        is_arithmetic = true
    else
        name = (args.visible and "decider-combinator") or "router-component-decider-combinator"
        parameters = {comparator=op, copy_count_from_input=not args.set_one}
    end
    parameters.output_signal = args.out or EACH
    local entity = self.surface.create_entity{
        name=name, position=self.position, force=self.force
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
        if red == ITSELF then red = entity end
        parameters = {wire=RED,target_entity=entity,target_circuit_id=INPUT}
        if red.type == "arithmetic-combinator" or red.type == "decider-combinator" then
            parameters.source_circuit_id=OUTPUT
        end
        red.connect_neighbour(parameters)
    end
    for i,green in ipairs(args.green or {}) do
        if green == ITSELF then green = entity end
        parameters = {wire=GREEN,target_entity=entity,target_circuit_id=INPUT}
        if green.type == "arithmetic-combinator" or green.type == "decider-combinator" then
            parameters.source_circuit_id=OUTPUT
        end
        green.connect_neighbour(parameters)
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

-- TODO: rename
local function create_passband(surface,position,force,input_belts,n_outputs)
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
    
    local builder = Builder:new(surface,position,force)

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
local DEMAND_FACTOR = 16

local function create_smart_comms(surface,position,force,input_belts,output_belts)
    -- Create communications system.

    -- For each output belt, set its mode to {don't enable or disable; read=pulse}
    -- The green wire from that output belt becomes the bus (connect it to a lamp)
    
    -- Return output_pickup and output_dropoff combinators
    -- TODO: add reset control
    local builder = Builder:new(surface,position,force)

    local ret = {
        output_pickup  = {},
        output_dropoff = {}
    }

    -----------------------------------------
    -- Construct the counter
    -----------------------------------------
    -- Inbound counter = sum(outbound - inbound) if > RESET
    -- Normally RESET == 0, so this leaves positive items, reducing effective demand
    -- This reduces effective demand because demands are negative
    local inbound_dbl   = builder:combi{op="*",R=-2,red=output_belts}
    local inbound_count = builder:combi{op=">",R=RESET,red={inbound_dbl,ITSELF}}

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
    local n_plus_k_shim    = builder:combi{op="/",L=COUNT,R=-DEMAND_FACTOR,out=COUNT,red={const_nega_ports}}

    -- Construct combo nega_average = (each / (N*DEMAND_FACTOR + 4))
    -- Nega average is also at latency 1 after the port.
    local nega_average = builder:combi{op="/",R=COUNT,red={const_nega_ports,n_plus_k_shim}}

    -- = +1 and -1 for every positive request (hooked up later)
    -- Assumption: all requests are positive!
    local nega_one_all_requests = builder:combi{op="OR",L=-1,red={const_nega_ports}}
    local plus_one_all_requests = builder:combi{op=">", R=0,set_one=true,red={const_nega_ports}}

    -- Same but only if it's < 0
    local nega_average_negative = builder:combi{op="<",R=0,green={nega_average,inbound_count}}
    
    -- Nega_output_driver = average_negative * DEMAND_FACTOR
    -- Cancels out values that we drive on the regular output drivers
    -- Because the <0 check filters out COUNT=1, need to re-add it here with const_count_one
    local nega_output_driver = builder:combi{
        op="*",R=DEMAND_FACTOR,
        red={nega_average_negative,const_count_one}
    }

    -----------------------------------------
    -- Input measurement
    -----------------------------------------
    -- Hook up the input belts to read their inputs
    for i,the_belt in ipairs(input_belts) do
        -- First, configure the belt
        local control = the_belt.get_or_create_control_behavior()
        control.enable_disable = false
        control.read_contents = true
        control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.hold

        -- Calculate ((-1 for all requested items) + (this belt contents))>>31
        -- = -1 for all requested items that aren't on this belt
        ret.output_pickup[i] = builder:combi{op=">>",R=31,red={the_belt},green={nega_one_all_requests}}
    end

    -- Unhandled inputs tracking: 
    --   -1 if on any belt or requested (requests are positive so they can't cancel?)
    --   +1 if requested
    --   Sum: -1 if on any belt and unrequested
    local minus_one_unhandled = builder:combi{
        op=">>",L=-1,
        green=input_belts, red={plus_one_all_requests}
    }
    local minus_one_unhandled_2 = builder:combi{
        op="!=", R=0,
        set_one=true, red={plus_one_all_requests}
    }
    builder:connect_outputs(minus_one_unhandled,minus_one_unhandled_2,RED)

    -- Add in default = -2 for reasons seen below
    local default_neg_2 = builder:constant_combi({{signal=DEFAULT,count=-2,out=DEFAULT}})
    default_neg_2.connect_neighbour{wire=RED,target_entity=minus_one_unhandled,target_circuit_id=OUTPUT}

    local LIBERALIZE = 1 -- A fudge factor so that things spread out a bit more

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
        control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.pulse

        -- bus & DEMAND_FACTOR-1 = inbound items pulse
        local inbound_pulse = builder:combi{op="AND",R=DEMAND_FACTOR-1,green={bus}}
        inbound_pulse.connect_neighbour{wire=RED, target_entity=inbound_count,
            source_circuit_id=OUTPUT, target_circuit_id=INPUT}

        -- bus & -DEMAND_FACTOR = demand from that port
        local inbound_demand = builder:combi{op="AND",R=-DEMAND_FACTOR,red={nega_output_driver},green={bus}}

        -- On the red side, connect to the average input
        inbound_demand.connect_neighbour{wire=RED, target_entity=nega_average,
            source_circuit_id=OUTPUT, target_circuit_id=INPUT}

        -- First level filtering (after the AND): x * (DEMAND_FACTOR+1 or just 1) / DEMAND_FACTOR
        -- on the green side, pass through:
        -- x / DEMAND_FACTOR, always
        -- x itself iff COUNT = 0. (i.e. if it's a leaf)
        local port_value = builder:combi{op="/", R=(DEMAND_FACTOR-LIBERALIZE), green={inbound_demand}}
        local leaf_value = builder:combi{op="=", L=COUNT, R=0, out=EVERYTHING, green={inbound_demand}}
        builder:connect_outputs(port_value,leaf_value,GREEN)

        -- Outputs of this net:
        --   Port wants it: 1
        --   Port doesn't want it: -BIG or 1-BIG
        --   Unhandled (or handled but rounds to zero in average): 0
        local gt_zero = builder:combi{op=">",   R=0, set_one=true, green={port_value}}
        local gt_mean = builder:combi{op="AND", R=MINUS_BIG,       green={port_value}, red={nega_average}}
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
        --   TODO: make default not an item so that it won't use a filter slot.
        local handle_by_default = builder:combi{
            op="=", R=DEFAULT, set_one=true,
            green={gt_zero}, red={minus_one_unhandled}
        }

        -- Feed it back on the red channel
        builder:connect_outputs(handle_by_default,gt_zero,RED)
        ret.output_dropoff[i] = gt_zero

        -- Drive output to the bus (also drives const_count_one which is already hooked up)
        local output_driver = builder:combi{op="*",R=-DEMAND_FACTOR,red={nega_average_negative}}
        output_driver.connect_neighbour{wire=GREEN, target_entity=bus, source_circuit_id=OUTPUT}
    end

    -- Whew
    return ret
end

-- Construct module
M.create_passband = create_passband
M.create_smart_comms = create_smart_comms
M.RED = RED
M.GREEN = GREEN
M.DEFAULT = DEFAULT
M.INPUT = INPUT
M.OUTPUT = OUTPUT
M.EACH = EACH
M.ANYTHING = ANYTHING
M.EVERYTHING = EVERYTHING
M.Builder = Builder
M.COUNT = COUNT
M.LEAF = LEAF
M.DEMAND_FACTOR = DEMAND_FACTOR

return M
