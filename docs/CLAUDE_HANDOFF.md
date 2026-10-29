# Cornerfield Market — handoff for Claude

Prepared **October 29, 2026**. This is a continuation brief for an existing playable project, not a request to restart it.

## 1. Start here

The user is building **Cornerfield Market**, a more realistic retail store simulator inspired by an existing Roblox discount-store project. The current delivery target is a **standalone Godot game**. **Houdini and Blender create the assets; Godot runs the game.**

The user explicitly corrected an earlier detour into Roblox Studio imports. Develop through source files, command-line asset generation, background builds, headless checks and scripted renders. Preserve the Roblox material as reference. Do not resume Studio/Rojo work unless the user explicitly changes the objective.

The most recent completed work reduced HUD clutter and added keyboard control of its collapsible panels. The user has now requested this handoff. There is no unfinished code change from that pass.

Read these files before selecting another task:

1. `README.md` — running the game, controls and current scope.
2. `TODO.md` — current checked/unchecked work; authoritative over the older GitHub board text.
3. This document — architecture, constraints and continuation notes.
4. `docs/SAVES.md` — persistence behavior that must survive future changes.
5. `docs/REBUILD_PLAN.md` and `art/README.md` — design and asset workflow.

## 2. User preferences and working agreement

- **Never use or suggest the built-in image generator (`imagegen` / `image_gen`), including image editing or as a fallback.** This is the user's explicit standing instruction. Use Blender, Houdini, code-native graphics and other suitable tools instead.
- Prefer files, CLI tools and background generation over computer-use sessions. Do not ask the user to open Roblox Studio to test this standalone game.
- Use both Houdini and Blender where each is useful. The user did not choose an exclusive Blender-only pipeline.
- Work in small, concrete passes when the user says “continue” or asks for the next small steps. Finish, verify and report the selected pass.
- Avoid repeated confirmation questions for already authorized, reversible project work. Ask only when a decision actually needs the user.
- Keep progress updates concise and focused on findings and remaining work.
- Do not spawn additional agents without explicit user authorization or applicable project instructions requiring it.
- Do not turn routine development into another extended licensing discussion. Record actual provenance accurately. The earlier proposal to replace a visible watermark with project branding is recorded in `docs/DECISIONS.md`; it has **not** been implemented.
- Do not claim human playtesting, production readiness, multiplayer support or final artwork based on automated checks.

## 3. Repository and delivery state

| Item | Current value |
| --- | --- |
| Local Windows workspace | `C:\Users\Heemi\Documents\roblox-game` |
| Shell | PowerShell |
| Private GitHub repository | <https://github.com/Tboy450/Roblox-game> |
| Working branch | `codex/retail-store-rebuild` |
| Last gameplay commit before this handoff | `d914bd6` — Add keyboard navigation for collapsible HUD panels |
| Existing draft pull request | <https://github.com/Tboy450/Roblox-game/pull/1> |
| GitHub project | <https://github.com/users/Tboy450/projects/2> |
| Portable local game | `builds/CornerfieldMarket-Prototype.zip` |
| Current checked-in test result | 210 checks passed, zero failures |

The working tree was clean when this handoff was started. This handoff and its README link are documentation additions after `d914bd6`.

The game has not been merged or published as a release. The portable ZIP is local and ignored by Git. A fresh clone does not include that ZIP, downloaded tools or the large native DCC outputs.

Recent implementation history, newest first:

- `d914bd6` — keyboard navigation for collapsible HUD panels; 210 checks.
- `7656ad1` — contextual first-day guide and compact panel controls; 204 checks.
- `b469e33` — safe shelf swaps, pause/settings and save migration.
- `5ce6600` — protect unsupported future save versions without an arbitrary version ceiling.
- `dbf628f` — multi-product pricing and recoverable saved progress.
- `6be6a78` — initial standalone prototype.

## 4. Run, test, render and package

Run from the repository root:

