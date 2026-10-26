# Rebuild plan

Build a believable neighborhood discount-store simulator in Roblox. Keep approachable cooperative work and give players meaningful choices about stock, pricing, service and upgrades. **Cornerfield Market** is a working original identity.

## Tools and visual target

Use Houdini for procedural shell construction, modular shelves, layout variants and repeated detail. Use Blender for detailed individual props, manual geometry cleanup, UVs, baking and export preparation. Use Studio/Luau/Rojo for gameplay integration. The user selected a hybrid workflow and authorized a noncommercial prototype using the installed Apprentice environment. Preserve provenance; small alterations are not recorded as changing the source license.

Use warm masonry, muted painted metal, aluminum frames, tile, refrigeration glass and localized wear. Keep routes clear and forms readable at normal camera distance. Retain 152 × 100 studs as the initial footprint, then approve dimensions by walking it with avatars. The extracted v55 scene is a measured reference, not finished art.

## Play loop

1. Prepare: inspect inventory, order goods, choose prices and prepare tills.
2. Receive: unload cases and move stock into organized storage.
3. Trade: restock while shoppers browse; scan goods, accept payment and give change.
4. Maintain: clean, remove trash, resolve shortages and support other players.
5. Close: finish queues, reconcile cash/stock, review service and profit, choose upgrades.

Inventory, prices, payments and rewards belong on the server. Use integer cents, stable IDs, request validation and rate limits. Reserve stock exactly once and refund abandoned orders exactly once; existing `NpcStockOrders` behavior is the regression reference.

## Milestones

| ID | Result | Acceptance gate | Dependency |
| --- | --- | --- | --- |
| M0 | Baseline/setup | Reference, docs, board, Studio backup and measured performance | — |
| M1 | Store foundation | Editable scene, reviewed views and avatar-scale routes | M0 |
| M2 | Modular art kit | Full fixture/room coverage, UV/PBR/LOD review | M1 |
| M3 | Roblox integration | Correct import, separate interactions, bootstrap preserves art | M1; M2 incrementally |
| M4 | Playable slice | Delivery → stock → NPC purchase → checkout → close works with two players | M3 |
| M5 | Management | Ordering, demand, staff, upgrades, tutorial and recoverable saves | M4 |
| M6 | Release candidate | Device profiling, multiplayer soak, provenance and recovery verified | M5 |

Take one shelf and one checkout through the complete pipeline before multiplying the art kit. Bakery/pharmacy detail and optional companions must not delay proving the main retail loop.

## Migration

Preserve baseline revision `8b47f52bfb817ede3c7f556cdf503c6f848ddb25` and save a dated Studio backup with unsynced edits. Build art outside the generated active store. Add stable interaction adapters, then an opt-in imported-store mode and matching updater behavior. Use a separate Studio test place until route, collision, interaction and performance gates pass. Switch the default only after the new slice works; retain a rollback path before retiring old visual generation.

The first Blender pass is a foundation. It does not complete final fixture modeling, baked materials, Studio upload or the game. Targets of 30 FPS mobile and 60 FPS desktop are provisional, not measured. Establish mesh/texture budgets after profiling an imported aisle.

References: [Roblox modeling](https://create.roblox.com/docs/art/modeling), [Importer](https://create.roblox.com/docs/studio/importer), [Reimport](https://create.roblox.com/docs/art/modeling/reimport), [SideFX licensing](https://www.sidefx.com/Support/licensing/), [Blender LTS](https://www.blender.org/releases/4-5/).
