# Factorio smart routers TODO list

## General
* Document how the circuits work
* Clean up functions
* Clean up prototypes via table merging
* Remove unused icons
* Proper packaging
* Support undo deconstruct with circuit reconnect, even if the lamps weren't selected for deconstruction

Refactor lua slightly
* Move subroutines out of control.lua
* Use builder more extensively
* Use util.add_shift instead of vector_add

Detect belt techs, recipes etc
* Refine the recipes -- add some kind of circuits or filter inserters?
* Special case recipes for some uses
* Localize router names
* Create inserters as necessary for higher-speed versions
* Create/destroy extra inserters on fast replace
* Space routers should be placeable in space
* Chain upgrades yellow -> red -> blue

Make new signal for reset
* Or some other reset mechanism

Add a design doc
* Maybe note in game not to mess with certain signals

Make other router shapes, e.g. 3 <=> 3??

## Integration/testing

* Test fast-replacing ghosts
* Test what happens when you place a router on a spaceship, or just ban that
* Integrate with SE (deep space belts woo)
* Integrate with K2
* Integrate with Py
* Integrate with AngelBobs
* Integrate with IR
* Integrate with Exotic
* Integrate with 248k
* Integrate with Ultimate belts

## Smart routers
Make a startup setting to enable/disable smart routers

Design smart I/O ports
* Have a circuit design, but need to implement it and make the entities

Design smart I/O buffers (= buffered version of router with a small chest??)
* These would set the default signal?
* Compare performance.  If it's much better then maybe all routers should be buffered?

Add a reset switch somehow
* Possibly add a signal definition for that

Adjust how loosely/tightly things are routed by adjusting the average.

Wider smart routers?  May need buffer/splitter

Design a diode
* This would connect two parts of the network but only allow demand to flow in one direction
* Would be useful for e.g. train stations or rocket loading in SE, where the materials inherently flow in 
* Can probably just present as a leaf to both sides, but proxy requests in one direction and not the other.

## Smart router autoconnect

Consider not connecting with a single wire, but with several, automatically using Lua
* When one wire is connected (or when bi-directional belts are connected??), automatically connect the other wires.
* Pro: gets rid of requirement to blueprint the lamps
* Pro: Significant reduction in circuit size
* * Current node is ~50
* * Save at least 9 gates (input high and low filters, and nega driver)
* * Save up to 8 gates from avoiding leaf vs root scaling (optimistic) -- this would be adjusted by the Lua on detecting a leaf.
* * Many of the rest of the gates can be eliminated with factorio 2 decider combinator
* Pro: faster convergence
* Pro: don't need a diode entity, can just autodetect it
* Con: need on-build handler to trace the belts for connect/disconnect
* Con: need complicated circuit reworking to connect things, turn leaf scaling on/off etc.
* Con: opaque and even cheatier

I could consider enabling this by creating a "routable belt/underneathie" that's the same as normal belts, but which must be used to connect routers.  This would both add to flavor and possibly graphics, and help the Lua avoid triggering too much on regular belts.

## Non-smart routers
* Make a startup setting to enable/disable non-smart routers

* Make blueprintable
* Set control behavior of lamps so they aren't "disabled by control behavior".
* Make default-ness affect the graphics (re-add indicator lamp?) since it's not an item anymore

* Allow <0 instead of >0 as port condition? ... Like I dunno, shift-R?