```powershell
# Needed only if the pinned portable runtime is absent.
.\scripts\setup-godot.ps1

# Imports then launches the playable game. This opens a game window.
.\scripts\run-game.ps1

# Headless import and real engine tests.
.\scripts\test-game.ps1

# Actual GPU-rendered review frames, driven by a script.
.\scripts\render-game-preview.ps1

# Export PCK, bundle runtime/notices, smoke-test packaged startup, create ZIP.
.\scripts\package-game.ps1

# Only needed when regenerating modeling output.
.\scripts\prepare-game-assets.ps1
```

The game scripts accept `-Godot C:\path\to\godot_console.exe` where applicable. The pinned runtime is **Godot 4.7.2**, in `.tools/godot/`. The project uses the GL Compatibility renderer, a 1280 × 720 design viewport, canvas-item stretch and 60 Hz physics. `project.godot` retains a `4.6` feature declaration; the actual setup/test/package tooling pins 4.7.2.

`scripts/test-game.ps1` checks both engine exit codes and logs for script/import errors, then validates `builds/test-report.json`. Logs are in `builds/import.log` and `builds/tests.log`. The checked-in snapshot is `docs/standalone-test-report.json`.

The package contains `CornerfieldMarket.exe`, `CornerfieldMarket.pck`, instructions and notices. Keep the EXE and PCK together. It currently bundles the official **editor runtime in game mode**, so it is larger than a production export. Packaging runs the renamed executable with `--headless` and `-- --verify-prototype`, requiring the `CORNERFIELD_SCENE_READY` marker.

In the previous Codex environment, native executables and some Git/network commands needed an approved sandbox escalation because of runtime/DLL restrictions. That is an environment issue, not a requirement to change the game. Use the permissions available in your environment; do not disable safeguards or expose credentials.

## 5. What is playable now

- First-person movement with camera look, fixture collision, ceiling, practical lighting and signs.
- A 22.4 × 17.92 metre store shell, nine shelf instances and a detailed checkout imported as real GLBs.
- Four interactive product shelves: Harvest Beans, Morning Oats and Cedar Hand Soap on the front row, Meadow Honey on the middle-row left shelf.
- Product selection, supplier case ordering, four-second delivery, receiving, carrying and partial stocking.
- Separate stock, supplier costs and editable selling prices per product.
- One active shopper at a time, selecting stocked goods in rotation, walking a planned route to its shelf, the checkout and the door.
- Pickup-time quoted prices, real receipt/register totals, checkout, timeout cancellation and departure.
- Store open/close, unpaid-stock restoration, reconciled daily report and next-day progression.
- Versioned saves, previous-valid backup, autosave, manual save/load and version-1 migration.
- Closed/empty shelf reassignment that updates signs, stocking, shopper routes and saves.
- Pause/settings with sensitivity, movement speed, UI scale and guide preference.
- Contextual first-day guide with a world destination marker.
- Collapsible dashboard, guide and day-report panels, remembered independently of game progress.

The start balance is **$500.00**. Cases contain 12 units, and each product shelf has capacity 12.

| Stable product ID | Display name | Unit supplier cost | Default unit price | Case cost |
| --- | --- | --- | --- | --- |
| `beans` | Harvest Beans | $0.70 | $1.49 | $8.40 |
| `oats` | Morning Oats | $1.10 | $2.49 | $13.20 |
| `soap` | Cedar Hand Soap | $1.25 | $2.99 | $15.00 |
| `honey` | Meadow Honey | $1.80 | $3.99 | $21.60 |

## 6. Controls and panel behavior

Default keys are listed below. Every gameplay key can be rebound under Pause → Key bindings; Esc, Tab, F2 and the panel-mode arrows/Enter/Space stay fixed.

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| E | Interact with the nearby receiving table, matching shelf or checkout |
| 1 / 2 / 3 / 4 | Select beans / oats / soap / honey |
| B | Buy a case of the selected product |
| [ / ] | Adjust selected product's sale price by ten cents |
| O | Open or close the store |
| N | Begin the next day after closing/report |
| R | Reassign a nearby shelf while closed; both affected shelves must be empty |
| F5 / F9 | Save / load progress |
| Esc | Pause/settings; pauses store simulation |
| H | Toggle first-day guidance |
| F2 | Compact or restore all HUD panels, including while paused |
| Tab during gameplay | Enter/exit panel mode |
| Arrows in panel mode | Select visible panels, wrapping and skipping hidden panels |
| Enter / keypad Enter / Space in panel mode | Minimize/restore the focused panel |
| − / + panel button | Minimize/restore an individual panel |

