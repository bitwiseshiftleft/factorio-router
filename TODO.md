# Factorio smart routers TODO list and ideas for future work

## Blocking release
* Migration script
* Make sure blueprinting works
* Check balance on routing toward nearby I/O terminal vs further along the line.

## General
* Create ghost lamps when creating ghost router, to enable circuit connections
* Document better in Factoripedia
* Document in tips-and-tricks, possibly even with a simulation
* Support undo deconstruct with circuit reconnect, even if the lamps weren't selected for deconstruction
* More testing with copy-paste, undo, etc.
* Undo should restore threshold trim combinator settings.
* Test fast-replacing ghosts
* Are "port connection" etc considered items (was in 1.0 in py, with crafting combinator)?
* Remove unused icons
* Make routers also function as a power pole?
* Add filters to event listeners, for reduced UPS cost
* Deal with routers' tendency to slightly over-send (undersend is better!) especially due to the gap when a loader moves items: they disappear from the chest's inventory before they appear on the belt's inventory.

Refactor lua slightly
* Use builder more extensively
* Use util.add_shift instead of vector_add

Make sure the collision masks are good.

Refine the recipes -- add some kind of circuits or filter inserters?

## Integration

* Integrate with Exotic
* Integrate with 248k
* Integrate with Ultimate belts
* Re-test integration in v2.0

## Smart routers

Implement smart I/O terminals
* Do we want to provide a limiting loader entity for the I/O terminals?  Eg a loader which takes an amount to load, and limits to at most that mayn items
* Suppress autoconnection in some cases?  Eg when a blueprint with both the chest and router is created
* Request only if > some amount, maybe with hysteresis?
* Lamps for defaultness?

Remember who last demanded an item, so that if excess is supplied it will end up in the right place??

Try to make the signaling more stable if possible, so that the network can quiesce faster

Also create wider smart routers?

Design a diode?

Document connecting red wires to routers as inbound contents

## Non-smart routers

* Re-build based on smart routers

## Graphics

* Make better graphics for smart routers
* * Redesign to look more like splitters with wires between them??  Or possibly make toroidal?
* * More detail, more contrast
* * Maybe move the red wire on the I/O port, so that it doesn't look like it's continuing through the connection point.
* * Is there a way to make them a little shorter without ruining the orthographic bit?
* * Gamma correction or whatever for the glow
* * Make lamps not as flat

* Make graphics for regular routers
* Make icons for the wire connection points
* Make lamp glows
* * Separate lamp picture into glow vs render vs tint layers

* Try to animate stuff when possible
* * Animate the belt shrouds, by attaching them to the belts?

* Make sure belts don't extend beyond eg the backs of routers