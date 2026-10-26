# Retail Store Simulator — To-do

[GitHub project](https://github.com/users/Tboy450/projects/2). This file holds detailed acceptance criteria; board cards track milestones. A generated model is not a completed Studio integration.

## M0 — Baseline and setup

- [x] Inspect v55 source and existing systems; record baseline revision.
- [x] Preserve legacy README and extract static geometry, hierarchy, attributes, signs and prompts.
- [x] Write rebuild README, design plan, art pipeline and migration inventory.
- [x] Create GitHub rebuild project.
- [x] Populate seven milestone cards and set the existing repository as the project's default.
- [ ] Save dated Studio place backup including unsynced edits before replacing the live map.
- [ ] Capture Studio screenshots/video including runtime vehicles, NPCs and companions.
- [ ] Measure baseline FPS, memory, triangles, instances and NPC timing on target devices.

## M1 — Store foundation

- [x] Choose original working identity and grounded visual direction.
- [x] Generate editable Houdini shell, roof/HVAC and nine parametric shelf units.
- [x] Generate and visually inspect the Blender checkout prop; export GLB and anchor/collision manifest.
- [ ] Visually review the Houdini store in its native viewport and refine the foundation.
- [ ] Approve 152 × 100 stud footprint using real avatar scale.
- [ ] Rebuild storefront: masonry, glazing frames, entrance, canopy, signs, bollards, gutters, roof and HVAC.
- [ ] Rebuild shell: tile, wall trim, ceiling structure and practical lighting.
- [ ] Validate routes between parking, entrance, checkout, aisles, rooms and dock.
- [ ] Approve exterior, interior checkout, aisle and overhead views.

## M2 — Modular fixtures and detail

- [ ] Shelving: uprights, base decks, perforated backs, brackets, endcaps, price rails and labels.
- [ ] Checkout: conveyor, divider bars, scanner, scale, card reader, monitor, printer, drawer and bags.
- [ ] Fictional product packaging: food, drinks, household, cleaning, health and seasonal goods.
- [ ] Refrigeration: glass doors, seals, handles, racks, vents and shelf lighting.
- [ ] Produce/bakery: crates, fruit, bread racks, prep, mixer and oven.
- [ ] Pharmacy: counter, pickup/dropoff, locked storage, scanner and waiting area.
- [ ] Stock/dock: cartons, racks, pallets, pallet jack, receiving desk, dock door and controls.
- [ ] Staff/office: seating, table, kitchenette, lockers, clock, board, desk, safe and paperwork.
- [ ] Two bathrooms: privacy doors, toilets, sinks, mirrors, dispensers, bins and fittings.
- [ ] Exterior: carts, baskets, bench, bins, reserved bays/access aisles, signs, pickup and service yard.
- [ ] Vehicles: delivery truck/van and customer cars with correct cabins and wheels.
- [ ] UVs, baked PBR maps, reusable texture sets, LODs and collision proxies.

## M3 — Roblox import and interactions

- [ ] Import one shelf and checkout in a separate test place; verify scale, axes, pivots and materials.
- [ ] Import modular batches; record asset IDs and stable source names in a manifest.
- [ ] Separate Visuals, Collisions, InteractionAnchors and Navigation.
- [ ] Replace decorative-name bindings with stable interaction IDs/adapters.
- [ ] Preserve shelf attributes, checkout targets, prompts, door pivots and NPC markers.
- [ ] Add explicit opt-in imported-store mode to bootstrap and updater.
- [ ] Confirm Play/update cannot overwrite imported art or duplicate prompts.
- [ ] Walk all room/parking routes and test door occupancy with real avatars.

## M4 — First playable slice

- [ ] Receive a delivery, move a carton and stock a shelf with server-owned inventory.
- [ ] Assign products and validate prices.
- [ ] NPC parks, enters, chooses stocked goods and queues without getting stuck.
- [ ] Complete checkout; stock and till reconcile in integer cents.
- [ ] Close mid-shopping/checkout; refunds happen once and all customers leave.
- [ ] End-of-day report shows revenue, cost, margin, stock and satisfaction.
- [ ] Repeat with two players; reject duplicate sales, remote spam and out-of-range actions.

## M5 — Management and progression

- [ ] Suppliers: case quantities, lead times, delivery windows, costs and storage capacity.
- [ ] Demand: shopping lists, price sensitivity, stock availability and patience.
- [ ] Operating costs and readable daily profit/loss.
- [ ] Product, fixture, staff and store upgrades.
- [ ] Cashier/stocker staff with bounded queues and reliable navigation.
- [ ] Co-op roles, permissions and handoffs.
- [ ] Persistence: versioned schemas, migrations, retries, ownership and recovery.
- [ ] Tutorial covering a complete store day.
- [ ] Decide companion/lottery scope after the core loop works.

## M6 — Polish and release

- [ ] Profile real devices, streaming, draw calls, texture memory and NPC cost.
- [ ] Meet provisional targets: 30 FPS on agreed mobile baseline, 60 FPS on target desktop.
- [ ] Optimize repeated meshes, materials, LODs and collision based on measurements.
- [ ] Test phone, controller and keyboard UI; scalable text and sound controls.
- [ ] Add ambience, checkout/footstep sounds, announcements and useful feedback.
- [ ] Design custom project branding/watermark for previews; the proposed replacement of an existing tool watermark is not implemented.
- [ ] Complete regression tests and sustained multiplayer delivery/open-close soak.
- [ ] Review asset provenance, fictional branding and production tool licenses.
- [ ] Verify save migration, backup and rollback, then publish the release place.
