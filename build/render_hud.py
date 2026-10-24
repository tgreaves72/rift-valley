"""Review exported live-script HUD layouts, without claiming an engine screenshot."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
fonts = list(Path("C:/Program Files/Roblox/Versions").glob("*/content/fonts/FredokaOne-Regular.ttf"))
heading_font = str(fonts[0]) if fonts else "C:/Windows/Fonts/arialbd.ttf"


def render(source):
    layout = json.loads(source.read_text())
    width, height = layout["width"], layout["height"]
    factor = 2
    canvas = Image.new("RGBA", (width*factor, height*factor), (29, 24, 49, 255))
    for item in layout["items"]:
        layer = Image.new("RGBA", canvas.size)
        draw = ImageDraw.Draw(layer)
        x, y, w, h = [item[key]*factor for key in ("x", "y", "w", "h")]
        box = (round(x), round(y), round(x+w), round(y+h))
        fill = (*map(round, item["background"]), round(item["alpha"]*255))
        stroke = (*map(round, item.get("stroke", [0, 0, 0])), round(item.get("strokeAlpha", 0)*255))
        draw.rounded_rectangle(box, radius=item["radius"]*factor, fill=fill,
                               outline=stroke, width=round(item.get("strokeWidth", 0)*factor))
        if item.get("text"):
            font = ImageFont.truetype(heading_font if item["font"] == "FredokaOne" else "C:/Windows/Fonts/arial.ttf",
                                      max(1, round(item["fontSize"]*factor)))
            words, lines = item["text"].split(" "), [""]
            for word in words:
                candidate = (lines[-1]+" "+word).strip()
                if draw.textlength(candidate, font=font) > w and lines[-1]:
                    lines.append(word)
                else:
                    lines[-1] = candidate
            leading = item["fontSize"]*factor*1.15
            top = y + (h-leading*len(lines))/2
            for line in lines:
                tx = x if item["align"] == "Left" else x+(w-draw.textlength(line, font=font))/2
                draw.text((tx, top), line, font=font, fill=tuple(map(round, item["color"])), anchor="lt")
                top += leading
        canvas = Image.alpha_composite(canvas, layer)
    return canvas.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)


for source in (ROOT/"assets").glob("hud-*-layout.json"):
    output = source.with_name(source.name.replace("-layout.json", "-preview.png"))
    render(source).save(output)
    print(f"Created {output.name} (offline GUI layout review)")
