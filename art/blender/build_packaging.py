"""Build original fictional merchandise packaging for the standalone store.

Label artwork is drawn here from flat shapes and lettering in Blender's bundled
Noto Sans CJK font (Latin glyphs; SIL Open Font License 1.1, The Noto Project
Authors), rendered to PNG with Cycles, then wrapped onto a tin, a carton and a pump bottle authored in
metres with the base at the origin and the label facing -Y (glTF/Godot +Z).
Usage: blender --background --python art/blender/build_packaging.py
"""
import json
import math
import random
from pathlib import Path
import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/exports"
LABELS = OUT / "packaging-labels"
LABELS.mkdir(parents=True, exist_ok=True)
FONT_PATH = Path(bpy.utils.resource_path("LOCAL")) / "datafiles/fonts/Noto Sans CJK Regular.woff2"
# Static outlines: the variable Inter font's overlapping strokes fill with holes.
FONT = bpy.data.fonts.load(str(FONT_PATH))
TEXT_SCALE = 1.65  # this font's Latin glyphs sit small within its em
PX = 0.01  # label layout units per pixel
GREEN, CREAM, INK = "1f3d30", "f3e7c9", "1a1a17"


def linear(hex_color):
    srgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb)


_flat = {}


def flat(hex_color):
    if hex_color not in _flat:
        mat = bpy.data.materials.new("Flat_" + hex_color)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        nodes.clear()
        emit = nodes.new("ShaderNodeEmission")
        emit.inputs["Color"].default_value = (*linear(hex_color), 1)
        out = nodes.new("ShaderNodeOutputMaterial")
        mat.node_tree.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        _flat[hex_color] = mat
    return _flat[hex_color]


class Label:
    """Flat 2D artwork in pixel coordinates, rendered by an orthographic camera."""

    def __init__(self, name, width, height):
        self.width, self.height, self.layer = width, height, 0
        scene = self.scene = bpy.data.scenes.new(name + "_Label")
        scene.render.engine = "CYCLES"
        scene.cycles.device = "CPU"
        scene.cycles.samples = 24
        scene.cycles.use_denoising = False
        scene.render.resolution_x, scene.render.resolution_y = width, height
        scene.render.resolution_percentage = 100
        scene.view_settings.view_transform = "Standard"
        scene.view_settings.look = "None"
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGB"
        scene.world = bpy.data.worlds.new(name + "_World")
        camera = bpy.data.cameras.new(name + "_Camera")
        camera.type = "ORTHO"
        camera.ortho_scale = max(width, height) * PX
        obj = bpy.data.objects.new(name + "_Camera", camera)
        obj.location = (width * PX / 2, height * PX / 2, 10)
        scene.collection.objects.link(obj)
        scene.camera = obj

    def _add(self, obj, color):
        if not obj.data.materials:
            obj.data.materials.append(flat(color))
        self.layer += 1
        obj.location.z = self.layer * 0.001
        self.scene.collection.objects.link(obj)
        return obj

    def poly(self, points, color):
        mesh = bpy.data.meshes.new("poly")
        mesh.from_pydata([(x * PX, y * PX, 0) for x, y in points], [], [tuple(range(len(points)))])
        return self._add(bpy.data.objects.new("poly", mesh), color)

    def rect(self, x, y, w, h, color, angle=0.0):
        obj = self.poly([(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], color)
        obj.location.x, obj.location.y = x * PX, y * PX
        obj.rotation_euler.z = angle
        return obj

    def ellipse(self, x, y, rx, ry, color, angle=0.0):
        mesh = bpy.data.meshes.new("ellipse")
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=True, segments=64, radius=1.0)
        bm.to_mesh(mesh)
        bm.free()
        obj = self._add(bpy.data.objects.new("ellipse", mesh), color)
        obj.location.x, obj.location.y = x * PX, y * PX
        obj.scale = (rx * PX, ry * PX, 1)
        obj.rotation_euler.z = angle
        return obj

    def text(self, body, x, y, size, color, bold=0.0, spacing=1.0, max_width=None):
        curve = bpy.data.curves.new("text", "FONT")
        curve.body = body
        curve.font = FONT
        curve.size = size * TEXT_SCALE * PX
        curve.align_x = "CENTER"
        curve.align_y = "CENTER"
        curve.space_character = spacing
        scale = 1.0
        if max_width:
            probe = bpy.data.objects.new("probe", curve)
            self.scene.collection.objects.link(probe)
            depsgraph = self.scene.view_layers[0].depsgraph
            depsgraph.update()
            scale = min(1.0, max_width * PX / probe.evaluated_get(depsgraph).dimensions.x)
            bpy.data.objects.remove(probe)
        # Faux bold from overlapping copies; offsetting glyph outlines breaks their counters.
        offsets = [(0, 0)] + [(bold * math.cos(i * math.pi / 4), bold * math.sin(i * math.pi / 4)) for i in range(8) if bold]
        for dx, dy in offsets:
            obj = self._add(bpy.data.objects.new("text", curve), color)
            obj.location.x, obj.location.y = (x + dx) * PX, (y + dy) * PX
            obj.scale = (scale, scale, 1)
        return obj

    def barcode(self, x, y, w, h, digits):
        self.rect(x, y - 8, w + 24, h + 44, "fbfaf3")
        rng = random.Random(digits)
        cursor = x - w / 2
        while cursor < x + w / 2 - 6:
            bar = rng.choice([2, 2, 3, 4, 6])
            self.rect(cursor + bar / 2, y + 4, bar, h, INK)
            cursor += bar + rng.choice([2, 3, 4])
        self.text(digits, x, y - h / 2 - 14, 16, INK, spacing=1.2)

    def render(self, filename):
        path = LABELS / filename
        self.scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True, scene=self.scene.name)
        return path


