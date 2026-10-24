"""Publication artwork rendered from Rift Valley's native geometry exports."""
import ast
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
PALETTE = {"paper": (244, 243, 255), "mint": (108, 255, 204)}


def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)


def canvas(size):
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(size[1]):
        t = y / size[1]
        draw.line((0, y, size[0], y), fill=(round(20 + 12*t), round(18 + 10*t), round(40 + 19*t)))
    return image, draw


def catcher(draw, x, floor, scale):
    # Reuse the established native creature renderer without its preview side effects.
    tree = ast.parse((ROOT / "build/render_catcher.py").read_text())
    render_function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "render")
    scope = {"math": math, "draw": draw, "geometry": json.loads((ASSETS / "catcher-geometry.json").read_text())}
    exec(compile(ast.Module(body=[render_function], type_ignores=[]), "native-catcher-render", "exec"), scope)
    scope["render"](x, floor, -.18, scale)


def course(draw, key, center_x, center_y, scale):
    base = json.loads((ASSETS / "chase-courses-geometry.json").read_text())
    themes = json.loads((ASSETS / "map-mechanics-geometry.json").read_text())
    parts = [p for p in base if abs(p["pos"][0]+230) < 48 and abs(p["pos"][2]) < 180]
    parts += [p for p in themes[key] if p["stage"] == 3]
    angle, elevation = .43, .78
    right = (math.cos(angle), 0, math.sin(angle))
    up = (-math.sin(elevation)*math.sin(angle), math.cos(elevation), math.sin(elevation)*math.cos(angle))
    toward = (math.cos(elevation)*math.sin(angle), math.sin(elevation), -math.cos(elevation)*math.cos(angle))
    dot = lambda a, b: sum(x*y for x, y in zip(a, b))
    faces = ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
    polygons = []
    for p in parts:
        if p["name"] in ("Sign", "CourseGateBeam", "CourseBoundary", "CourseBackWall"):
            continue
        x, y, z = p["pos"]
        sx, sy, sz = p["size"]
        c, sn = math.cos(p.get("yaw", 0)), math.sin(p.get("yaw", 0))
        vertices = []
        for dz in (-1, 1):
            for dy in (-1, 1):
                for dx in (-1, 1):
                    lx, lz = dx*sx/2, dz*sz/2
                    vertices.append((x+230+c*lx+sn*lz, y+dy*sy/2, z-sn*lx+c*lz))
        for face in faces:
            points = [vertices[i] for i in face]
            centroid = [sum(v[i] for v in points)/4 for i in range(3)]
            shade = .82 if face in (faces[0], faces[4]) else 1
            color = tuple(min(255, round(v*shade)) for v in p["color"])
            foundation = p["name"] in ("CourseFloor", "CourseDeck", "FloatingStoneUnderside")
            polygons.append((0 if foundation else 1, dot(centroid, toward),
                             [(center_x+dot(v, right)*scale, center_y-dot(v, up)*scale) for v in points], color))
    for _, _, points, color in sorted(polygons, key=lambda p: (p[0], p[1])):
        draw.polygon(points, fill=color)


def main():
    image, draw = canvas((1920, 1080))
    draw.text((70, 48), "RIFT VALLEY", font=font(112), fill=PALETTE["paper"])
    draw.text((77, 177), "SPRINT. DASH. ESCAPE.", font=font(38), fill=PALETTE["mint"])
    draw.ellipse((90, 350, 700, 980), fill=(38, 30, 68), outline=(83, 62, 121), width=3)
    catcher(draw, 390, 945, 102)
    draw.rounded_rectangle((100, 957, 670, 1032), 22, fill=PALETTE["mint"])
    draw.text((385, 994), "RUN TO FINISH!", anchor="mm", font=font(42), fill=(20, 30, 39))
    for index, (key, title, color) in enumerate((
        ("CrystalGrove", "CRYSTAL GROVE", (123, 255, 190)),
        ("SunsetRuins", "SUNSET RUINS", (255, 194, 120)),
        ("NeonHarbor", "NEON HARBOR", (120, 218, 255)),
    )):
        left = 760 + index*375
        draw.rounded_rectangle((left, 300, left+350, 995), 28, fill=(39, 32, 61), outline=(83, 68, 112), width=2)
        draw.text((left+175, 345), title, anchor="mm", font=font(29), fill=color)
        course(draw, key, left+175, 680, 2.15)
    draw.text((1320, 235), "FIVE COURSES  /  THREE WORLDS", anchor="mm", font=font(34), fill=(210, 201, 229))
    image.save(ASSETS / "launch-thumbnail.png")

    icon, draw = canvas((512, 512))
    draw.ellipse((44, 145, 468, 559), fill=(43, 32, 71), outline=(119, 85, 171), width=3)
    catcher(draw, 256, 494, 55)
    draw.text((256, 40), "RIFT", anchor="mt", font=font(68), fill=PALETTE["paper"])
    draw.text((256, 107), "VALLEY", anchor="mt", font=font(67), fill=PALETTE["mint"])
    icon.save(ASSETS / "launch-icon.png")
    print("Rendered launch-icon.png (512x512) and launch-thumbnail.png (1920x1080) from native geometry.")


if __name__ == "__main__":
    main()
