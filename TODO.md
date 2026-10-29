# Retail simulator checklist

Runtime: **standalone Godot**. Modeling: **Houdini + Blender**. Build through files and background commands. [GitHub project](https://github.com/users/Tboy450/projects/2). Earlier Roblox tasks are preserved in [the historical checklist](docs/ROBLOX_REBUILD_CHECKLIST.md); Studio/Rojo work is stopped.

## M0 — Project and workflow

- [x] Preserve Roblox v55 source, documentation and static reference.
- [x] Create the GitHub project and milestone cards.
- [x] Establish standalone project and pinned portable runtime setup.
- [x] Add background generation, import, test and portable packaging commands.
- [x] Capture and inspect a game frame through a script.
- [x] Add a GitHub Actions headless check.
- [ ] Refresh the board's older Roblox milestone text to this standalone scope. Existing API credentials lack GitHub Projects access; this checklist is current.
- [ ] Select target hardware and establish measured budgets.

## M1 — Store foundation

- [x] Generate editable Houdini shell, shelves and roof/HVAC source.
- [x] Import a 22.4 × 17.92 metre shell and nine shelf instances into Godot.
- [x] Add floor/wall collision, ceiling, practical lights, signs and movement.
- [x] Verify character landing and separate fixture collisions in the engine.
- [ ] Refine glazing, doors, storefront, masonry and ceiling details.
- [ ] Complete office, stockroom, staff room, bathrooms, cooler and dock layout.
- [ ] Review all routes at player scale and adjust provisional dimensions.
- [ ] Inspect exterior, checkout, aisle and overhead review views.

## M2 — Art kit

- [x] Author detailed Blender checkout with conveyor, scanner, till, terminal, printer and bagging return.
- [x] Import actual GLBs with materials and a source/hash manifest.
- [x] Keep merchandise dynamic and fixture collision separate from decoration.
- [x] Add readable shelf-edge price tags that follow price edits, shelf swaps and loaded progress.
- [x] Replace block merchandise with fictional Blender packaging: labelled tin, carton and pump bottle.
- [ ] Finish refrigeration, produce/bakery, pharmacy, receiving, staff/office and bathroom props.
- [ ] Add carts, baskets, parking, delivery/customer vehicles and service-yard assets.
- [ ] Replace the shopper capsule with a rigged, animated character.
- [ ] Finish UVs, PBR textures, wear, LODs and measured rendering budgets.

## M3 — Godot integration

- [x] Bind shelf, receiving and register interactions to simulation state.
- [x] Validate distance and prevent duplicate purchases/refunds.
- [x] Reserve real stock; restore unpaid orders on close or timeout.
- [x] Check actual shelf/checkout material imports in the engine.
- [x] Replace fixed shopper waypoints with shortest routes planned around the real collider footprints.
- [ ] Add shopper occupancy handling so several shoppers can share aisles and the checkout.
- [x] Add three separate product shelves, case matching, price editing and live receipt/display totals.
- [x] Swap the three front shelves' products while closed and empty; update labels, stock locations, shopper routes and saves.
- [x] Add pause/settings with sensitivity, movement speed, UI scale and keyboard navigation.
- [x] Add contextual first-day guidance for ordering, delivery, stocking, checkout and closing; follow reassigned shelves and resumed progress.
- [x] Add a remembered guide toggle and destination marker without locking normal gameplay.
- [x] Add minimize/restore controls to dashboard, guide and day report; remember layouts and provide compact-all/cursor shortcuts.
- [x] Add keyboard rebinding with conflict swaps, fixed pause/panel keys, saved preferences and live key hints.
- [x] Expand the catalog to a fourth product, Meadow Honey: middle-row shelf, packaging, select key, routes and version-3 save migration.
- [x] Make shelf slots and shopper routes data-driven: gondola list, per-product home shelf and planned routes.
- [x] Add keyboard panel selection and toggling, skipping hidden panels and returning focus to gameplay.
- [ ] Playtest the guide with new players and extend keyboard-only/accessibility coverage.

## M4 — First playable slice

- [x] Order, receive, carry and stock a twelve-unit case.
- [x] Shopper enters, takes stocked goods, queues and leaves after checkout.
- [x] Complete a sale in integer cents; conserve inventory and reconcile cash.
- [x] Close, restore unpaid reservations and produce a daily report.
- [x] Start a new day with cash/stock preserved and counters reset.
- [x] Pass automated engine tests and packaged startup verification.
- [ ] Human playtest the complete loop and resolve usability issues.
- [x] Expand to beans, oats and hand soap with separate stock, costs and prices.
- [ ] Expand beyond one active shopper and implement real queues.

## M5 — Management and multiplayer

- [ ] Suppliers, lead times, storage limits and delivery windows.
- [ ] Shopping lists, demand, patience, price sensitivity and satisfaction.
- [ ] Operating expenses, upgrades and progression.
- [ ] Cashier/stocker staff and reliable work queues.
- [x] Add versioned saves, atomic primary replacement, previous-valid backup, autosave and recovery tests.
- [x] Preserve cash, prices, stock, carried/incoming cases and daily progress across load.
- [x] Migrate version-1 saves to version 2 with a checked-in legacy fixture.
- [x] Migrate version-1 and version-2 saves to version 3 when the catalog grows, with a checked-in version-2 fixture.
- [ ] Validate long-running campaigns and add migrations for future schema changes.
- [ ] Authoritative co-op simulation, permissions and request validation.
- [ ] Complete two-player receive → stock → sell → close tests.
- [ ] Decide companion/lottery scope after the core game is stable.

## M6 — Polish and release

- [ ] Profile target hardware and optimize from measurements.
- [ ] Add sound, ambience, announcements and animation feedback.
- [ ] Test controller/scalable UI and assess mobile suitability.
- [ ] Add smaller production exports, versioning and crash handling.
- [ ] Run sustained store-day and multiplayer soak tests.
- [ ] Design custom project preview branding; the earlier watermark-replacement proposal remains unimplemented.
- [ ] Review asset inventory, attribution and distribution requirements.
- [ ] Publish a tested release with recovery instructions.
