"""Top-down overview rendered from the actual onward course geometry."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
geometry = json.loads((ROOT / "assets/chase-courses-geometry.json").read_text())
image = Image.new("RGB", (1600, 1100), (17, 22, 39))
draw = ImageDraw.Draw(image)
def font(size):
    return ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size)
draw.text((65, 45), "BEYOND THE FINISH LINE", font=font(58), fill=(234, 242, 239))
draw.text((65, 122), "TURN / CLIMB / JUMP / TIME YOUR DASH", font=font(24), fill=(108, 255, 204))
stages = ((2, "SHATTERED STEPS", 230, 0, 3), (3, "SERPENT SLALOM", -230, 0, 4),
          (4, "BROKEN CAUSEWAY", 0, -430, 5), (5, "RIFT GAUNTLET", 230, -430, 6))
for index, (stage, name, ox, oz, count) in enumerate(stages):
    left = 50 + index * 387
    draw.rounded_rectangle((left, 190, left+355, 1008), radius=18, fill=(26, 35, 48), outline=(64, 79, 97), width=2)
    draw.text((left+20, 215), f"{stage}/5", font=font(26), fill=(174, 131, 255))
    draw.text((left+20, 258), name, font=font(23), fill=(238, 244, 240))
    draw.text((left+20, 302), f"{count} CATCHERS", font=font(20), fill=(108, 255, 204))
    scale = 1.72
    cx, cy = left+177, 670
    selected = [obj for obj in geometry if abs(obj["pos"][0]-ox) < 50 and abs(obj["pos"][2]-oz) < 180]
    for obj in sorted(selected, key=lambda part: part["pos"][1]):
        if obj["name"] in ("Sign", "RiftObelisk", "CourseGateBeam"):
            continue
        x, y, z = obj["pos"]
        sx, sy, sz = obj["size"]
        rectangle = (cx+(x-ox-sx/2)*scale, cy-(z-oz+sz/2)*scale,
                     cx+(x-ox+sx/2)*scale, cy-(z-oz-sz/2)*scale)
        color = tuple(obj["color"])
        draw.rectangle(rectangle, fill=color)
    draw.text((cx, 972), "START  /  RUN NORTH", anchor="mm", font=font(17), fill=(173, 190, 201))
draw.text((800, 1060), "Actual course geometry. Native Studio physics and jump testing remain pending.", anchor="mm", font=font(22), fill=(158, 177, 193))
image.save(ROOT / "assets/chase-courses-preview.png")
print("Created assets/chase-courses-preview.png")
