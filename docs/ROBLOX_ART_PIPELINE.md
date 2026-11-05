# Retail art pipeline

Use both applications where they are strongest: Houdini for procedural buildings and fixtures; Blender for detailed props, cleanup, UVs and baking. Studio owns collision, lighting and runtime integration. This initial prototype uses installed Houdini Apprentice; keep its provenance with derived assets.

## Rebuild

The complete, checked pipeline is now `scripts/build-retail-assets.ps1`; use `-SkipRender` for faster export iteration. It generates both DCC assets, native Houdini review images, checks the real checkout GLB, and packages `art/exports/retail-import-kit.zip`. See [the fixture test instructions](../docs/ASSET_IMPORT_TEST.md).

```powershell
.\scripts\export-retail-reference.ps1
& 'C:\Program Files\Side Effects Software\Houdini 22.0.466\bin\hython.exe' art/houdini/build_store.py
& 'C:\path\to\blender.exe' --background --python art/blender/build_store.py -- --render
```

Portable Blender in this workspace, if downloaded:

```powershell
& '.\.tools\blender-4.5.15-windows-x64\blender.exe' --background --python art/blender/build_store.py -- --render
```

Run in a fresh/background Blender process: the script clears that process's scene. Omit `--render` for faster generation. Output goes to `art/exports/` and is ignored by Git. Source scripts and `reference/current-store-v55.json` remain versioned.

## Generated starter assets

| Output in `art/exports/` | Contents |
| --- | --- |
| `cornerfield-prototype.hipnc` | Native Houdini procedural shell, nine shelves, removable roof/HVAC, sign and hidden v55 reference |
| `houdini-report.json` | Cooked geometry counts and source environment |
| `checkout-01.blend` | Original Blender checkout with separate named components and review lighting |
| `checkout-01.glb` | Checkout visual meshes and anchor empties; no uploaded Roblox asset IDs |
| `checkout-01-manifest.json` | Asset version, units, six interaction targets and a simple collision-box specification |
| `checkout-review.png` | Inspected Blender prop render |

The Houdini source uses Y-up coordinates directly matching the extracted Roblox reference. Open a geometry object's `PARAMETRIC_SOURCE` node to adjust dimensions/tier count. `EDGE_BEVEL` and `SURFACE_NORMALS` remain editable. Roof visibility is off for interior inspection; the old reference is also hidden. The reference's non-box shapes are box proxies, not a lossless conversion. Native renders have been inspected; interactive viewport review and complete room/exterior integration are still pending.

The Blender script independently authors the checkout and does not import Houdini output. The first pass includes casework, bevels, belt/rollers, scanner, till, monitor, card terminal, receipt printer, bagging return, labels and screws. Final modeling, UV layout, texture baking, LODs, collisions and Studio integration remain checklist work. Preview shaders do not become Roblox PBR maps automatically.

## Scale and structure

Reference units are studs. Houdini keeps `(X, Y, Z)` with Y up. Blender props use Z up; convert Roblox reference coordinates with `(X, -Z, Y)` if assembling them in Blender. One DCC unit represents one source stud. Calibrate the Studio importer with a known fixture and an avatar; do not assume its default scale. Preserve unique names and deliberate pivots. Separate glass, repeating fixtures, structural meshes and collision proxies.

The checkout GLB is an import candidate. Review lights, camera, floor, collision proxy and live sale-state text are excluded. Fixed brand lettering remains. The accompanying manifest supplies anchor positions if importer handling of empty nodes differs. Runtime display targets and collision proxies live in `RetailAssetDefinitions.luau`. The unstocked Houdini shelf exports to `gondola-01.obj` plus MTL at 10,368 triangles; merchandise remains under runtime inventory control. Actual Roblox import testing is pending.

## Import gate

1. Import one shelf and checkout in a separate Studio place using the 3D Importer.
2. Verify axes, units, normals, material colors, textures, pivots and collision.
3. Add simple collision proxies and explicit interaction anchors; disable decorative collision.
4. Prove stocking and checkout before importing the whole kit.
5. Record asset IDs/source names and provenance in a manifest.
6. Add an opt-in loader/updater mode that preserves imported art.
7. Validate routes, light levels, multiplayer and device performance before switching defaults.

The default bootstrap still creates the legacy game. It now preserves a root marked `ImportedArt=true`, and the legacy blueprint refuses to replace that root. Updater v53 adds corresponding update/clear guards. Use `asset-test.project.json` and the current plugins for supported fixture tests; older installed plugins must be updated separately.

References: [Roblox modeling](https://create.roblox.com/docs/art/modeling), [Importer](https://create.roblox.com/docs/studio/importer), [Reimport](https://create.roblox.com/docs/art/modeling/reimport).
