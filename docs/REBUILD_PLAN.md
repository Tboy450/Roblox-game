# Standalone retail simulator plan

Build **Cornerfield Market**, a neighborhood discount-store simulator in Godot. Houdini creates procedural architecture and repeated fixtures; Blender creates detailed props, UVs and baking. Roblox v55 supplies design/system references. Repeated editor automation is outside the current workflow.

## Delivery workflow

Source code and procedural geometry are the source of truth. Run Houdini/Blender in fresh background processes, import GLBs headlessly, execute engine tests, render review frames by script and package a runnable prototype. GDScript creates the playable scene and HUD. GitHub Actions checks versioned runtime assets without requiring a DCC installation.

The first shell is 22.4 × 17.92 metres, scaled from an 80 × 64 source-unit Houdini variant. The conversion is **0.28 metres per source unit**, Y up. The runtime manifest records source tools and hashes. Keep visuals, stock, collision and gameplay actions separate.

## Play loop

1. Order cases and manage cash.
2. Receive, carry and restock merchandise.
3. Open and serve shoppers who consume real inventory.
4. Resolve unpaid baskets without creating or losing units.
5. Close and review revenue, cost of goods, purchases and cash movement.
6. Carry cash/inventory into the next day, then expand management and upgrades.

The prototype implements beans, oats and hand soap with one active shopper. Money uses integer cents. Inventory includes receiving, carried, shelf and reserved quantities; sales/cancellations consume order IDs once. Reserved capacity prevents cancellation from overfilling a restocked shelf. Purchases affect cash when ordered; cost of goods affects profit when sold. Prices are editable, with active baskets retaining their pickup quote. Staff and networking are not implemented yet.

Version-2 saves preserve product inventory/prices, shelf assignments, cash, day, delivery/carry state and daily counters. Version-1 progress migrates with its original shelf layout. Resume starts closed and normalizes unpaid baskets into shelf stock. Validated temporary writes replace the primary, retaining a previous-valid backup. Invalid loads never partially modify live state; unsupported future schemas are left unchanged. See [save behavior](SAVES.md).

The three front shelves can swap product assignments while both affected shelves are empty and the store is closed. Runtime stock, labels and shopper routes use the current mapping. Esc pauses simulation and opens control settings, with manual save/load and a save-and-quit action. Preferences are separate from store progress.

First-day guidance derives the next action from real progress and follows reassigned fixture locations. H and a pause-menu checkbox control visibility. The dashboard, guide and report minimize to title bars; F2 compacts/restores them together, and Tab exposes a panel cursor while store time continues. Their layout preferences persist separately from store accounts.

## Milestones

| ID | Deliverable | Acceptance gate |
| --- | --- | --- |
| M0 | Background workflow | Source, docs, board, import/test/render/package commands |
| M1 | Foundation | Reviewed shell, movement, lighting and usable routes |
| M2 | Art kit | Complete room/fixture coverage, materials, UVs and LODs |
| M3 | Godot integration | Stable actions, collision, stock visuals and navigation |
| M4 | Playable slice | Receive → stock → sell → close, tests and human playtest |
| M5 | Management/co-op | Demand, staff, upgrades, persistence and two-player flow |
| M6 | Release | Profiling, soak tests, production exports and recovery |

## Verification and limits

`scripts/test-game.ps1` checks actual engine imports, simulation and scene physics. The portable pack receives a startup smoke test. A scripted GPU frame is inspected separately. These do not prove human usability, navigation at scale, multiplayer correctness or target-hardware performance.

Shoppers currently follow fixed waypoint routes and use capsule placeholder art. The three front shelves are interactive. Final packaging/textures, lighting and most supporting rooms remain unfinished. Expand content after the loop is reviewed.

The [earlier Roblox plan](ROBLOX_REBUILD_PLAN.md) is preserved. A future Roblox version could reuse art/data but would require platform-specific gameplay integration; it is not the current objective.

References: [Godot command-line workflow](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html), [Godot runtime](https://godotengine.org/download/windows/).
