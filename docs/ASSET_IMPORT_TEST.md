# Shelf and checkout integration test

This is a separate test of real imported assets with existing shelf/register mechanics. It is not the replacement full-store map and does not yet run NPC shopping, deliveries or a complete store day.

## Open the test place

Run `scripts/test-retail.ps1` to build `art/exports/retail-asset-test.rbxlx`, then open that file in Roblox Studio. Alternatively, use a new blank place and connect `scripts/serve-asset-test.ps1` at **localhost:34873**. The normal game remains on **34872**. Do not connect the asset test project to the production place.

The test project sets `ReplicatedStorage.RetailMapConfig.Mode` to `AssetTest` and preserves unknown children of `ServerStorage.RetailAssetLibrary` during Rojo sync. Templates live there, outside the runtime scene.

## Import and prepare

1. Install the supplied `plugins/RetailAssetKit.lua` in Studio's local Plugins folder and restart Studio. Also update `BuildRetailStore.lua` to updater v53 if using the legacy Retail Game plugin; earlier installed copies do not have the new imported-art guards.
2. Use Studio's 3D Importer to import `checkout-01.glb`. Import it as visual geometry, without extra cameras, lights, collision objects or scripts. Keep its authored orientation.
3. Select its one root Model and click **Retail Asset Kit → Prepare Checkout**.
4. Import `gondola-01.obj` with `gondola-01.mtl` beside it. Its source axis is Y up. Select the root Model and click **Prepare Shelf**.
5. Preparation clones the original import, normalizes uniform unit conversion, checks all three dimensions, restores the authored origin, and stores a prepared copy in `ServerStorage.RetailAssetLibrary`. It does not overwrite an existing prepared copy. A wrong axis or changed silhouette is an error rather than a guessed correction.
6. Click **Build Kit Test**, then Play. Alternatively press Play directly once both templates are prepared.

Use Upload to Roblox in the importer when persistent cloud mesh IDs are needed; record returned IDs in the asset inventory. No asset IDs have been created or invented by these source scripts. A DCC export/round-trip check does not verify Studio's importer.

## Test the interactions

- Clock in at the visible TimeClock control.
- Take products from the shelf; its twelve dynamic stock slots should disappear with the server-owned count.
- Collect stock at StockCollection, then restock. Change the shelf product through ShelfControl and check product/color/price updates.
- Open the player register through its scanner or drawer target and complete the existing register UI flow. Check live display and receipt updates.
- Walk around the cabinet, bagging return and shelf. Decoration must not snag avatars; collision is provided by simple separate proxies.
- Stop and restart Play. The prepared templates stay unchanged; the saved test store is preserved rather than rebuilt over imported geometry.
- Check Studio Output for errors and confirm there is only one prompt per action.

The test floor uses four folders: `Visuals`, `Collisions`, `InteractionAnchors`, and `Navigation`. Shelf and register metadata remain under semantic fixture Models inside `InteractionAnchors`; decorative mesh names do not control the gameplay bindings.

## Protection and reset

The bootstrap preserves a store marked `ImportedArt=true`. The current legacy blueprint refuses to replace it directly. Updater v53 skips test-mode rebuilds and refuses to Clear Map on imported art. This protection applies to the new source; an older installed plugin must be updated separately.

To intentionally rebuild a saved test scene, keep the prepared templates in ServerStorage and explicitly rename/move the old runtime `Workspace.RetailStore` before building again. No tool silently deletes that scene for you.

## Generate and validate the kit

```powershell
.\scripts\build-retail-assets.ps1              # native renders + exports + validation + ZIP
.\scripts\build-retail-assets.ps1 -SkipRender  # faster source/export iteration
.\scripts\test-retail.ps1                     # regression, import-contract and startup checks
```

The ZIP is `art/exports/retail-import-kit.zip`. Houdini shelf export excludes static merchandise so Roblox can control stock visibility. Blender export excludes review furniture/lights and baked sale-state text. Checkout metadata describes six authored anchors; runtime display targets and collision proxies are defined in `RetailAssetDefinitions.luau`.

Still requiring Studio verification: importer scale/orientation/materials, pivot calibration on actual imported Models, plugin operation, GUI readability, avatar collision and live multiplayer behavior. Native desktop app launches did not expose a usable window during this preparation, so those items remain unchecked.
