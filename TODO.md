# Factorio smart routers TODO list

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
* Remove unused icons
* Proper packaging
* Support undo deconstruct with circuit reconnect, even if the lamps weren't selected for deconstruction
* Test fast-replacing ghosts
* Set dependencies
* Make the stations use (a lot of) power somehow, or else add solar to the recipe

Reverse the orders: it's currently express - fast - regular

Refactor lua slightly
* Move subroutines out of control.lua
* Use builder more extensively
* Use util.add_shift instead of vector_add

Refine the recipes -- add some kind of circuits or filter inserters?

## Integration

* Add soft dependencies on other mods
* Test what happens when you place a router on a spaceship, or just ban that
* Integrate with SE (deep space belts woo)
* Space routers should be placeable in space
* Integrate with K2 -- need to add extra inserters for speed
* Integrate with Py
* Integrate with AngelBobs
* Integrate with IR
* Integrate with Exotic
* Integrate with 248k
* Integrate with Ultimate belts
* Create inserters as necessary for higher-speed versions
* Create/destroy extra inserters on fast replace

## Smart routers

Implement smart I/O ports
* Make an icon
* Wire connection points
* Lamps for defaultness, disablement.
* Rotate to disable output / set defaultness to 100?
* Do we want to provide limiting loaders for the I/O ports?  Eg with an amount to cache
* Autoconnect chests, maybe pursuant to startup option
* Copy-paste, auto deconstruct, undo etc.

Buffered routers?
* These would set the default signal?
* Compare performance.  If it's much better then maybe all routers should be buffered?
* Or maybe just make buffers a regular I/O node.

Add a reset switch somehow in case the system goes haywire
* Possibly add a signal definition for that

Make the routers leak a little less: signals don't propagate far enough.

Other shapes?? Wider smart routers?
* Wider smart routers probably would use a filter for perf.

Design a diode
* I have a circuit design, but need to implement it and make the entities
* The diode appears as a leaf on both sides, but propagates requests in one direction.
* Inputs at leaf stations get magnified by a factor of almost D, so they should be reduced. One possible calculation is x//(D+1) + (x mod (D+1)).  This is the same mod D: x//(D+1) == (x - (x mod (D+1)))/(D+1) === x - (x mod (D+1)) because D+1 === 1.  This allows a latency-1 division by approximately D without changing the low bits.
* What about long-distance link situations?  May want a version which can be proxied by radio

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

* Make blueprintable
* Set control behavior of lamps so they aren't "disabled by control behavior".
* Make default-ness affect the graphics (re-add indicator lamp?) since it's not an item anymore
* Allow <0 instead of >0 as port condition? ... Like I dunno, shift-R?

## Graphics

* Make real graphics for smart routers
* Make graphics for I/O ports.  These don't have to overlap as much anymore because of underneathies
* Make graphics for regular routers
* Make wire connection points
* Make lamp glows
* Try to animate stuff when possible
* Add blinkenlights
* Add shadows to the graphics
* Adjust the patched underneathies so they don't cast a weird shadow.