def beans_label():
    # 360-degree tin wrap; u = 0.5 faces the aisle.
    art = Label("Beans", 1024, 384)
    art.rect(512, 192, 1024, 384, "b5562a")
    for y in (22, 362):
        art.rect(512, y, 1024, 22, GREEN)
    for y in (38, 346):
        art.rect(512, y, 1024, 4, "e9d9ae")
    art.ellipse(512, 192, 182, 146, CREAM)
    art.text("CORNERFIELD PANTRY", 512, 300, 21, GREEN, bold=0.5, spacing=1.25)
    art.text("HARVEST", 512, 258, 46, "7a2f12", bold=1.4, max_width=290)
    art.text("BEANS", 512, 198, 84, "7a2f12", bold=2.2, max_width=320)
    art.text("in rich tomato sauce", 512, 150, 23, "3d2a1c")
    for dx, dy, angle in [(-36, 2, .4), (0, 10, -.2), (36, 0, .7), (-17, -16, 1.1), (19, -18, -.6)]:
        art.ellipse(512 + dx, 106 + dy, 18, 11, "8a3a18", angle)
        art.ellipse(509 + dx, 109 + dy, 7, 3, "c87445", angle)
    art.text("NET WT 415 g", 512, 68, 19, GREEN, bold=0.3)
    for index, line in enumerate(["SERVING IDEA", "Warm gently and", "serve on toast."]):
        art.text(line, 250, 236 - index * 34, 22 if index == 0 else 20, CREAM, bold=0.5 if index == 0 else 0)
    for index, line in enumerate(["INGREDIENTS", "Beans, tomatoes,", "water, sugar,", "salt, spices."]):
        art.text(line, 774, 250 - index * 32, 22 if index == 0 else 20, CREAM, bold=0.5 if index == 0 else 0)
    art.barcode(930, 200, 110, 70, "0 41862 30415 7")
    art.text("RECYCLE STEEL", 96, 192, 18, CREAM, bold=0.4)
    return art.render("beans.png")


def oats_label():
    # Carton atlas: front 512 x 853 at left, side 384 x 853 beside it; the
    # golden corner patch colours the top and bottom.
    art = Label("Oats", 1024, 1024)
    art.rect(512, 512, 1024, 1024, "d8b35a")
    fx = 256
    art.rect(fx, 803, 512, 100, GREEN)
    art.text("CORNERFIELD PANTRY", fx, 803, 30, CREAM, bold=0.6, spacing=1.2)
    for index in range(16):
        angle = index * math.pi / 8
        art.rect(fx + math.cos(angle) * 128, 616 + math.sin(angle) * 128, 66, 14, "f2cf6e", angle)
    art.ellipse(fx, 616, 96, 96, "f6dd8c")
    art.text("MORNING", fx, 424, 66, "4a2a14", bold=1.6, max_width=440)
    art.text("OATS", fx, 330, 132, "4a2a14", bold=3.2, max_width=440)
    art.text("ROLLED WHOLE GRAIN", fx, 248, 27, GREEN, bold=0.6, spacing=1.15)
    for dx, angle in [(-66, .5), (0, -.2), (66, .3)]:
        art.ellipse(fx + dx, 166, 32, 19, CREAM, angle)
        art.ellipse(fx + dx, 166, 19, 6, "e2c98f", angle)
    art.rect(fx, 96, 512, 6, GREEN)
    art.text("NET WT 1 kg", fx, 56, 26, GREEN, bold=0.5)
    sx = 704
    art.rect(sx, 803, 384, 100, GREEN)
    art.text("MORNING OATS", sx, 803, 30, CREAM, bold=0.6)
    steps = ["HOW TO COOK", "Add 40 g oats to", "250 mL milk.", "Simmer 5 minutes,", "stirring often.", "Top with fruit."]
    for index, line in enumerate(steps):
        art.text(line, sx, 690 - index * 44 - (16 if index else 0), 30 if index == 0 else 26, "3b2614", bold=0.6 if index == 0 else 0.1)
    art.barcode(sx, 190, 220, 100, "0 41862 11000 3")
    return art.render("oats.png")


