# Factorio smart routers TODO list

## General
* Document how the circuits work
* Clean up functions
* Clean up prototypes via table merging
* Remove unused icons
* Proper packaging

Refactor lua slightly
* Move circuit builder to its own module
* If building a lot of circuits, move each one to its own file
* Move subroutines out of control.lua
* Use builder more extensively
* Use base's merge_tables when possible

Detect belt techs, recipes etc
* Refine the recipes -- add some kind of circuits or filter inserters?
* Special case recipes for some uses
* Localize router names
* Extra inserters as necessary
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
* Test what happens when you place a router on a spaceship

* Integrate with SE (deep space belts woo)
* Integrate with K2
* Integrate with Py
* Integrate with AngelBobs
* Integrate with IR
* Integrate with Exotic
* Integrate with 248k
* Integrate with Ultimate belts

## Smart routers
* Make a startup setting to enable/disable smart routers

Design smart I/O ports
* Have a circuit design, but need to implement it and make the entities

Design smart I/O buffers (= buffered version of router with a small chest??)
* These would set the default signal?
* Compare performance.  If it's much better then maybe all routers should be buffered?

* Add a reset switch somehow
* * Possibly add a signal definition for that

* Adjust how loosely/tightly things are routed by adjusting the average.
* Wider smart routers?  May need buffer/splitter

## Smart router autoconnect
* Consider not connecting with a single wire, but with several
* When one wire is connected (or when bi-directional belts are connected??), automatically connect the other wires.
* Pro: gets rid of requirement to blueprint the lamps
* Pro: Significant reduction in circuit size
* * Current node is ~50
* * Save at least 9 gates (input high and low filters, and nega driver)
* * Save up to 8 gates from avoiding leaf vs root scaling (optimistic)
* * Many of the rest of the gates can be eliminated with factorio 2 decider combinator
* Pro: faster convergence
* Con: need on-build handler to trace the belts for connect/disconnect
* Con: opaque and even cheatier

## Regular routers
* Make a startup setting to enable/disable non-smart routers

*Make blueprintable
*Set control behavior of lamps so they aren't "disabled by control behavior".
*Make default-ness affect the graphics (re-add indicator lamp?) since it's not an item anymore

* Allow <0 instead of >0 as port condition? ... Like I dunno, shift-R?