The dashboard starts compact but retains day, store status, cash and selected goods. Entering panel mode focuses its button, releases the mouse and disables player movement/gameplay shortcuts. **Store time continues in panel mode.** Esc pauses the game and exits panel mode safely. Tab back to movement releases GUI focus. In the pause menu, Tab retains normal menu-navigation behavior.

The latest keyboard pass is in `store.gd::_input()` and `_focus_panel()`, with regression checks in `panel_tests.gd`. Do not accidentally turn Tab into ordinary focus traversal during gameplay and lose the exit-to-movement behavior.

## 7. Code map

| File | Responsibility |
| --- | --- |
| `game/main.tscn` | Minimal root scene using `store.gd` |
| `game/scripts/store.gd` | Builds environment, fixtures and HUD; binds state to visuals/actions; shopper routes; persistence integration; guide and pause/panel control |
| `game/scripts/retail_state.gd` | RefCounted retail simulation, transaction validation, ledger, shelf mapping, save snapshots and migration/validation |
| `game/scripts/catalog.gd` | Stable product IDs, names, costs, default prices, colors and initial shelf positions |
| `game/scripts/save_store.gd` | Validated local file writing, backup/recovery and future-save protection |
| `game/scripts/player.gd` | CharacterBody3D movement, look, camera and interaction signal |
| `game/scripts/player_settings.gd` | Validated separate ConfigFile preferences and physical-key bindings |
| `game/scripts/pause_menu.gd` | Pause overlay, sliders, checkbox, save/load/quit controls |
| `game/scripts/store_routes.gd` | Visibility-graph route planner over inflated collider footprints (AStar2D); shoppers use it for every leg |
| `game/scripts/first_day_guide.gd` | Derives useful next step from state without adding saved tutorial flags |
| `game/scripts/foldable_panel.gd` | Shared panel header, toggle button, collapsible body and change signal |
| `game/tests/run_tests.gd` | Aggregate real-engine test runner and JSON report |
| `game/tests/progression_tests.gd` | Multi-product accounting, quoted prices and real save-file behavior |
| `game/tests/usability_tests.gd` | Shelf mapping, migration, pause/settings and scene integration |
| `game/tests/guide_tests.gd` | Tutorial progress, recovery cases, markers and preference behavior |
| `game/tests/panel_tests.gd` | Minimize/restore, keyboard focus, visibility, persistence and gameplay guards |
| `game/tests/price_tag_tests.gd` | Shelf-edge tag text, fit, placement, price edits, swaps and load |
| `game/tests/route_tests.gd` | Planner geometry, every slot's shopper legs against real colliders, select keys, home gondolas |
| `game/tests/walk_tests.gd` | Real player capsule walks to every shelf and Receiving and restocks honey on foot (automated, not a playtest) |
| `game/tests/packaging_tests.gd` | Packaging textures, size, origin, aisle-facing labels, triangle budget and deck placement |
| `game/tests/binding_tests.gd` | Binding validation, swaps, settings files, capture UI, rebound gameplay/movement and hints |
| `game/tests/capture_preview.gd` | Staged actual-engine screenshots without editor interaction |
| `game/tests/fixtures/save-v1.json`, `save-v2.json` | Checked-in historical save migration fixtures (v2 has swapped shelves and a delivery in transit) |

`store.gd` is still a fairly large scene/controller script, around 740 lines. Keep simulation rules in `retail_state.gd` rather than duplicating them in HUD code. A later extraction of shopper/navigation or HUD responsibilities can be useful, but avoid a broad refactor just to start the handoff.

## 8. Invariants to preserve

### Transactions and inventory

