"""Native Houdini SOP geometry for the noncommercial retail prototype.

Coordinates match Roblox (Y up, source studs). Functions run inside Python SOPs.
"""
import json
import math
from pathlib import Path
import hou

PAINT = (0.68, 0.70, 0.65)
STEEL = (0.20, 0.23, 0.24)
GREEN = (0.10, 0.24, 0.17)
PAPER = (0.94, 0.91, 0.81)


class Mesh:
    def __init__(self, geo):
        self.geo = geo
        self.cd = geo.addAttrib(hou.attribType.Prim, "Cd", (1.0, 1.0, 1.0))
        self.name = geo.addAttrib(hou.attribType.Prim, "name", "")
        self.uv = geo.addAttrib(hou.attribType.Vertex, "uv", (0.0, 0.0, 0.0))

    def polygon(self, coords, name, color):
        poly = self.geo.createPolygon()
        for i, position in enumerate(coords):
            if isinstance(position, hou.Point):
                point = position
            else:
                point = self.geo.createPoint()
                point.setPosition(position)
            vertex = poly.addVertex(point)
            vertex.setAttribValue(self.uv, ((i == 1 or i == 2) * 1.0, (i >= 2) * 1.0, 0.0))
        poly.setAttribValue(self.cd, color)
        poly.setAttribValue(self.name, name)

    def box(self, name, center, size, color=PAINT, rotation=(0, 0, 0)):
        transform = hou.hmath.buildRotate(rotation)
        x, y, z = (v / 2 for v in size)
        vertices = [(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),
                    (-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)]
        vertices = [tuple(hou.Vector3(v) * transform + hou.Vector3(center)) for v in vertices]
        points = []
        for position in vertices:
            point = self.geo.createPoint()
            point.setPosition(position)
            points.append(point)
        for face in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)]:
            self.polygon([points[i] for i in face], name, color)

    def cylinder(self, name, center, radius, height, color=STEEL, axis="Y", segments=16):
        def pos(angle, along):
            a, b = math.cos(angle) * radius, math.sin(angle) * radius
            local = {"Y":(a, along, b), "X":(along, a, b), "Z":(a, b, along)}[axis]
            return tuple(local[i] + center[i] for i in range(3))
        low = [pos(i * math.tau / segments, -height / 2) for i in range(segments)]
        high = [pos(i * math.tau / segments, height / 2) for i in range(segments)]
        def points(positions):
            result=[]
            for position in positions:
                point=self.geo.createPoint(); point.setPosition(position); result.append(point)
            return result
        low,high=points(low),points(high)
        # The X/Y/Z permutations differ in handedness; Y requires reversed winding.
        flip = axis == "Y"
        def emit(coords):
            self.polygon(coords[::-1] if flip else coords, name, color)
        emit(low[::-1]); emit(high)
        for i in range(segments):
            j = (i + 1) % segments
            emit([low[i], low[j], high[j], high[i]])


def reference(geo, path):
    """Measured baseline reference; block proxy for non-box shapes is intentional."""
    data = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    mesh = Mesh(geo)
    for node in data["nodes"]:
        if "size" not in node or node.get("transparency", 0) >= 1:
            continue
        vector = lambda field: tuple(node[field][key] for key in ("X", "Y", "Z"))
        color = tuple(node["color"][key] for key in ("R", "G", "B"))
        mesh.box(f'ref_{node["id"]}_{node["name"]}', vector("position"), vector("size"), color, vector("orientation"))


def shell(geo, width, depth, height):
    mesh = Mesh(geo)
    masonry = (0.57, 0.50, 0.39)
    floor = (0.66, 0.65, 0.59)
    half_w, half_d = width / 2, depth / 2
    mesh.box("Floor", (0, .5, 0), (width, 1, depth), floor)
    for name, center, size in [
        ("BackWall",(0,1+height/2,-half_d),(width,height,.7)),
        ("WestWall",(-half_w,1+height/2,0),(.7,height,depth)),
        ("EastWall",(half_w,1+height/2,0),(.7,height,depth)),
        ("FrontHeader",(0,height-.5,half_d),(width,3,.7)),
    ]:
        mesh.box(name,center,size,masonry)
    # Front opening: 14-stud entrance; 28-stud windows on each side.
    for sign in (-1, 1):
        outer = (half_w + 37) / 2
        mesh.box(f"FrontPier{sign}",(sign*outer,7,half_d),(half_w-37,12,.7),masonry)
        mesh.box(f"WindowSill{sign}",(sign*22,1.8,half_d),(30,1.6,.85),masonry)
        for x in (7, 22, 37):
            mesh.box(f"Mullion{sign}_{x}",(sign*x,7.4,half_d),(.24,10.2,.35),STEEL)
        mesh.box(f"WindowGlass{sign}",(sign*22,7.4,half_d),(29.6,9.7,.10),(.28,.40,.42))
    mesh.box("Canopy",(0,12.2,half_d+3),(width+1,.35,7),GREEN)
    mesh.box("CanopyFascia",(0,12.0,half_d+6.4),(width+1,.9,.25),GREEN)
    for x in (-7.1,7.1):
        mesh.box("DoorJamb",(x,6,half_d),(.3,10,.5),STEEL)
    mesh.box("DoorTrack",(0,11,half_d),(14.5,.35,.6),STEEL)
    mesh.box("SignBacker",(0,height+1,half_d+.55),(54,4,.4),GREEN)
    # Actual narrow tile joints, kept slightly above the slab to avoid z-fighting.
    for x in range(int(-half_w)+4,int(half_w),4):
        mesh.box("TileJointX",(x,1.008,0),(.025,.01,depth-.5),(.46,.46,.43))
    for z in range(int(-half_d)+4,int(half_d),4):
        mesh.box("TileJointZ",(0,1.008,z),(width-.5,.01,.025),(.46,.46,.43))
    for x in (-18,18):
        mesh.cylinder("Bollard",(x,2.6,half_d+6),.32,3.2,GREEN)
        mesh.cylinder("BollardBase",(x,1.15,half_d+6),.5,.25,STEEL)


