"""Render the posed native creature geometry exported by the rig validation."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
geometry = json.loads((ROOT / "assets/catcher-geometry.json").read_text())
img = Image.new("RGB", (1400, 1050), (16, 23, 31))
draw = ImageDraw.Draw(img)

def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)

def render(ox, oy, angle, scale):
    elev = .1
    right = (math.cos(angle), 0, math.sin(angle))
    up = (-math.sin(elev)*math.sin(angle), math.cos(elev), math.sin(elev)*math.cos(angle))
    toward = (math.cos(elev)*math.sin(angle), math.sin(elev), -math.cos(elev)*math.cos(angle))
    def dot(a, b): return sum(x*y for x, y in zip(a, b))
    def project(v): return (ox + dot(v, right)*scale, oy - dot(v, up)*scale)
    polygons = []
    for part in geometry:
        verts = part["vertices"]
        faces = ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3))
        if part["wedge"]: faces = ((0, 1, 5, 4), (4, 5, 7, 6), (0, 4, 6), (1, 7, 5), (0, 6, 7, 1))
        for face in faces:
            points = [verts[i] for i in face]
            a = [points[1][i] - points[0][i] for i in range(3)]
            b = [points[2][i] - points[0][i] for i in range(3)]
            normal = (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
            length = math.sqrt(dot(normal, normal)) or 1
            shade = .66 + .38*abs(dot([n/length for n in normal], (-.35, .8, -.5)))
            if part["name"] == "GlowingEye": shade = 1.2
            rgb = tuple(min(255, round(c*shade)) for c in part["rgb"])
            centroid = [sum(p[i] for p in points)/len(points) for i in range(3)]
            polygons.append((dot(centroid, toward), [project(v) for v in points], rgb))
    draw.ellipse((ox-230, oy-12, ox+230, oy+37), fill=(10, 16, 23))
    for _, points, rgb in sorted(polygons, key=lambda p: p[0]): draw.polygon(points, fill=rgb)

draw.text((64, 50), "RIFT STALKER", font=font(66), fill=(240, 240, 226))
draw.text((67, 135), "CATCHER DESIGN / RIFT VALLEY 0.4.0", font=font(27), fill=(183, 139, 255))
draw.line((64, 192, 1336, 192), fill=(61, 77, 86), width=2)
render(405, 849, -.18, 92)
render(1040, 849, .72, 82)
draw.text((405, 895), "FRONT", anchor="mm", font=font(24), fill=(165, 185, 184))
draw.text((1040, 895), "THREE-QUARTER", anchor="mm", font=font(24), fill=(165, 185, 184))
draw.text((700, 960), "Glowing eyes / mask-like face / long arms / clawed hands / hunched run", anchor="mm", font=font(27), fill=(223, 224, 209))
draw.text((700, 1004), "Rendered from the game's actual creature geometry. Original primitive model.", anchor="mm", font=font(20), fill=(137, 157, 164))
img.save(ROOT / "assets/catcher-preview.png")
print("Created assets/catcher-preview.png from the tested native rig")
