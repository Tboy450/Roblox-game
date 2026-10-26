"""Build an original detailed checkout asset and review render in fresh Blender.

This prop is authored directly in Blender; it does not import Houdini output.
Usage: blender --background --python art/blender/build_store.py -- --render
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"art/exports"
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene=bpy.context.scene
scene.unit_settings.system="NONE"
asset=bpy.data.collections.new("Checkout_01_Visuals")
scene.collection.children.link(asset)
studio=bpy.data.collections.new("Review_Studio")
scene.collection.children.link(studio)
collisions=bpy.data.collections.new("Checkout_01_Collisions")
scene.collection.children.link(collisions)


def material(name,color,metallic=0,roughness=.45):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value=(*color,1)
    bsdf.inputs["Metallic"].default_value=metallic
    bsdf.inputs["Roughness"].default_value=roughness
    return mat


paint=material("Powdercoat_Cornerfield_Green",(.10,.23,.17),.25,.38)
metal=material("Brushed_Stainless",(.52,.56,.57),.9,.29)
dark=material("Charcoal_ABS",(.035,.045,.047),.05,.4)
rubber=material("Conveyor_Rubber",(.045,.05,.046),0,.82)
cream=material("Warm_Countertop",(.72,.72,.64),.08,.32)
paper=material("Receipt_and_Labels",(.92,.90,.79),0,.75)
screen=material("Screen_Glass",(.045,.11,.12),.25,.19)
led=material("Display_Lettering",(.48,.9,.72),0,.35)
bsdf=led.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Emission Color"].default_value=(.25,.65,.45,1)
bsdf.inputs["Emission Strength"].default_value=.6
red=material("Scanner_Window",(.26,.025,.018),.3,.2)
ground=material("Review_Floor",(.15,.18,.18),0,.8)


def move_to(obj,collection):
    for old in list(obj.users_collection): old.objects.unlink(obj)
    collection.objects.link(obj)


def finish(obj,name,mat,collection=asset,bevel=.05):
    obj.name=name
    move_to(obj,collection)
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        modifier=obj.modifiers.new("Manufactured_Edge_Radius","BEVEL")
        modifier.width=bevel
        modifier.segments=3
        modifier.affect="EDGES"
        modifier=obj.modifiers.new("Weighted_Surface_Normals","WEIGHTED_NORMAL")
        modifier.keep_sharp=True
    obj["sourceTool"]="Blender"
    obj["assetFamily"]="Checkout_01"
    return obj


def box(name,position,size,mat,bevel=.05,collection=asset):
    bpy.ops.mesh.primitive_cube_add(size=1,location=position)
    obj=bpy.context.object
    obj.dimensions=size
    return finish(obj,name,mat,collection,bevel)


def cylinder(name,position,radius,depth,mat,axis="Z"):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24,radius=radius,depth=depth,location=position)
    obj=bpy.context.object
    obj.rotation_euler={"X":(0,math.pi/2,0),"Y":(math.pi/2,0,0),"Z":(0,0,0)}[axis]
    for face in obj.data.polygons: face.use_smooth=len(face.vertices)==4
    return finish(obj,name,mat,bevel=.018)


def lettering(name,text,position,size,mat,rotation=(math.pi/2,0,0)):
    curve=bpy.data.curves.new(name,"FONT")
    curve.body=text; curve.size=size; curve.extrude=.002
    curve.align_x="CENTER"; curve.align_y="CENTER"
    obj=bpy.data.objects.new(name,curve)
    asset.objects.link(obj); obj.location=position; obj.rotation_euler=rotation
    obj.data.materials.append(mat)
    return obj


# Casework with separate panels, real recessed plinth and raised countertop.
box("Recessed_Plinth",(0,0,.25),(3.8,8.2,.5),dark)
box("Checkout_Cabinet",(0,0,1.9),(4.2,8.6,2.9),paint,.10)
box("Stainless_Top",(0,0,3.43),(4.6,9,.22),metal,.08)
box("Conveyor_Bed",(0,-1.65,3.59),(3.65,4.7,.14),dark,.12)
box("Moving_Belt_Visual",(0,-1.65,3.68),(3.35,4.4,.09),rubber,.07)
for y in (-3.82,.52): cylinder("Belt_End_Roller",(0,y,3.65),.16,3.45,metal,"X")
for x in (-1.88,1.88):
    box("Conveyor_Guide",(x,-1.65,3.76),(.16,4.95,.27),metal,.06)
for y in (-3.4,-2.65,-1.9,-1.15,-.4):
    box("Belt_Seam",(0,y,3.73),(3.23,.018,.009),dark,.001)
box("Divider_Bar",(.30,-2.55,3.86),(2.45,.23,.20),paint,.05)

# Flush scanner glass, rim, side scanner, scale and operator work surface.
box("Scanner_Recess",(0,1.45,3.59),(2.55,1.8,.12),dark,.06)
box("Scanner_Glass",(0,1.45,3.66),(2.15,1.45,.035),red,.04)
for x in (-.78,-.39,0,.39,.78):
    box("Scanner_Optics_Line",(x,1.45,3.683),(.012,1.2,.006),metal,.001)
box("Scale_Plate",(0,3.10,3.62),(3.6,1.2,.13),cream,.045)
box("Upright_Scanner",(-1.58,1.62,4.23),(.45,1.0,1.25),dark,.11)
box("Upright_Scanner_Window",(-1.337,1.62,4.23),(.025,.68,.78),red,.04)

# Independent bagging return with stainless supports and usable open space.
box("Bagging_Return",(3.95,2.2,3.23),(3.2,4.2,.28),cream,.10)
for x in (2.7,5.2):
    for y in (.75,3.65):
        cylinder("Bagging_Leg",(x,y,1.62),.095,3.05,metal)
        cylinder("Adjustable_Foot",(x,y,.14),.16,.13,dark)
box("Bagging_Lower_Shelf",(3.95,2.2,.65),(2.8,3.7,.13),metal)
for x in (3.2,4.6):
    cylinder("Bag_Holder_Post",(x,3.5,3.8),.055,1.0,metal)
    cylinder("Bag_Holder_Arm",(x,3.13,4.25),.055,.75,metal,"Y")
box("Bag_Stack",(3.9,3.46,3.84),(1.15,.08,.70),paper,.015)

# Drawer, till key, service panel, vents, monitor, terminal and receipt printer.
box("Till_Housing",(-.8,2.6,3.94),(1.65,1.25,.52),dark,.06)
box("Cash_Drawer_Front",(-.8,1.95,3.94),(1.49,.06,.35),metal,.035)
cylinder("Till_Lock",(-.8,1.907,3.94),.075,.025,dark,"Y")
box("Monitor_Base",(-.8,2.75,4.25),(1.3,.9,.1),dark)
cylinder("Monitor_Stem",(-.8,2.82,4.77),.12,1.0,metal)
box("Monitor_Frame",(-.8,2.80,5.43),(2.20,.20,1.45),dark,.09)
box("Monitor_Display",(-.8,2.687,5.43),(1.98,.02,1.22),screen,.035)
lettering("Monitor_Brand","CORNERFIELD",(-.8,2.67,5.68),.16,led)
lettering("Monitor_State","READY  $0.00",(-.8,2.67,5.26),.17,paper)
cylinder("Terminal_Mount",(1.6,1.85,4.0),.075,.65,metal)
terminal=box("Card_Terminal",(1.6,1.85,4.35),(.68,.98,.20),dark,.075)
terminal.rotation_euler.x=math.radians(18)
box("Terminal_Screen",(1.6,2.03,4.49),(.48,.35,.025),screen,.025)
for row in range(3):
    for col in range(3):
        box("Terminal_Key",(1.43+col*.17,1.85-row*.15,4.48),(.10,.08,.025),paper,.014)
box("Receipt_Printer",(1.1,3.55,4.0),(.88,.95,.65),dark,.08)
box("Printer_Slot",(1.1,3.05,4.10),(.62,.025,.08),metal,.01)
box("Receipt_Paper",(1.1,2.92,4.11),(.48,.3,.012),paper,.006)
for i in range(5): box("Receipt_Print",(1.1,2.82+i*.04,4.12),(.32,.012,.003),dark,.001)
box("Access_Panel",(-2.11,1.7,1.9),(.035,2.5,1.85),dark,.045)
for i in range(9): box("Cabinet_Vent",(-2.14,1.7,1.2+i*.14),(.025,1.8,.045),metal,.01)
for x in (-1.7,1.7):
    for z in (.7,2.9):
        cylinder("Front_Panel_Screw",(x,-4.32,z),.045,.025,metal,"Y")
lettering("Front_Brand","CORNERFIELD",(0,-4.315,2.15),.29,paper)
lettering("Front_Label","CHECKOUT 01",(0,-4.32,1.65),.16,paper)

# Integration metadata is explicit; meshes alone do not implement gameplay.
anchors={"Scan":(0,1.45,3.7),"CashDrawer":(-.8,1.9,3.94),"Payment":(1.6,1.85,4.48),
         "Cashier":(-3.5,2,0),"Customer":(3.2,-1,0),"Queue":(3.2,-6,0)}
for name,position in anchors.items():
    obj=bpy.data.objects.new("Anchor_"+name,None)
    asset.objects.link(obj); obj.location=position
    obj["interactionId"]="checkout_01_"+name.lower()
collision=box("COLLISION_Cabinet",(0,0,1.75),(4.2,8.6,3.5),dark,0,collisions)
collision.hide_render=True
collision.display_type="WIRE"

# Export before adding studio lighting/background. GLB does not create Roblox asset IDs.
bpy.ops.object.select_all(action="DESELECT")
for obj in asset.objects:
    obj.select_set(True)
    if obj.type=="FONT":
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target="MESH")
bpy.ops.export_scene.gltf(filepath=str(OUT/"checkout-01.glb"),use_selection=True,export_extras=True,export_apply=True)
(OUT/"checkout-01-manifest.json").write_text(json.dumps({
    "asset":"checkout_01","version":1,"source":"art/blender/build_store.py",
    "units":"one Blender unit per Roblox stud; Blender Z up",
    "status":"prototype, not Studio integrated", "anchors":anchors,
    "collisionBoxes":[{"center":[0,0,1.75],"size":[4.2,8.6,3.5]}],
    "needs":["import scale calibration","Roblox asset IDs","runtime anchor bindings","LOD/UV/bake review"]
},indent=2),encoding="utf-8")

box("Review_Platform",(1,0,-.20),(25,25,.3),ground,.08,studio)
camera_data=bpy.data.cameras.new("Review_Camera")
camera=bpy.data.objects.new("Review_Camera",camera_data)
studio.objects.link(camera)
camera.location=(15,-18,14)
camera.rotation_euler=(Vector((1,0,2.1))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.type="ORTHO"; camera_data.ortho_scale=17.5
scene.camera=camera
for name,position,power,size in [("Key",(0,-7,15),2300,10),("Fill",(-8,0,9),1700,8),("Rim",(7,8,12),2600,7)]:
    data=bpy.data.lights.new(name,"AREA"); data.energy=power; data.shape="DISK"; data.size=size
    light=bpy.data.objects.new(name,data); studio.objects.link(light); light.location=position
    light.rotation_euler=(Vector((0,0,2))-light.location).to_track_quat("-Z","Y").to_euler()
scene.world.color=(.18,.18,.18)
scene.render.engine="CYCLES"
scene.cycles.samples=40
scene.cycles.use_denoising=True
scene.render.resolution_x=1200; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format="PNG"
scene.render.filepath=str(OUT/"checkout-review.png")
scene.view_settings.view_transform="AgX"
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/"checkout-01.blend"))
if "--render" in sys.argv: bpy.ops.render.render(write_still=True)
print("CHECKOUT_READY",len(asset.objects),"visual/anchor objects",OUT)