def roof(geo,width,depth,height):
    mesh=Mesh(geo)
    mesh.box("RemovableRoof",(0,height+1,0),(width+2,.4,depth+2),(.23,.25,.24))
    for x in (-width/2,width/2):
        mesh.box("Parapet",(x,height+1.8,0),(.45,1.3,depth+2),PAINT)
    for x in (-35,35):
        mesh.box("HVACBase",(x,height+2.3,-15),(11,2,7),PAINT)
        for dx in (-2.6,2.6):
            mesh.cylinder("FanRim",(x+dx,height+3.4,-15),1.7,.3,STEEL)
            mesh.cylinder("FanInset",(x+dx,height+3.57,-15),1.5,.05,(.08,.1,.1))
        for i in range(8):
            mesh.box("HVACLouver",(x,height+1.7+i*.16,-11.45),(9,.045,.08),STEEL)


def shelf(geo,width,height,depth,tiers):
    mesh=Mesh(geo)
    mesh.box("Plinth",(0,.24,0),(width,.48,depth),PAINT)
    mesh.box("BackPanel",(0,height/2,-depth/2+.10),(width,height,.12),PAINT)
    for x in (-width/2+.16,width/2-.16):
        mesh.box("Upright",(x,height/2,-depth/2+.26),(.28,height,.34),STEEL)
        for step in range(1,int(height/.38)):
            mesh.box("AdjustmentSlot",(x,step*.38,-depth/2+.438),(.09,.16,.018),(.05,.06,.05))
        mesh.box("Foot",(x,.18,0),(.45,.25,depth+.18),STEEL)
    for tier in range(tiers):
        y=.65+tier*(height-1.15)/max(1,tiers-1)
        mesh.box("ShelfDeck",(0,y,0),(width-.36,.12,depth-.18),PAINT)
        mesh.box("PriceRail",(0,y+.05,depth/2),(width-.3,.3,.10),GREEN)
        for x in (-width/2+.35,width/2-.35):
            mesh.box("ShelfBracket",(x,y-.20,-.15),(.16,.28,depth-.6),STEEL)
        for col in range(8):
            x=-width/2+.85+col*(width-1.7)/7
            color=[(.65,.21,.10),(.85,.64,.19),(.20,.37,.23),(.22,.34,.55)][(col+tier)%4]
            for row in range(2):
                z=-depth/2+.85+row*.95
                if col%3==0:
                    mesh.cylinder("ProductTin",(x,y+.66,z),.36,1.18,color)
                    mesh.cylinder("TinLid",(x,y+1.26,z),.37,.04,PAINT)
                else:
                    mesh.box("ProductCarton",(x,y+.75,z),(.78,1.35,.68),color)
                    mesh.box("PackageLabel",(x,y+.8,z+.35),(.62,.65,.025),PAPER)
            mesh.box("PriceLabel",(x,y+.07,depth/2+.06),(.7,.20,.015),PAPER)


def cook(node):
    geo=node.geometry()
    kind=node.evalParm("kind")
    if kind=="reference":
        reference(geo,hou.expandString(node.evalParm("reference_file")))
    elif kind=="shell":
        shell(geo,node.evalParm("width"),node.evalParm("depth"),node.evalParm("height"))
    elif kind=="roof":
        roof(geo,node.evalParm("width"),node.evalParm("depth"),node.evalParm("height"))
    else:
        shelf(geo,node.evalParm("width"),node.evalParm("height"),node.evalParm("depth"),node.evalParm("tiers"))
