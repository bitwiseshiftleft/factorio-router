# Factorio smart routers TODO list and ideas for future work

## Suggestions to consider

* Tallow: constrain the operation of the network to make it more of a puzzle.
* For example, could require the network to be a directed or undirected tree, or a DAG.
* VVG: consider contraining to a directed tree or similar because it's better for UPS.

Another possibility to constrain the network more: instead of being completely free,
there can only be one static requester for each resource (per network). This could either
be static or potentially circuit controlled, but if you request the same resource in
more than one place then that resource can't be routed anywhere.  Then the user would need
to separately track how many of each item has been delivered.

The (mostly) static routing layout might be better for UPS too.  A tree with a static
routing layout, where each resource can only be requested from one place, requires only
about 12 combinators per router, most of which are not active at any given time.
However, a constraint to request each resource from only one place might be too
restrictive.

## General
* Document how the circuits work
* Support undo deconstruct with circuit reconnect, even if the lamps weren't selected for deconstruction
* More testing with copy-paste, undo, etc.
* Test fast-replacing ghosts
* Remove unused icons
* Proper packaging for upload to mod portal

Refactor lua slightly
* Move subroutines out of control.lua
* Use builder more extensively
* Use util.add_shift instead of vector_add
* Don't hard-code names in the picker-dolly banning code

Make sure the collision masks are good.

Refine the recipes -- add some kind of circuits or filter inserters?

## Integration

* Integrate with Exotic
* Integrate with 248k
* Integrate with Ultimate belts

## Smart routers

Implement smart I/O terminals
* Lamps for defaultness, disablement.
* Do we want to provide limiting loaders for the I/O terminals?  Eg with an amount to cache
* Suppress autoconnection in some cases?  Eg when a blueprint with both the chest and router is created
* Undo construct -> deconstruct; undo deconstruct -> construct
* Test throughput when a terminal is connected to another terminal

Buffered routers?
* These might set the default signal?
* Compare performance.  If it's much better then maybe all routers should be buffered?

Add a reset switch somehow in case the system goes haywire
* Possibly add a signal definition for that

Make the routers leak a little less: signals don't propagate far enough.

Try to make the signaling more stable if possible, so that the network can quiesce.

Wider smart routers?
* Wider smart routers probably would use a splitter or chest for perf.
* A splitter would fit.

Design a diode
* I have a circuit design, but need to implement it and make the entities
* The diode appears as a leaf on both sides, but propagates requests in one direction.
* Inputs at leaf stations get magnified by a factor of almost D, so they should be reduced. One possible calculation is x//(D+1) + (x mod (D+1)).  This is the same mod D: x//(D+1) == (x - (x mod (D+1)))/(D+1) === x - (x mod (D+1)) because D+1 === 1.  This allows a latency-1 division by approximately D without changing the low bits.
* What about long-distance link situations?  May want a version which can be proxied by radio


Some sort of history buffer instead of / in addition to defaulting?
* So that e.g. if we send too much iron, it will go to the iron station even though there is no more demand.
* It's not obvious that this is stable, but it might be.

## Smart router autoconnect

Consider not connecting with a single wire, but with several, automatically using Lua
* When one wire is connected (or when bi-directional belts are connected??), automatically connect the other wires.
* Pro: gets rid of requirement to blueprint the lamps
* Pro: Significant reduction in circuit size
* * Current node is ~50
* * Save at least 9 gates (input high and low filters, and nega driver)
* * Save up to 8 gates from avoiding leaf vs root scaling (optimistic) -- this would be adjusted by the Lua on detecting a leaf.
* * Many of the rest of the gates can be eliminated with Factorio2's fancy decider combinator
* Pro: faster convergence
* Pro: don't need a diode entity, can just autodetect it
* Con: need on-build handler to trace the belts for connect/disconnect
* Con: need complicated circuit reworking to connect things, turn leaf scaling on/off etc.
* Con: opaque and even cheatier

I could consider enabling this by creating a "routable belt/underneathie" that's the same as normal belts, but which must be used to connect routers.  This would both add to flavor and possibly graphics, and help the Lua avoid triggering too much on regular belts.

## Non-smart routers

* Backport changes
* Cause to have power consumption
* Make blueprintable
* Set control behavior of lamps so they aren't "disabled by control behavior".
* Make default-ness affect the graphics (re-add indicator lamp?) since it's not an item anymore
* Allow <0 instead of >0 as port condition? ... Like I dunno, shift-R?

## Graphics

* Make real graphics for smart routers
* * Redesign to look more like splitters with wires between them??
* * More detail, more contrast
* * Is there a way to make them a little shorter without ruining the orthographic bit?
* * Gamma correction or whatever for the glow
* * Make lamps not as flat

* Make graphics for regular routers
* Make icons for the wire connection points
* Make lamp glows
* * Separate lamp picture into glow vs render vs tint layers

* Try to animate stuff when possible
* * Animate the belt shrouds, by attaching them to the belts?

* Adjust the patched underneathies so they don't cast a weird shadow.
* * Integrate the rubber shroud thingies?
* * Separate in vs out belts (with half-sized graphics)?