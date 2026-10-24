"""Offline review of the actual native 3D buff meshes exported by tests."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]


def main():
    models = json.loads((ROOT / "assets/buff-models-geometry.json").read_text(encoding="utf-8"))
    scale = 2
    image = Image.new("RGB", (1100*scale, 480*scale), (26, 23, 44))
    draw = ImageDraw.Draw(image)
    glow = Image.new("RGB", image.size)
    gd = ImageDraw.Draw(glow)
    font = lambda size: ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", size*scale)
    draw.text((40*scale, 24*scale), "GLOWING 3D BUFFS", font=font(30), fill=(243, 242, 255))
    angle, elevation = .45, .22
    right = (math.cos(angle), 0, math.sin(angle))
    up = (-math.sin(elevation)*math.sin(angle), math.cos(elevation), math.sin(elevation)*math.cos(angle))
    toward = (math.cos(elevation)*math.sin(angle), math.sin(elevation), -math.cos(elevation)*math.cos(angle))
    dot = lambda a,b: sum(x*y for x,y in zip(a,b))
    faces = ((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
    for index,kind in enumerate(("Stamina","Dash")):
        cx,cy = (280+index*540)*scale, 225*scale
        polygons = []
        for part in models[kind]:
            part_center = [sum(v[i] for v in part["vertices"])/8 for i in range(3)]
            for face in faces:
                vertices = [part["vertices"][i] for i in face]
                center = [sum(v[i] for v in vertices)/4 for i in range(3)]
                a = [vertices[1][i]-vertices[0][i] for i in range(3)]
                b = [vertices[2][i]-vertices[0][i] for i in range(3)]
                normal = (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
                length = math.sqrt(dot(normal,normal)) or 1
                shade = .7+.3*abs(dot([v/length for v in normal],(-.4,.8,-.4)))
                color = tuple(round(c*shade) for c in part["color"])
                points = [(cx+dot(v,right)*64*scale,cy-dot(v,up)*64*scale) for v in vertices]
                polygons.append((dot(part_center,toward),dot(center,toward),points,color,part["neon"]))
        for _,_,points,color,neon in sorted(polygons,key=lambda p:(p[0],p[1])):
            draw.polygon(points,fill=color)
            if neon: gd.polygon(points,fill=tuple(round(c*.35) for c in color))
        draw.text((cx,393*scale), "STAMINA" if index==0 else "DASH", font=font(23), fill=(145,255,214) if index==0 else (110,223,255), anchor="mm")
    from PIL import ImageChops
    image = ImageChops.screen(image,glow.filter(ImageFilter.GaussianBlur(9*scale)))
    draw = ImageDraw.Draw(image)
    draw.text((550*scale,443*scale), "Native neon parts and glow lights | offline geometry review", font=font(17), fill=(186,179,212), anchor="mm")
    image.resize((1100,480),Image.Resampling.LANCZOS).save(ROOT / "assets/pickup-icons-preview.png")
    print("Created pickup-icons-preview.png from tested native 3D models")


if __name__ == "__main__":
    main()