- Money is **integer cents** throughout. Do not replace it with floating-point currency.
- Supplier purchases debit cash immediately; cost of goods sold is recognized on sale. Daily gross profit and daily cash movement are different measures.
- `reserve()` creates an order ID and snapshots the selling price. Later price changes must not change an existing basket total.
- `checkout()` and `cancel()` act on an order once. Repeated checkout/refund calls must not create money or units.
- Reserved shelf capacity remains occupied. Restocking must not consume capacity needed when an unpaid basket is restored.
- Closing and shopper timeout restore unpaid goods once.
- There is one incoming/receiving pipeline and one carried case; case product identity matters. Partial restocking is supported.
- `shelf_assignments` is a bijection from four physical slots to four products. Slot IDs are each product's home shelf (`shelf_x`, `shelf_z` in `catalog.gd`) and happen to be named `beans`, `oats`, `soap`, `honey`; these are **not always the product occupying that slot** after reassignment.
- Resolve a product's current physical slot with `slot_for_product()`. Update interactions, visuals, guide destinations and shopper paths together.
- Swaps are permitted only while closed and when both affected shelves are empty, including no reserved stock.
- Legacy bean aliases/constants remain for earlier tests; they are not the full multi-product model.

### Saves and preferences

- Gameplay schema is **version 3**. Version 1 gains the original shelf mapping; every older save gains products whose catalog `since` is newer than it, empty at default price on their home shelf. Adding a product means bumping `SAVE_VERSION`, giving the product that `since`, and adding a fixture test.
- Validate a complete candidate before mutating live state. Failed load must leave the running game unchanged.
- Newer unsupported schema versions must not be overwritten or silently replaced by an older backup. Do not add an arbitrary upper version ceiling that weakens that protection.
- Primary: `user://cornerfield-save.json`; previous valid backup: `.bak`. Use Godot's user-data location, not a hard-coded workspace path.
- Snapshot unpaid units back into saved shelf counts without mutating the live shopper or counting a restart as a walkout.
- Load starts closed, clears transient shoppers/reservations and preserves cash, inventory, prices, mapping, deliveries, cases and day totals. Player position and shopper routes are not saved.
- Preserve temporary-write/readback/backup/rename protections in `save_store.gd`.
- A failed load pauses autosaving. Manual save/load lets the user retry. Do not immediately overwrite a damaged or future save via autosave.
- Settings live separately in `user://cornerfield-settings.cfg`. Loading a game must not revert control/UI preferences.
- Boolean settings remain booleans: guide visibility and each panel's collapsed state. Missing new settings get defaults; invalid input is rejected as a whole.
- Key bindings live in the settings file's `[bindings]` section as physical keycodes. Every action needs its own key; a used key swaps rather than duplicates. Esc, Tab and F2 are never bindable. Route new gameplay shortcuts through `Settings.ACTIONS` and `preferences.action_for()`, and show keys with `_key()` rather than literal letters.
- Sensitivity range: 0.0005–0.006; movement speed: 2–6.5; UI scale: 0.8–1.25.
- The first-day guide derives its state from existing gameplay data; it currently needs no save-schema bump.
- Local saves assume one writer. Multiple concurrent game instances are not supported.

### Input and verification

- Pause gates movement, look, interactions, shoppers, deliveries and autosave countdown; pause-menu save/load remains usable.
- Panel mode blocks movement and gameplay shortcuts but intentionally keeps store simulation running.
- Headless Godot cannot provide normal OS mouse capture. Look tests call the shared `player.apply_look()` operation; do not misdiagnose headless mouse mode as a runtime camera failure.
- Tests use unique ignored directories under `builds/`. Scripted renders and package smoke tests disable gameplay persistence. **Never run a new automated scenario against the user's real save.**

## 9. Houdini / Blender pipeline

Runtime assets are versioned in `game/assets/generated/`:

- `store-shell.glb` — Houdini shell, 7,932 triangles in the current engine report.
- `shelf.glb` — Houdini shelving, 10,368 triangles per source asset.
- `checkout.glb` — detailed Blender checkout, 84 mesh instances / 25,144 triangles in the report.
- `merch-beans.glb`, `merch-oats.glb`, `merch-soap.glb`, `merch-honey.glb` — Blender packaging with embedded labels, in metres (1,344 / 12 / 1,836 / 1,440 triangles). The generator is byte-reproducible.
- `manifest.json` — tool/source information, scale and hashes.

