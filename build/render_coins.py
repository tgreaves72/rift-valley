"""Offline view of the tested native coin parts, including true round faces."""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

root=Path(__file__).resolve().parents[1]
parts=json.loads((root/"assets/coin-model-geometry.json").read_text())
scale=2
image=Image.new("RGB",(900*scale,540*scale),(26,23,44))
glow=Image.new("RGB",image.size)
draw,gd=ImageDraw.Draw(image),ImageDraw.Draw(glow)
font=lambda size:ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf",size*scale)
draw.text((40*scale,28*scale),"GLOWING RIFT COINS",font=font(31),fill=(243,240,255))
right,up,toward=(.94,0,.342),(-.068,.98,.188),(.335,.2,-.921)
dot=lambda a,b:sum(x*y for x,y in zip(a,b))
polygons=[]
for part in parts:
    if part["name"]=="CoinRune" and part["frame"][2]-part["origin"][2]>0: continue
    sx,sy,sz=part["size"]
    if part["cylinder"]:
        vertices=[(end*sx/2,math.cos(i*math.tau/40)*sy/2,math.sin(i*math.tau/40)*sz/2) for end in (-1,1) for i in range(40)]
        faces=[tuple(range(40)),tuple(range(40,80))]+[(i,(i+1)%40,(i+1)%40+40,i+40) for i in range(40)]
    else:
        vertices=[(x*sx/2,y*sy/2,z*sz/2) for z in (-1,1) for y in (-1,1) for x in (-1,1)]
        faces=((0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3))
    cf,origin=part["frame"],part["origin"]
    vertices=[tuple(cf[row]-origin[row]+sum(cf[3+row*3+j]*v[j] for j in range(3)) for row in range(3)) for v in vertices]
    for face in faces:
        points=[vertices[i] for i in face]
        center=[sum(v[i] for v in points)/len(points) for i in range(3)]
        shade=.74+.2*max(0,center[1]/2)+(.05 if part["name"]=="CoinRune" else 0)
        color=tuple(min(255,round(c*shade)) for c in part["color"])
        screen=[((450+dot(v,right)*97)*scale,(285-dot(v,up)*97)*scale) for v in points]
        polygons.append((part["name"]=="CoinRune",dot(center,toward),screen,color,part["name"]!="CoinFace"))
for _,_,points,color,neon in sorted(polygons,key=lambda row:(row[0],row[1])):
    draw.polygon(points,fill=color)
    if neon:gd.polygon(points,fill=tuple(round(c*.4) for c in color))
image=ImageChops.screen(image,glow.filter(ImageFilter.GaussianBlur(10*scale)))
draw=ImageDraw.Draw(image)
draw.text((450*scale,490*scale),"Solid round pickups | fixed orientation | offline geometry review",anchor="mm",font=font(20),fill=(190,183,214))
image.resize((900,540),Image.Resampling.LANCZOS).save(root/"assets/coin-pickup-preview.png")
print("Created coin-pickup-preview.png from tested native coin geometry")
