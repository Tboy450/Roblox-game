"""Export cooked shell geometry for the standalone engine, without a GUI."""
from pathlib import Path
import hou

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/exports"
hou.hipFile.load(str(OUT / "cornerfield-prototype.hipnc"), suppress_save_prompt=True)
shell = hou.node("/obj/Cornerfield_Prototype/Procedural_Store_Shell")
# Compact first playable store; native source HIP remains unchanged on disk.
source = shell.node("PARAMETRIC_SOURCE")
source.parm("width").set(80)
source.parm("depth").set(64)
geo = shell.displayNode().geometry()
if shell.displayNode().errors():
    raise RuntimeError(shell.displayNode().errors())
palette, vertices, faces = {}, [], []
for primitive in geo.prims():
    color = tuple(round(c, 4) for c in primitive.attribValue("Cd"))
    material = palette.setdefault(color, f"Shell_{len(palette):02}")
    face = []
    for vertex in primitive.vertices():
        normal = vertex.attribValue("N") if geo.findVertexAttrib("N") else primitive.normal()
        vertices.append((vertex.point().position(), normal, vertex.attribValue("uv")))
        face.append(len(vertices))
    faces.append((primitive.stringAttribValue("name"), material, face))
lines = ["# Houdini cooked shell. Y up; source units, scale 0.28 in Godot.", "mtllib store-shell.mtl", "o StoreShell"]
for position, normal, uv in vertices:
    lines.extend(["v %.7g %.7g %.7g" % tuple(position), "vt %.7g %.7g" % tuple(uv[:2]), "vn %.7g %.7g %.7g" % tuple(normal)])
for name, material, face in faces:
    lines.extend([f"g {name}", f"usemtl {material}", "f " + " ".join(f"{i}/{i}/{i}" for i in face)])
(OUT / "store-shell.obj").write_text("\n".join(lines) + "\n", encoding="utf-8")
mtl = []
for color, name in palette.items():
    mtl.extend([f"newmtl {name}", "Kd %.4f %.4f %.4f" % color, "Ks 0.08 0.08 0.08", "Ns 25", ""])
(OUT / "store-shell.mtl").write_text("\n".join(mtl), encoding="utf-8")
print("GODOT_SHELL_EXPORTED", len(faces), "faces")
