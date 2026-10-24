"""Top-down design review from the exported native course and mechanic geometry."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
base = json.loads((ROOT/"assets/chase-courses-geometry.json").read_text())
themes = json.loads((ROOT/"assets/map-mechanics-geometry.json").read_text())
image = Image.new("RGB", (1440, 1050), (29, 24, 49))
draw = ImageDraw.Draw(image)
font = lambda n: ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", n)
draw.text((50, 32), "CHOOSE YOUR ROUTE", font=font(46), fill=(246, 245, 255))
draw.text((50, 94), "Native layout review: safer detours, shortcut crystals and themed obstacles", font=font(23), fill=(185, 177, 216))
for index, (key, title, sub) in enumerate((("CrystalGrove", "CRYSTAL GROVE", "Raised bridges grant a speed boost"), ("SunsetRuins", "SUNSET RUINS", "Stones warn before crumbling"), ("NeonHarbor", "NEON HARBOR", "Cargo moves across the route"))):
    left, cx, cy, scale = 45+index*465, 270+index*465, 610, 1.85
    draw.rounded_rectangle((left, 155, left+440, 985), 20, fill=(48, 35, 82), outline=(105, 88, 143), width=2)
    draw.text((left+20, 178), title, font=font(28), fill=(246,245,255))
    draw.text((left+20, 223), sub, font=font(20), fill=(145,255,214))
    parts = [p for p in base if abs(p["pos"][0]) < 48 and abs(p["pos"][2]+430) < 180]
    parts += [p for p in themes[key] if p["stage"] == 4]
    for part in sorted(parts, key=lambda p: p["pos"][1]):
        if part["name"] in ("Sign", "RiftObelisk", "CourseGateBeam", "CourseBoundary", "CourseBackWall"):
            continue
        x, _, z = part["pos"]
        sx, _, sz = part["size"]
        box = (cx+(x-sx/2)*scale, cy-(z+430+sz/2)*scale, cx+(x+sx/2)*scale, cy-(z+430-sz/2)*scale)
        draw.rectangle(box, fill=tuple(round(c) for c in part["color"]))
    draw.text((cx, 955), "SWITCH SIDES / JUMP SHORTCUTS", anchor="mm", font=font(19), fill=(255,221,137))
draw.text((720, 1020), "Actual geometry shown. Roblox Studio must verify movement, jumps and NPC pathfinding.", anchor="mm", font=font(21), fill=(185,177,216))
image.save(ROOT/"assets/route-choices-preview.png")
print("Created route-choices-preview.png (native geometry review)")
