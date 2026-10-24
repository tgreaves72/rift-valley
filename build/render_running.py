"""Animate the sampled native run poses as a small GIF preview."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
import render_catcher as renderer

ROOT = Path(__file__).resolve().parents[1]
poses = json.loads((ROOT / "assets/catcher-run-frames.json").read_text())
frames = []
for pose in poses:
    img = Image.new("RGB", (640, 560), (16, 23, 31))
    renderer.img, renderer.draw, renderer.geometry = img, ImageDraw.Draw(img), pose
    renderer.draw.text((32, 22), "RIFT STALKER / RUN", font=renderer.font(29), fill=(241, 240, 227))
    renderer.draw.text((33, 63), "Authored loop / actual model geometry", font=renderer.font(17), fill=(183, 139, 255))
    renderer.render(315, 482, .5, 55)
    renderer.draw.text((320, 530), "Animation preview", anchor="mm", font=renderer.font(18), fill=(160, 182, 181))
    frames.append(img.quantize(colors=128))
frames[0].save(ROOT / "assets/catcher-running.gif", save_all=True, append_images=frames[1:], duration=57, loop=0, disposal=2)
print("Created assets/catcher-running.gif from the authored run cycle")
