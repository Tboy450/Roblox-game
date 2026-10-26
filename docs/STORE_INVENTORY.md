# Store inventory and migration contract

Blueprint v55, revision `8b47f52bfb817ede3c7f556cdf503c6f848ddb25`. The reference extraction contains **2,108 static nodes**: 1,383 Parts, two Seats, one SpawnLocation, 43 Models, 102 ProximityPrompts, 33 PointLights, 272 SurfaceGuis and 272 TextLabels.

The extractor executes the actual blueprint using repository construction doubles. It records geometry, orientation, color/material, hierarchy, attributes and selected UI/prompt/light fields. It is a modeling reference, not a lossless Roblox interchange. Runtime vehicles, shoppers, companions, scripts, player state and unsynced Studio work are outside its scope.

| Area | Details to retain |
| --- | --- |
| Shell | 152 × 100 studs; entrance, front glazing, walls, floor, ceiling, roof, posts |
| Sales floor | Nine shelf units, produce crates/fruit, freezer bank, endcaps, aisle signs, product boards and pricing |
| Front end | Player/NPC registers, scanner/belt, till, card terminal, monitor, printer, bags, service desk and entry queue |
| Stock room | Rack bays, cases, table, inventory board, pallet jack, backstock |
| Cooler | Door, racks, case, thermometer, drain, lights and checks |
| Receiving | Dock door, seals/leveler, pallets, jack, forklift prop, shipping/receiving, schedule and controls |
| Bakery | Oven, prep, mixer, bread/cooling racks and menu |
| Pharmacy | Pickup/dropoff, scanner, cabinet, fridge, waiting seat and privacy divider |
| Bathrooms | Two rooms, privacy doors/occupancy behavior, toilets, basins and fittings |
| Staff/manager | Seating, table, kitchenette, appliances, clock, boards, desk, safe and paperwork |
| Outside | Fourteen ordinary bays, two reserved bays/access aisles, sidewalks, pickup, trees, lamps, bench, bins, carts, service yard |
| Runtime/UI | Customer cars/shoppers/queues, companions, register/shelf/stock/open-close UI and stats |

## Current bindings

- Root: `Workspace.RetailStore`; attributes carry open/closing state, inventory/service metrics, opening till, drawer cash, tender, change, net sales and customer counts.
- Shelves: stable identity plus `ShelfDepartmentIndex`, `ShelfProductIndex`, `ShelfCapacity`, `ShelfStock` and descriptive fields. Code currently looks for `TopSign`, `ProductSelector`, `ShelfControl`, `RestockControl` and attributes on descendants.
- Registers: current logic reads `CashDrawer`, `StatusDisplay`, `MonitorScreen`, `ReceiptPaper` and other named targets. Price/status text must remain runtime UI.
- Doors: preserve state, moving guard, prompt, pivots and occupied-doorway checks; a door mesh does not implement them.
- Navigation: `Outdoor.NpcTraffic` holds road/drive routes, entry markers, shops, register queue/spot, four queue slots, cashier and fourteen parking markers. Reserved bays stay outside NPC parking.
- Prompts: carry action attributes and activation distances onto explicit anchors; remove duplicate active prompts when retiring old props.
- Remotes: preserve `RetailRemotes` contracts and server validation during migration, including NPC reservation/cancellation/checkout bindables.
- UI: `StarterGui.RetailHudRunner` is independent of model art and remains until deliberately replaced.

Target hierarchy (requires adapter implementation):

```text
RetailStore
  Visuals
  Collisions
  InteractionAnchors
  Navigation
```

Give meshes stable unique names for reimport. The bootstrap and Studio updater currently regenerate the old map. Do not clear the live store or put imported art under that generated root until M3 supports it.
