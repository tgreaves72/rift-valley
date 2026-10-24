"""Review the tested native vote emblems, including wedge faces and neon glow."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

root = Path(__file__).resolve().parents[1]
models = json.loads((root / "assets/map-vote-icons-geometry.json").read_text())
factor = 2
canvas = Image.new("RGB", (1260*factor, 520*factor), (26, 23, 44))
glow = Image.new("RGB", canvas.size)
draw, gd = ImageDraw.Draw(canvas), ImageDraw.Draw(glow)
font = lambda size: ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size*factor)
draw.text((38*factor, 25*factor), "VOTE WITH YOUR FEET", font=font(30), fill=(244, 242, 255))
right, up, toward = (.98, 0, .2), (-.04, .98, .196), (.196, .2, -.96)
dot = lambda a, b: sum(x*y for x, y in zip(a, b))
cube = ((0,1,3,2), (4,6,7,5), (0,4,5,1), (2,3,7,6), (0,2,6,4), (1,5,7,3))
wedge = ((0,4,5,1), (4,6,7,5), (0,1,7,6), (0,6,4), (1,5,7))
for index, (key, title) in enumerate((("CrystalGrove", "CRYSTAL GROVE"), ("SunsetRuins", "SUNSET RUINS"), ("NeonHarbor", "NEON HARBOR"))):
    cx, cy = (210+index*420)*factor, 260*factor
    polygons = []
    for part in models[key]:
        for face in wedge if part["class"] == "WedgePart" else cube:
            vertices = [part["vertices"][i] for i in face]
            center = [sum(v[i] for v in vertices)/len(vertices) for i in range(3)]
            a, b = ([vertices[1][i]-vertices[0][i] for i in range(3)], [vertices[2][i]-vertices[0][i] for i in range(3)])
            normal = (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
            length = math.sqrt(dot(normal, normal)) or 1
            shade = .66+.34*abs(dot([v/length for v in normal], (-.4,.8,-.4)))
            color = tuple(round(c*shade) for c in part["color"])
            points = [(cx+dot(v,right)*43*factor, cy-dot(v,up)*43*factor) for v in vertices]
            polygons.append((dot(center,toward), points, color, part["neon"]))
    for _, points, color, neon in sorted(polygons, key=lambda row: row[0]):
        draw.polygon(points, fill=color)
        if neon: gd.polygon(points, fill=tuple(round(c*.32) for c in color))
    draw.text((cx, 439*factor), title, anchor="mm", font=font(23), fill=(228, 224, 247))
canvas = ImageChops.screen(canvas, glow.filter(ImageFilter.GaussianBlur(7*factor)))
ImageDraw.Draw(canvas).text((630*factor, 492*factor), "Native 3D map emblems | offline geometry preview", anchor="mm", font=font(17), fill=(183, 176, 208))
canvas.resize((1260,520), Image.Resampling.LANCZOS).save(root / "assets/map-vote-icons-preview.png")
print("Created map-vote-icons-preview.png from tested native geometry")
