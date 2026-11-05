"""Run with hython in a fresh process; builds an editable Apprentice prototype."""
import json
from pathlib import Path
import hou

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"art/exports"
OUT.mkdir(parents=True,exist_ok=True)
hou.hipFile.clear(suppress_save_prompt=True)
scene=hou.node("/obj").createNode("subnet","Cornerfield_Prototype")
scene.setComment("Noncommercial first pass. Houdini procedural shell/shelves; Blender detailed props. One unit = one Roblox stud. Baseline reference is hidden.")
scene.setGenericFlag(hou.nodeFlag.DisplayComment,True)


def model(name,kind,width,height,depth,tiers=4):
    obj=scene.createNode("geo",name)
    for child in obj.children(): child.destroy()
    source=obj.createNode("python","PARAMETRIC_SOURCE")
    templates=source.parmTemplateGroup()
    for parm in [hou.StringParmTemplate("kind","Generator",1,default_value=(kind,)),
                 hou.FloatParmTemplate("width","Width (studs)",1,default_value=(width,),min=2),
                 hou.FloatParmTemplate("height","Height (studs)",1,default_value=(height,),min=2),
                 hou.FloatParmTemplate("depth","Depth (studs)",1,default_value=(depth,),min=.5),
                 hou.IntParmTemplate("tiers","Shelf tiers",1,default_value=(tiers,),min=2,max=6),
                 hou.StringParmTemplate("reference_file","Reference JSON",1,default_value=("$HIP/../reference/current-store-v55.json",))]:
        templates.append(parm)
    source.setParmTemplateGroup(templates)
    source.parm("python").set('import sys, hou\np=hou.expandString("$HIP/../houdini")\nif p not in sys.path: sys.path.insert(0,p)\nimport store_geometry\nstore_geometry.cook(hou.pwd())')
    # Non-destructive bevel after the procedural source; kept editable in the network.
    bevel=obj.createNode("polybevel::3.0","EDGE_BEVEL")
    bevel.setInput(0,source)
    for parm in bevel.parms():
        if parm.name()=="divisions": parm.set(2)
        if parm.name() in ("offset","distance"): parm.set(.035)
    normal=obj.createNode("normal","SURFACE_NORMALS")
    normal.setInput(0,bevel)
    output=obj.createNode("null","OUT_"+name.upper())
    output.setInput(0,normal)
    output.setDisplayFlag(True); output.setRenderFlag(True)
    obj.layoutChildren()
    return obj,source,output


# Set the future HIP directory before cooking relative reference paths.
hou.hipFile.setName(str(OUT/"cornerfield-prototype.hipnc"))
reference,_,_=model("Reference_v55_HIDDEN","reference",152,14,100)
reference.setDisplayFlag(False)
shell,shell_source,_=model("Procedural_Store_Shell","shell",152,14,100)
roof,roof_source,_=model("Removable_Roof_and_HVAC","roof",152,14,100)
for dimension in ("width","height","depth"):
    roof_source.parm(dimension).setExpression(f'ch("../../Procedural_Store_Shell/PARAMETRIC_SOURCE/{dimension}")')
roof.setDisplayFlag(False)
for index,(x,z) in enumerate([(x,z) for z in (-10,10,28) for x in (-42,0,42)],1):
    shelf,source,_=model(f"Gondola_{index:02}","shelf",12,8.5,3.8)
    shelf.parmTuple("t").set((x,1,z))
    source.setComment("Editable width, height, depth and tier count. Primitive name/Cd plus starter face UVs. Final atlas UVs and collision proxies remain open tasks.")
font=scene.createNode("geo","Store_Sign")
for child in font.children(): child.destroy()
text=font.createNode("font","Cornerfield_Lettering")
text.parm("text").set("CORNERFIELD MARKET")
text.parm("fontsize").set(2.5)
font.parmTuple("t").set((-23,14.2,50.8))
text.setDisplayFlag(True); text.setRenderFlag(True)
scene.layoutChildren()
camera=hou.node("/obj").createNode("cam","Exterior_Review")
camera.parmTuple("t").set((170,115,205))
look=hou.Vector3((0,4,12))-hou.Vector3((170,115,205))
rotation=hou.Vector3((0,0,-1)).matrixToRotateTo(look).extractRotates()
camera.parmTuple("r").set(rotation)
camera.parm("focal").set(42)
stats={"license":str(hou.licenseCategory()),"scene":"cornerfield-prototype.hipnc","units":"Roblox studs; Y up", "objects":[]}
for obj in scene.children():
    if obj.type().name()!="geo": continue
    output=obj.displayNode()
    if output is None: continue
    geo=output.geometry()
    if output.errors(): raise RuntimeError((obj.path(),output.errors()))
    stats["objects"].append({"name":obj.name(),"points":len(geo.points()),"polygons":len(geo.prims()),"visible":obj.isDisplayFlagSet()})
hou.hipFile.save(str(OUT/"cornerfield-prototype.hipnc"),save_to_recent_files=False)
(OUT/"houdini-report.json").write_text(json.dumps(stats,indent=2),encoding="utf-8")
print(json.dumps(stats,indent=2))