def soap_label():
    # Bottle wrap; outside the front panel it matches the bottle plastic.
    art = Label("Soap", 1024, 256)
    art.rect(512, 128, 1024, 256, "4f8786")
    art.rect(512, 128, 408, 236, "eef2ea")
    art.rect(512, 128, 392, 220, "2f5f5c")
    art.rect(512, 128, 384, 212, "eef2ea")
    tree_x = 392
    for width, base, top in [(86, 62, 128), (70, 104, 164), (50, 144, 196)]:
        art.poly([(tree_x - width / 2, base), (tree_x + width / 2, base), (tree_x, top)], "2f6b4f")
    art.rect(tree_x, 50, 14, 26, "6b4a2c")
    art.text("CEDAR", 566, 160, 66, "1f4a46", bold=1.8, max_width=250)
    art.text("HAND SOAP", 566, 100, 32, "1f4a46", bold=0.7, max_width=250)
    art.text("500 mL  ·  CORNERFIELD", 566, 56, 17, "3f6663", bold=0.2)
    art.barcode(888, 136, 104, 70, "0 41862 50500 1")
    art.text("Rinse well.", 140, 128, 22, "eef2ea")
    return art.render("soap.png")


def solid(name, hex_color, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*linear(hex_color), 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*linear(hex_color), 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def textured(name, image_path, roughness):
    mat = solid(name, "ffffff", roughness)
    tree = mat.node_tree
    texture = tree.nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(image_path))
    tree.links.new(texture.outputs["Color"], tree.nodes["Principled BSDF"].inputs["Base Color"])
    return mat