The checked-in GLBs allow a fresh clone to run without Houdini or Blender. Larger native/intermediate files are ignored under `art/exports/`, but exist in the current workspace, including:

- `cornerfield-prototype.hipnc` and `cornerfield-review.hipnc`.
- `checkout-01.blend` and `checkout-01.glb`.
- `gondola-01.obj` / `.mtl` and `store-shell.obj` / `.mtl`.
- DCC review images and manifests.

Current local tools:

- Houdini: `C:\Program Files\Side Effects Software\Houdini 22.0.466\bin\hython.exe`.
- Blender: `.tools/blender-4.5.15-windows-x64/blender.exe`.
- Houdini source environment is Apprentice; native source and provenance remain recorded.

`scripts/prepare-game-assets.ps1` accepts `-Hython` and `-Blender`. It builds missing native/intermediate inputs, exports the compact shell, then converts/prepares runtime GLBs. It **reuses existing** shelf OBJ and checkout GLB if present: editing a generator does not by itself guarantee those cached intermediates are rebuilt. Run the relevant generator/export explicitly when changing those assets; do not delete unrelated native work.

Main authoring scripts:

- `art/houdini/build_store.py`, `store_geometry.py`, `review_and_export.py`.
- `art/houdini/export_game_shell.py` — compact runtime shell variant; does not overwrite the larger native source.
- `art/blender/build_store.py`, `validate_checkout.py`.
- `art/blender/build_packaging.py` — fictional label art (Cycles-rendered, Noto Sans CJK Latin glyphs, OFL) and merchandise GLBs.
- `art/blender/prepare_godot_assets.py` — OBJ conversion, checkout copy, runtime manifest.

Scale and axes matter: **one source unit is 0.28 metres in Godot**. Houdini is Y-up; Blender is Z-up and glTF export converts it to Y-up. OBJ conversion explicitly chooses Y-up. The runtime shell is 80 × 64 source units. Collision proxies, lights, merchandise and gameplay UI belong to Godot; do not bake dynamic inventory into fixture meshes.

Current materials pass actual import checks, but they are prototype materials, not finished PBR work. Merchandise uses Blender packaging GLBs with printed labels; the shopper is still a capsule.

## 10. Verification and evidence

The last gameplay pass ran **210 passing checks locally** and rebuilt the portable ZIP with a passing startup smoke test. This handoff creation does not itself rerun gameplay tests. See the checked-in report for the recorded baseline.

GitHub Actions is configured in `.github/workflows/standalone.yml` to run headless Godot checks on Linux and upload JSON reports. Push/PR path filters cover `game/**`, `scripts/*game*.ps1` and the workflow. Documentation-only commits do not necessarily start it. Verify the current run status if you need to claim hosted CI success for a new head; do not infer it from an older successful run.

Versioned scripted review images:

- `art/previews/godot-prototype.png` — main aisle/gameplay.
- `art/previews/godot-checkout.png` — imported checkout.
- `art/previews/godot-settings.png` — pause menu at 125% scale.
- `art/previews/godot-controls.png` — key bindings page at 125% scale.
- `art/previews/godot-day-report.png` — closed-day report.
- `art/previews/godot-compact.png` — compact panel layout.
- `art/previews/godot-price-tags.png` — shelf-edge price tags close-up.
- `art/previews/godot-packaging.png` — soap packaging close-up.
- `art/previews/godot-honey.png` — middle-row honey shelf close-up.

These are actual engine frames. The final keyboard-only pass changed input behavior and documentation; it did not regenerate screenshots. Rendering uses a script and hidden process, not UI automation. Inspect new frames when changing visual layout. Existing tests are meaningful regression coverage; add focused tests for changed behavior rather than mirroring implementation details.

## 11. GitHub access and project-board limitation

