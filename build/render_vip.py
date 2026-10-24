"""Render the native VIP lounge geometry as a reviewable illustration."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
geometry = json.loads((ROOT / "assets/vip-geometry.json").read_text())
image = Image.new("RGB", (1400, 1050), (20, 23, 40))
draw = ImageDraw.Draw(image)
def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)
draw.text((65, 42), "THE VALLEY VIP SKY LOUNGE", font=font(51), fill=(244, 227, 190))
draw.text((67, 115), "VELVET SEATING / GLOWING GEAR / VIP ACTIVITY ARENA", font=font(23), fill=(176, 145, 216))
polygons = []
layers = {"LoungeFloor": 0, "LoungeMarbleTile": 1, "ChampagneInlay": 2, "LoungeRug": 2}
for obj in geometry:
    x, y, z = obj["pos"]
    sx, sy, sz = obj["size"]
    yaw = obj["yaw"]
    def vertex(a, b, c):
        dx, dz = a*sx/2, c*sz/2
        return (x+dx*math.cos(yaw)+dz*math.sin(yaw)-101, y+b*sy/2-28, z-dx*math.sin(yaw)+dz*math.cos(yaw)-224)
    for face, shade in ((((-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1)), .72),
                        (((-1,-1,1),(-1,-1,-1),(-1,1,-1),(-1,1,1)), .86),
                        (((-1,1,-1),(1,1,-1),(1,1,1),(-1,1,1)), 1.04)):
        vertices = [vertex(*v) for v in face]
        points = [(-a+c*.62, -a*.2-c*.5-b) for a,b,c in vertices]
        depth = sum(-a*.62+b*.624-c for a,b,c in vertices)/4
        color = tuple(min(255, round(c*shade)) for c in obj["color"])
        polygons.append((layers.get(obj["name"], 3), depth, points, color))
points = [point for _, _, polygon, _ in polygons for point in polygon]
x0, x1 = min(x for x,y in points), max(x for x,y in points)
y0, y1 = min(y for x,y in points), max(y for x,y in points)
scale = min(1230/(x1-x0), 680/(y1-y0))
for _, _, polygon, color in sorted(polygons, key=lambda p:(p[0],p[1])):
    draw.polygon([(700+(x-(x0+x1)/2)*scale, 535+(y-(y0+y1)/2)*scale) for x,y in polygon], fill=color)
draw.text((700, 937), "SPEED COIL / JUMP COIL / RIFT BLASTER / ARENA COVER", anchor="mm", font=font(24), fill=(231, 199, 137))
draw.text((700, 997), "Native geometry illustration. See deploy/studio-test-results.json for test scope.", anchor="mm", font=font(20), fill=(154, 171, 188))
image.save(ROOT / "assets/vip-preview.png")
print("Created assets/vip-preview.png")
