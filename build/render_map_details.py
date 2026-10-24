"""Offline isometric overview of tested native biome/course part data."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
base = json.loads((ROOT / "assets/chase-courses-geometry.json").read_text(encoding="utf-8"))
themes = json.loads((ROOT / "assets/map-mechanics-geometry.json").read_text(encoding="utf-8"))
image = Image.new("RGB", (1500, 900), (25, 22, 43))
draw = ImageDraw.Draw(image)
font = lambda size: ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)
draw.text((45, 26), "RIFT VALLEY / BIOME DETAIL", font=font(40), fill=(245, 243, 255))
draw.text((45, 82), "Open views, landmarks and branching routes", font=font(22), fill=(189, 178, 219))
angle, elevation = .43, .78
right = (math.cos(angle), 0, math.sin(angle))
up = (-math.sin(elevation)*math.sin(angle), math.cos(elevation), math.sin(elevation)*math.cos(angle))
toward = (math.cos(elevation)*math.sin(angle), math.sin(elevation), -math.cos(elevation)*math.cos(angle))
dot = lambda a,b: sum(x*y for x,y in zip(a,b))
faces = ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
for index,(key,title,caption,tint) in enumerate((
    ("CrystalGrove","CRYSTAL GROVE","Root canopies / luminous fungi",(123,255,190)),
    ("SunsetRuins","SUNSET RUINS","Carved columns / broken temples",(255,194,120)),
    ("NeonHarbor","NEON HARBOR","Dock cranes / floodlights / cargo",(120,218,255)))):
    left = 30+index*494
    draw.rounded_rectangle((left,130,left+476,826),20,fill=(37,31,61),outline=(89,75,126),width=2)
    draw.text((left+20,153),title,font=font(27),fill=tint)
    draw.text((left+20,193),caption,font=font(18),fill=(211,203,230))
    cx,cy,s = left+237,490,1.65
    ox,oz = -230,0
    parts = [p for p in base if abs(p["pos"][0]-ox)<48 and abs(p["pos"][2]-oz)<180]
    parts += [p for p in themes[key] if p["stage"]==3]
    polygons = []
    for part in parts:
        if part["name"] in ("Sign","CourseGateBeam","CourseBoundary","CourseBackWall"):
            continue
        x,y,z = part["pos"]
        sx,sy,sz = part["size"]
        yaw = part.get("yaw",0)
        c,sn = math.cos(yaw),math.sin(yaw)
        vertices = []
        for dz in (-1,1):
            for dy in (-1,1):
                for dx in (-1,1):
                    lx,lz = dx*sx/2,dz*sz/2
                    vertices.append((x-ox+c*lx+sn*lz,y+dy*sy/2,z-oz-sn*lx+c*lz))
        for face in faces:
            points = [vertices[i] for i in face]
            center = [sum(p[i] for p in points)/4 for i in range(3)]
            color = tuple(round(v*(.82 if face in (faces[0],faces[4]) else 1)) for v in part["color"])
            foundation = part["name"] in ("CourseFloor","CourseDeck","FloatingStoneUnderside")
            polygons.append((0 if foundation else 1,dot(center,toward),[(cx+dot(v,right)*s,cy-dot(v,up)*s) for v in points],color))
    for _,_,points,color in sorted(polygons,key=lambda p:(p[0],p[1])): draw.polygon(points,fill=color)
    draw.text((cx,773),"SERPENT SLALOM",font=font(19),fill=(226,217,243),anchor="mm")
draw.text((750,866),"Offline layout illustration from native part data. Studio gameplay and lighting verification remain pending.",font=font(18),fill=(179,170,201),anchor="mm")
image.save(ROOT / "assets/map-details-preview.png")
print("Created map-details-preview.png from tested native biome part data")
