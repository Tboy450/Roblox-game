"""Round-trip the real GLB and check scale, anchors and export separation."""
import json
import math
from pathlib import Path
import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parents[2] / "art/exports"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(OUT / "checkout-01.glb"))
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
assert meshes, "GLB contains no meshes"
corners = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
# Apply the documented Blender-to-Roblox coordinate mapping.
positions = [(v.x, v.z, -v.y) for v in corners]
minimum = [min(p[axis] for p in positions) for axis in range(3)]
maximum = [max(p[axis] for p in positions) for axis in range(3)]
for actual, expected in zip(minimum + maximum, [-2.3, 0, -4.5, 5.55, 6.155, 4.5]):
    assert math.isclose(actual, expected, abs_tol=.025), f"Authored bounds drifted: {minimum}, {maximum}"
expected_anchors = json.loads((OUT / "checkout-01-manifest.json").read_text())["anchors"]
for name, position in expected_anchors.items():
    anchor = bpy.data.objects.get("Anchor_" + name)
    assert anchor is not None, f"Missing anchor: {name}"
    assert (anchor.matrix_world.translation - Vector(position)).length < .001, f"Moved anchor: {name}"
for obj in bpy.context.scene.objects:
    assert not obj.name.startswith(("Review_", "COLLISION_", "Monitor_State_PREVIEW_ONLY")), f"Preview content leaked into GLB: {obj.name}"
triangles = {}
for obj in meshes:
    obj.data.calc_loop_triangles()
    triangles[obj.name] = len(obj.data.loop_triangles)
    for vertex in obj.data.vertices:
        assert all(math.isfinite(component) for component in vertex.co), f"Invalid vertex in {obj.name}"
report = {"status": "pass", "boundsMinRoblox": minimum, "boundsMaxRoblox": maximum,
          "meshCount": len(meshes), "triangles": sum(triangles.values()),
          "largestMeshTriangles": max(triangles.values()), "anchorCount": len(expected_anchors),
          "scope": "Blender GLB round-trip, not Roblox importer/physics verification"}
(OUT / "checkout-validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
print("CHECKOUT_VALIDATED", json.dumps(report))
