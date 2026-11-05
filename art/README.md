# Background art pipeline

Use **Houdini** for procedural architecture and shelving, **Blender** for detailed checkout and merchandise modeling, cleanup, UVs and baking, and **Godot** for the standalone game. Generate assets/review frames through scripts. No built-in image-generation service or editor automation is used.

```powershell
.\scripts\prepare-game-assets.ps1   # Houdini/Blender → portable fixture and merchandise GLBs
.\scripts\test-game.ps1             # real headless imports and gameplay checks
.\scripts\render-game-preview.ps1   # GPU frame captured by code
```

DCC paths default to installed Houdini 22.0.466 `hython.exe` and portable `.tools/blender-4.5.15-windows-x64/blender.exe`; override `-Hython`/`-Blender` as needed. The Houdini source environment is Apprentice. Native files and manifests retain provenance.

## Runtime assets

| Asset in `game/assets/generated/` | Content |
| --- | --- |
| `store-shell.glb` | Cooked Houdini shell variant: 80 × 64 source units, masonry, glazing, canopy and tile joints |
| `shelf.glb` | Houdini uprights, slots, decks, brackets, rails and labels; static merchandise excluded |
| `checkout.glb` | Blender casework, conveyor/rollers, scanner, till, monitor, terminal, printer, bagging return and lettering |
| `merch-beans.glb`, `merch-oats.glb`, `merch-soap.glb`, `merch-honey.glb` | Blender packaging with embedded printed labels; metres, base centred at the origin |
| `manifest.json` | Source files/tools, scale and SHA-256 hashes |

These compact runtime files are versioned so fresh clones do not require DCC tools. Larger native/intermediate outputs live in ignored `art/exports/`. The full Houdini starter, roof/HVAC and hidden reference remain there; compact shell export does not overwrite the native HIP.

## Merchandise packaging

`art/blender/build_packaging.py` draws each label from flat shapes and lettering, renders it to PNG with Cycles (`art/exports/packaging-labels/`), then wraps it onto a lathed tin, a box-mapped carton, a lathed pump bottle or a lathed honey jar and exports one GLB per product. Label PNGs are re-saved without Cycles' render-time metadata, so rebuilding produces byte-identical GLBs. Brands, copy and barcodes are fictional. Lettering uses the Latin glyphs of **Noto Sans CJK Regular** bundled with Blender (SIL Open Font License 1.1, The Noto Project Authors); Blender's bundled variable Inter font was tried first but its overlapping strokes fill with holes. `prepare-game-assets.ps1` runs the generator only when a `merch-*.glb` export is missing, so run it directly after editing labels or models. Godot extracts the embedded labels to ignored `merch-*_*.png` files on import and generates mipmaps.

## Coordinates and ownership

Houdini uses Y up. Blender uses Z up; glTF export converts to Y up. One fixture source unit becomes **0.28 metres** in Godot; merchandise is authored directly in metres. OBJ conversion explicitly selects Y-up axes. Runtime instances share mesh resources; Godot instances one merchandise GLB per stocked unit.

Godot owns collision proxies, lights, inventory, actions and dynamic UI. Material colors passed actual engine import checks. Current materials are prototype shaders, not final baked PBR maps. Textures, LODs, wear, animated shoppers and complete room assets remain checklist work.

`art/previews/godot-*.png` files are actual scripted engine frames. Other previews are native DCC renders. The [earlier Roblox pipeline](../docs/ROBLOX_ART_PIPELINE.md) is preserved as history.
