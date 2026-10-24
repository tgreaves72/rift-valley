"""Illustrate the native lobby geometry, without substituting an imagined scene."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
geometry = json.loads((ROOT / "assets/lobby-geometry.json").read_text())
img = Image.new("RGB", (1600, 1000), (21, 23, 43))
d = ImageDraw.Draw(img)
font_path = "C:/Windows/Fonts/bahnschrift.ttf"
def font(size): return ImageFont.truetype(font_path, size)
d.ellipse((1250, 75, 1400, 225), fill=(180, 192, 232))
for x, y in ((100, 200), (360, 40), (660, 125), (1150, 35), (1520, 260), (1450, 75)):
    d.ellipse((x, y, x+3, y+3), fill=(183, 193, 234))
d.text((64, 45), "THE EXPANDED RIFT OVERLOOK", font=font(55), fill=(241, 240, 227))
d.text((66, 121), "2.7X PUBLIC SPACE / RIFT FOUNTAIN / FLOWERING GARDENS", font=font(25), fill=(162, 142, 222))
def raw_project(x, y, z):
    z, y = z - 282, y - 28
    return (x - z*.62, x*.20 + z*.50 - y)
polygons = []
ground = {"PlazaFoundation": 0, "LobbyFloor": 1, "PlazaFloor": 1, "PlazaConnector": 1, "LoungeFloor": 1,
          "CourtyardTile": 2, "PlazaPaving": 2, "InlaidPath": 2, "GardenPathInlay": 2, "GardenCrossPath": 2}
for obj in geometry:
    x,y,z = obj["pos"]
    sx,sy,sz = obj["size"]
    angle = obj["yaw"]
    def v(a,b,c):
        dx, dz = a*sx/2, c*sz/2
        return (x+dx*math.cos(angle)+dz*math.sin(angle), y+b*sy/2, z-dx*math.sin(angle)+dz*math.cos(angle))
    for face, shade in (((( -1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)),.7), (((1,-1,-1),(1,-1,1),(1,1,1),(1,1,-1)),.85), (((-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)),1.05)):
        vertices = [v(*p) for p in face]
        depth = sum(a*.62+c+b*.624 for a,b,c in vertices)/len(vertices)
        rgb = tuple(min(255, round(c*shade)) for c in obj["color"])
        polygons.append((ground.get(obj["name"], 3), depth, [raw_project(*p) for p in vertices], rgb))
all_points = [point for _, _, points, _ in polygons for point in points]
x0, x1 = min(x for x, y in all_points), max(x for x, y in all_points)
y0, y1 = min(y for x, y in all_points), max(y for x, y in all_points)
scale = min(1460/(x1-x0), 665/(y1-y0))
for _, _, points, rgb in sorted(polygons, key=lambda p:(p[0], p[1])):
    d.polygon([(800+(x-(x0+x1)/2)*scale, 530+(y-(y0+y1)/2)*scale) for x, y in points], fill=rgb)
d.text((800, 905), "12 SOCIAL SEATS / LANTERN WALK / FLOATING ISLANDS / FREE PARKOUR", anchor="mm", font=font(25), fill=(108, 255, 204))
d.text((800, 966), "Geometry illustration of the rebuilt lobby. Studio playtesting remains required.", anchor="mm", font=font(22), fill=(157, 177, 186))
img.save(ROOT / "assets/lobby-preview.png")
print("Created assets/lobby-preview.png")
