# Circuit-controlled router

## Development version

Please note that this is an early development release, and is not close to completion.  In particular, the graphics are just placeholders (and have the wrong rendering angle), except maybe for the signals.

## Introduction

This mod introduces two types of circuit-controlled belt routers for moving items around your base.  These buildings act somewhat like 4-way splitters, with belts of items going into them and coming out of them.

However, there are several important differences to splitters:
* Routers can have multiple filters set per port.
* Routers can be circuit-controlled.
* Splitters preserve lanes, but routers do not.
* Splitters try to divide items fairly, but routers do not.
* Splitters can send items to a backup port if the main one is blocked, but routers cannot.

## Manual routers

Manual routers are controlled by a constant combinator on each port.  Every item signaled as >0 on that port will be accepted.  If the default signal ![default_signal_icon](resources/default.png) is set on a port, then it will also receive any items that are not accepted by other ports.  Using the "rotate" key on a port will toggle the default signal.

Manual routers do not have any form of priority.  An item is either requested by a port, or it is not.

Manual routers are currently in a rougher state than smart ones, and are disabled.

## Smart routers and I/O terminals

The screenshot shows a simple network which uses smart routers to direct the manufacturing of blue chips.  First the green-chip station requests iron and copper; the red-chip station requests copper, plastic and green chips; the blue-chip station requests green chips, red chips, iron, sulfur and water barrels (to make sulfuric acid), and the barrel-filler station requests empty barrels.  Finally, a station at the left requests the blue chips.  All of these are routed automatically through the network.

![smart router screenshot](resources/screenshot-smart.jpg)

Smart routers and I/O terminals are designed to form a network, routing items from terminals that provide them to terminals that request them.  The routers and the terminals form a network connected by green wires.  When two smart routers are connected together, their port lights will turn from red to green, and when a router port is connected to a terminal, the router's port light will turn blue.

Each terminal has a set of items it requests.  You can adjust this using the constant combinator that's integrated into the terminal, or through the circuit network.  The terminal can also set the threshold at which it starts providing items, which is useful for adjusting its priority.

Smart routers use a fancy communication protocol over the green wires.  It is recommended not to add your own signals to these.  The routers also track how many items have been from one smart router to another, so that they don't send too many.  It is therefore important not to divert these items, either with splitters or by picking them up off the belt.

Since the circuit network doesn't update instantaneously, it is possible that slightly too many of an item will be sent.  Reducing this problem is part of the purpose of the request threshold ![threshold_signal_igon](resources/threshold.png).  If extra items are sent, they would normally have nowhere to go, and so would clog up the network until someone requests them.  However, extra items can be sent to
*buffer terminals*.  Buffer terminals additionally request all types of resources that aren't requested elsewhere, by using the default signal ![default_signal_icon](resources/default.png).  Just set ![default_signal_icon](resources/default.png) on a terminal to some positive value (say, 100) and any extra items will be routed to that terminal.

I/O terminals automatically connect to adjacent chests, unless this is disabled in the map settings.

## Balancing

Smart routers are not very balanced, because they make some types of logistics prolems significantly easier.  However, they are fairly expensive and use a lot of power.

## How it works

Each router contains several invisible very fast filter inserters, much like with the [https://mods.factorio.com/mod/miniloader](miniloaders) mod.  However, if you place many items on the port's allow-list, then simply setting the inserters' filters wouldn't be enough: inserters can only have up to 5 filters, and any other items in the allow-list would be ignored.  So each router also contains a circuit made of invisible combinators to intersect the filters with the items present on the input belts.

Smart routers use extensive circuitry.  Each green wire carries the following signals:
* For each item, the number of those items being put on the belt in that tick.  This must remain less than 64.
* For each item, 64 times a demand factor for that item.
* The connected signal ![connected_signal_icon](resources/connected.png) is set to -64 by each smart router.  So if it's -64 then one smart router is connected, and if it's -32 then two smart routers are connected.
* The leaf signal ![leaf_signal_icon](resources/leaf.png) is set to 64 by each leaf (requester and/or provider) port.  This is currently only used to turn the port indicator light blue.

The item types participate in a "leaky heat equation": each smart router with N connected ports propagates slightly less than 1/Nth of its demands to each neighboring router.  You can imagine that a leaf node demanding e.g. copper is a "heat source" on the copper channel, and then heat propagates throughout the smart router network.  The heat leaks out slightly from everywhere in the network, but especially from the edges, which sets up a heat gradient.  When a router receives an item, it will be routed in a direction that has above-average heat (= demand) for that item type.

The routers count how many items they are expecting to receive, so that they don't send too many.

Because each router knows how much of each signal it's broadcasting in each direction, it can cancel out the contribution from its own outputs when processing its inputs.  This enables all the signals to fit on one green wire.

## Performance cost

This mod makes efforts to reduce the UPS cost of routing items, and in particular it doesn't run a script on every tick.  However, since this is a complex task the UPS cost cannot be negligible.  On my current laptop, a 10x10 array of smart routers with about 30 items requested runs at about 330 UPS when nothing else is going on -- or put another way, it's using 20% of the time budget.  I will look for ways to speed this up, but it's unlikely that you will be able to build your entire Pyanodon base on nothing but smart routers.

It is possible that Factorio 2 will enable this mod to have better performance, either by changing what can be connected to the circuit network and how (e.g. by removing the limit on inserter filters), or by allowing this mod
to replace several combinators with one smarter one, such as the Decider Combinator 2.0.

The trick of channeling everything over one green wire costs some performance.  It is possible that a future version will use hidden connections with multiple wires instead.

## Limitations

The design of routers, and especially smart routers, has many limitations, both inherently and due to my scripting skills.  Because they are very complex compound entities, there are likely to be bugs around building, destroying and blueprinting routers.  In particular:
* If you remove a router, then undoing the removal with control-Z won't restore its connections.
* If you remove a router I/O point, then undoing the removal with control-Z won't restore its connections or its trim settings (but will restore its request list).
* The feature that automatically connects router I/O points to chests triggers (when turned on in map settings) even when the router and chest were built from a blueprint where they're intentionally not connected.

## TODO list

See TODO.md on the github.  Some notable todo items:
* Better graphics
* Bring manual routers back to the polish level of smart ones, and re-enable them.
* Localization to languages other than English
* Integration with K2 and SE (working but needs more testing), pY, IR, AB, 248k, EI, etc
* Test and polish interactions
* Allow manual routers to request items when negative instead of positive, in the style of LTN