def finish(bm, name, materials, collection):
    bm.normal_update()
    for face in bm.faces:
        face.smooth = True
    for edge in bm.edges:
        if len(edge.link_faces) == 2 and edge.calc_face_angle(0) > math.radians(35):
            edge.smooth = False
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def lathe(name, profile, bands, label_z, materials, collection, label_index=1, segments=48):
    """Revolve (radius, z) points traced bottom centre -> outside -> top centre.

    bands[i] is the material index between points i and i+1; faces using
    label_index wrap the label image once around, spanning label_z vertically.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rings = []
    for radius, z in profile:
        if radius == 0:
            rings.append([bm.verts.new((0, 0, z))] * segments)
            continue
        ring = []
        for step in range(segments):
            phi = 2 * math.pi * step / segments - math.pi
            ring.append(bm.verts.new((radius * math.sin(phi), -radius * math.cos(phi), z)))
        rings.append(ring)
    z0, z1 = label_z
    for band, mat in enumerate(bands):
        lower, upper = profile[band][1], profile[band + 1][1]
        labelled = mat == label_index
        for step in range(segments):
            nxt = (step + 1) % segments
            corners = [(rings[band][step], step, lower), (rings[band][nxt], step + 1, lower),
                       (rings[band + 1][nxt], step + 1, upper), (rings[band + 1][step], step, upper)]
            unique = []
            for corner in corners:
                if not any(corner[0] is seen[0] for seen in unique):
                    unique.append(corner)
            face = bm.faces.new([corner[0] for corner in unique])
            face.material_index = mat
            for loop, (_, u, z) in zip(face.loops, unique):
                loop[uv].uv = (u / segments, (z - z0) / (z1 - z0)) if labelled else (0.0, 0.0)
    return finish(bm, name, materials, collection)


def box(bm, uv, centre, size, mat=0):
    created = bmesh.ops.create_cube(bm, size=1.0)
    for vert in created["verts"]:
        vert.co = (centre[0] + vert.co.x * size[0], centre[1] + vert.co.y * size[1], centre[2] + vert.co.z * size[2])
    faces = {face for vert in created["verts"] for face in vert.link_faces}
    for face in faces:
        face.material_index = mat
        for loop in face.loops:
            loop[uv].uv = (0.0, 0.0)


def carton(name, size, material, collection):
    w, d, h = size
    x0, x1, y0, y1 = -w / 2, w / 2, -d / 2, d / 2
    top = 853 / 1024
    front_uv = [(0, 0), (.5, 0), (.5, top), (0, top)]
    side_uv = [(.5, 0), (.875, 0), (.875, top), (.5, top)]
    patch = [(.94, .94)] * 4
    faces = [([(x0, y0, 0), (x1, y0, 0), (x1, y0, h), (x0, y0, h)], front_uv),
             ([(x1, y1, 0), (x0, y1, 0), (x0, y1, h), (x1, y1, h)], front_uv),
             ([(x0, y1, 0), (x0, y0, 0), (x0, y0, h), (x0, y1, h)], side_uv),
             ([(x1, y0, 0), (x1, y1, 0), (x1, y1, h), (x1, y0, h)], side_uv),
             ([(x0, y0, h), (x1, y0, h), (x1, y1, h), (x0, y1, h)], patch),
             ([(x0, y1, 0), (x1, y1, 0), (x1, y0, 0), (x0, y0, 0)], patch)]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    for corners, coords in faces:
        face = bm.faces.new([bm.verts.new(corner) for corner in corners])
        for loop, coord in zip(face.loops, coords):
            loop[uv].uv = coord
    obj = finish(bm, name, [material], collection)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def export(product, objects):
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in objects)
    path = OUT / f"merch-{product}.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_image_format="AUTO", export_extras=True, use_active_scene=True)
    triangles = sum(sum(len(p.vertices) - 2 for p in obj.data.polygons) for obj in objects)
    return {"file": path.name, "triangles": triangles}


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
images = {"beans": beans_label(), "oats": oats_label(), "soap": soap_label()}
scene = bpy.context.scene
assets = []

# Moderate metallic: the GL Compatibility scene has no reflections, so a full metal reads black.
tin = solid("Tinplate", "c9ccc4", .34, .45)
beans = bpy.data.collections.new("Merch_Beans")
scene.collection.children.link(beans)
can = lathe("Beans_Tin", [(0, .006), (.094, .006), (.100, .001), (.106, 0), (.110, .006), (.108, .016), (.108, .030),
                          (.1085, .030), (.1085, .310), (.108, .310), (.108, .324), (.110, .334), (.106, .340),
                          (.100, .339), (.096, .333), (0, .333)],
            [0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], (.030, .310),
            [tin, textured("Beans_Label", images["beans"], .55)], beans)
assets.append(export("beans", [can]))

oats = bpy.data.collections.new("Merch_Oats")
scene.collection.children.link(oats)
box_obj = carton("Oats_Carton", (.24, .18, .40), textured("Oats_Print", images["oats"], .72), oats)
assets.append(export("oats", [box_obj]))

soap = bpy.data.collections.new("Merch_Soap")
scene.collection.children.link(soap)
pump = solid("Pump_Plastic", "1f3d30", .38)
# Plastic matches the label's wrap colour and finish so the printed band blends in.
plastic = solid("Soap_Bottle_Plastic", "4f8786", .33)
bottle = lathe("Soap_Bottle", [(0, .004), (.080, .004), (.088, 0), (.094, .006), (.096, .024), (.096, .045),
                               (.096, .190), (.096, .206), (.088, .232), (.062, .258), (.034, .270), (.028, .276),
                               (.028, .290), (.036, .290), (.036, .312), (.012, .314), (.012, .336), (.030, .336),
                               (.032, .346), (.030, .358), (0, .360)],
               [1] * 5 + [2] + [1] * 6 + [0] * 8, (.045, .190),
               [pump, plastic, textured("Soap_Label", images["soap"], .33)], soap, label_index=2)
nozzle_mesh = bpy.data.meshes.new("Soap_Nozzle")
bm = bmesh.new()
box(bm, bm.loops.layers.uv.new("UVMap"), (0, -.042, .350), (.018, .060, .014))
nozzle = finish(bm, "Soap_Nozzle", [pump], soap)
assets.append(export("soap", [bottle, nozzle]))

(OUT / "merchandise-manifest.json").write_text(json.dumps({
    "tool": "Blender " + bpy.app.version_string, "source": "art/blender/build_packaging.py",
    "units": "metres", "origin": "base centre", "label_facing": "-Y in Blender, +Z in glTF/Godot",
    "lettering": "Noto Sans CJK Regular, Latin glyphs (SIL Open Font License 1.1, The Noto Project Authors), bundled with Blender; rendered into label images",
    "labels": {key: path.name for key, path in images.items()}, "assets": assets}, indent=2), encoding="utf-8")
print("PACKAGING_READY", json.dumps(assets))
