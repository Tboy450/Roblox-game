"""Convert authored exports into portable GLBs for background Godot imports."""
import hashlib
import json
import shutil
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art/exports"
DEST = ROOT / "game/assets/generated"
DEST.mkdir(parents=True, exist_ok=True)
assets = []
for source, target, tool in [("gondola-01.obj", "shelf.glb", "Houdini"), ("store-shell.obj", "store-shell.glb", "Houdini")]:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.wm.obj_import(filepath=str(SOURCE/source), forward_axis="NEGATIVE_Z", up_axis="Y")
    objects = list(bpy.context.selected_objects)
    assert objects and all(o.type == "MESH" for o in objects), source
    for obj in objects:
        obj["sourceTool"] = tool
        obj["sourceFile"] = source
    bpy.ops.export_scene.gltf(filepath=str(DEST/target), use_selection=True, export_apply=True, export_extras=True)
    assets.append({"file": target, "source": source, "tool": tool})
shutil.copyfile(SOURCE/"checkout-01.glb", DEST/"checkout.glb")
assets.append({"file": "checkout.glb", "source": "art/blender/build_store.py", "tool": "Blender"})
# Merchandise is authored in metres and instanced per stocked unit by Godot.
for product in ("beans", "oats", "soap", "honey"):
    target = f"merch-{product}.glb"
    shutil.copyfile(SOURCE/target, DEST/target)
    assets.append({"file": target, "source": "art/blender/build_packaging.py", "tool": "Blender", "units": "metres"})
for asset in assets:
    asset["sha256"] = hashlib.sha256((DEST/asset["file"]).read_bytes()).hexdigest()
(DEST/"manifest.json").write_text(json.dumps({"version": 1, "source_to_metres": .28, "axis": "Y up",
    "assets": assets, "note": "source_to_metres applies to fixtures; merchandise is authored in metres. Fixture textures, LODs and final art remain work in progress."}, indent=2), encoding="utf-8")
print("GODOT_ASSETS_READY", len(assets))
