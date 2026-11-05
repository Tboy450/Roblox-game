"""Native Houdini review render and game-oriented unstocked shelf export."""
import json
import sys
from pathlib import Path
import hou

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/exports"
hou.hipFile.load(str(OUT / "cornerfield-prototype.hipnc"), suppress_save_prompt=True)
root = hou.node("/obj/Cornerfield_Prototype")

# Keep stock separate: Roblox owns item counts and their visible representation.
source = root.node("Gondola_01/OUT_GONDOLA_01")
geo = hou.Geometry()
geo.merge(source.geometry())
stock_names = {"ProductTin", "TinLid", "ProductCarton", "PackageLabel"}
geo.deletePrims([p for p in geo.prims() if p.stringAttribValue("name") in stock_names], keep_points=False)

# OBJ/MTL uses native cooked positions, vertex normals and UVs. Split materials
# explicitly because importer support for Houdini's Cd attribute varies.
palette = {}
vertices, faces = [], []
for primitive in geo.prims():
    color = tuple(round(c, 4) for c in primitive.attribValue("Cd"))
    material = palette.setdefault(color, f"Material_{len(palette):02}")
    face = []
    for vertex in primitive.vertices():
        normal = vertex.attribValue("N") if geo.findVertexAttrib("N") else primitive.normal()
        uv = vertex.attribValue("uv")
        vertices.append((vertex.point().position(), normal, uv))
        face.append(len(vertices))
    faces.append((primitive.stringAttribValue("name"), material, face))
lines = ["# Houdini-authored prototype. Units: Roblox studs, Y up.", "mtllib gondola-01.mtl", "o Gondola_01"]
for position, normal, uv in vertices:
    lines.extend(["v %.7g %.7g %.7g" % tuple(position), "vt %.7g %.7g" % tuple(uv[:2]), "vn %.7g %.7g %.7g" % tuple(normal)])
for name, material, face in faces:
    lines.extend([f"g {name}", f"usemtl {material}", "f " + " ".join(f"{i}/{i}/{i}" for i in face)])
(OUT / "gondola-01.obj").write_text("\n".join(lines) + "\n", encoding="utf-8")
mtl = []
for color, name in palette.items():
    mtl.extend([f"newmtl {name}", "Kd %.4f %.4f %.4f" % color, "Ks 0.18 0.18 0.18", "Ns 45", ""])
(OUT / "gondola-01.mtl").write_text("\n".join(mtl), encoding="utf-8")
report = {"asset": "gondola_01", "units": "Studs", "axis": "Y up", "stockIncluded": False,
          "triangles": sum(len(p.vertices()) - 2 for p in geo.prims()),
          "boundsMin": list(geo.boundingBox().minvec()), "boundsMax": list(geo.boundingBox().maxvec())}
(OUT / "gondola-01-manifest.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
if "--skip-render" in sys.argv:
    print("Shelf export:", json.dumps(report), flush=True)
    sys.exit(0)

# Native material/rendering; the hidden reference and roof are explicitly excluded.
material = hou.node("/mat").createNode("principledshader::2.0", "Store_Review_Material")
material.parm("basecolor_usePointColor").set(True)
material.parmTuple("basecolor").set((1, 1, 1))
material.parm("rough").set(.5)
visible = []
for obj in root.children():
    if obj.type().name() == "geo" and obj.isDisplayFlagSet():
        obj.parm("shop_materialpath").set(material.path())
        visible.append(obj.path())

def point_at(obj, position, target):
    obj.parmTuple("t").set(position)
    direction = hou.Vector3(target) - hou.Vector3(position)
    obj.parmTuple("r").set(hou.Vector3((0, 0, -1)).matrixToRotateTo(direction).extractRotates())

for name, position, intensity, size in [
    ("Review_Key", (30, 75, 65), 9, 60),
    ("Review_Fill", (-55, 45, 25), 5, 45),
    ("Review_Back", (0, 50, -35), 7, 35),
]:
    light = hou.node("/obj").createNode("hlight::2.0", name)
    light.parm("light_type").set(2)  # area light
    light.parm("light_intensity").set(intensity)
    light.parm("light_exposure").set(7)
    light.parmTuple("areasize").set((size, size))
    point_at(light, position, (0, 0, 0))
camera = hou.node("/obj/Exterior_Review")
camera.parmTuple("res").set((1200, 800))
point_at(camera, (140, 115, 175), (0, 2, 0))
camera.parm("focal").set(42)
rop = hou.node("/out").createNode("ifd", "Store_Review")
rop.parm("camera").set(camera.path())
rop.parm("vobject").set("")
rop.parm("forceobject").set(" ".join(visible))
rop.parm("excludeobject").set(root.node("Reference_v55_HIDDEN").path() + " " + root.node("Removable_Roof_and_HVAC").path())
rop.parm("vm_samplesx").set(3)
rop.parm("vm_samplesy").set(3)
rop.parm("vm_picture").set(str(OUT / "houdini-store-review.png"))
hou.hipFile.save(str(OUT / "cornerfield-review.hipnc"), save_to_recent_files=False)
print("Shelf export:", json.dumps(report), flush=True)
rop.render()
point_at(camera, (-22, 17, 11), (-42, 4.5, -10))
camera.parm("focal").set(50)
rop.parm("vm_picture").set(str(OUT / "houdini-shelf-review.png"))
rop.render()
print("Native Houdini review render complete", flush=True)