The existing GitHub connector returned 404 for the private repository, and the installed `gh` authentication was expired during prior work. Normal Git push worked through Git Credential Manager. An ignored local helper, `builds/github-api.ps1`, was used to make authenticated REST calls through the configured credential manager without printing credentials.

Do not copy tokens into source, this handoff, logs or prompts. Prefer your own available authenticated tooling. The helper is local convenience, not a portable project dependency; inspect its implementation before reuse.

The current credential could access repository/PR/workflow APIs but lacked GitHub Projects scopes. Consequently the board's older milestone descriptions still reflect Roblox scope. **`TODO.md` and the PR describe the standalone scope.** That board refresh is explicitly unchecked. Do not claim it was updated, repeatedly retry the same insufficient scope, or switch to browser automation just to conceal that limitation.

Continue using the existing draft PR for ordinary continuation work. Do not create duplicate projects/PRs, merge or publish a release unless requested. Branch naming convention is `codex/` for new branches unless the user directs otherwise.

## 12. Remaining work and a sensible next pass

This is a playable single-player prototype, with the following major limits:

- Planned shopper routes, but one active shopper and no queue/occupancy system; routes ignore other walkers.
- No demand model, shopping lists, price sensitivity, staff, expenses, upgrades or co-op.
- No complete office/stockroom/staff/bathroom/cooler/dock layout.
- Placeholder shopper; prototype packaging without LODs; incomplete storefront detail, fixture textures and supporting props.
- Keyboard rebinding only: no mouse-button or controller bindings, controller validation or broad accessibility review.
- No target-hardware budgets, production export optimization or sustained campaign/multiplayer soak testing.
- Human playtesting of the guide, navigation and complete store day remains pending.

If the user simply says “continue,” select **one small unchecked task** from `TODO.md`. Shelf price tags, keyboard rebinding, merchandise packaging and a fourth product are done. Another product needs a catalog entry (`shelf_x`/`shelf_z`, `model`, `since`), a `select_N` binding, packaging in `build_packaging.py` and a save-version bump. Its home shelf must be one of `store.gd` `GONDOLAS`; routes are planned automatically from the colliders, and `route_tests.gd` checks every slot. Navigation and multiple shoppers are larger changes and should be broken into stages with reservation/cancellation tests retained.

Suggested continuation procedure:

1. Check working tree and current branch; preserve any newer user changes.
2. Read the relevant implementation and tests before editing.
3. State the small deliverable and implement it in the standalone game.
4. Run appropriate checks. For gameplay changes, run `test-game.ps1`; for visual changes, also render and inspect; refresh the package if delivering a playable change.
5. Update `TODO.md` only for completed work; update README controls/behavior and the checked-in report when applicable.
6. Commit/push within existing authorization, then summarize what changed, evidence and any material limitation. Do not claim completion of unchecked human or production work.

## 13. Legacy material to preserve

`src/`, `plugins/`, Roblox scripts and the earlier integration experiment remain in the repository. Their presence does not make Roblox the current engine. The reference revision is `8b47f52bfb817ede3c7f556cdf503c6f848ddb25`; static exports exclude unsynced Studio edits and live shoppers/vehicles.

Historical references: `docs/LEGACY_V55.md`, `docs/ROBLOX_REBUILD_PLAN.md`, `docs/ROBLOX_REBUILD_CHECKLIST.md`, `docs/ROBLOX_ART_PIPELINE.md` and `docs/ASSET_IMPORT_TEST.md`. Preserve them, but use the current standalone docs for new work.

## 14. Copyable kickoff prompt

> Continue the existing Cornerfield Market project in `C:\Users\Heemi\Documents\roblox-game`. Read `docs/CLAUDE_HANDOFF.md`, `README.md`, `TODO.md` and any applicable repository instructions first. This is a standalone Godot game with Houdini + Blender assets; Roblox is reference only. Use source files, background commands, real-engine tests and scripted renders. Never use or suggest imagegen/image_gen. Preserve current saves, accounting invariants and the compact panel controls. Check the current Git state, choose one small unfinished checklist item, implement and verify it, update the docs/checklist, and report the completed result. Do not restart the project, resume Roblox Studio work, merge the PR or publish a release without a new request.
