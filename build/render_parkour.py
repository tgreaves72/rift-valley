"""Diagram the authored parkour platforms from the native build's geometry export."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[1]
parts=json.loads((root/"assets/lobby-geometry.json").read_text(encoding="utf-8"))
steps={int(p["name"].split("_")[1]):p for p in parts if p["name"].startswith("ParkourStep_")}
dock=next(p for p in parts if p["name"]=="ParkourDock")
image=Image.new("RGB",(1600,1000),(25,22,43))
draw=ImageDraw.Draw(image)
font=lambda n:ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf",n)
draw.text((50,35),"RIFT ASCENT / 24 PLATFORMS",font=font(48),fill=(245,243,255))
draw.text((52,102),"Precision landings, narrow beams and milestone beacons. Falls end the attempt.",font=font(25),fill=(189,178,219))
for panel in range(4):
    left,top=40+(panel%2)*780,180+(panel//2)*370
    draw.rounded_rectangle((left,top,left+740,top+340),18,fill=(42,32,69),outline=(94,75,135),width=2)
    first,last=panel*6+1,(panel+1)*6
    draw.text((left+24,top+17),f"{first}-{last}  /  "+("FINISH" if last==24 else f"MILESTONE {last}"),font=font(26),fill=(145,255,214))
    values=[(first-1,steps[first-1] if first>1 else dock)]+[(i,steps[i]) for i in range(first,last+1)]
    x0,x1=min(p["pos"][0]-p["size"][0]/2 for _,p in values),max(p["pos"][0]+p["size"][0]/2 for _,p in values)
    z0,z1=min(p["pos"][2]-p["size"][2]/2 for _,p in values),max(p["pos"][2]+p["size"][2]/2 for _,p in values)
    scale=min(500/(x1-x0),210/(z1-z0))
    def xy(x,z): return left+370+(x-(x0+x1)/2)*scale,top+188+(z-(z0+z1)/2)*scale
    points=[xy(p["pos"][0],p["pos"][2]) for _,p in values]
    draw.line(points,fill=(98,77,133),width=3)
    for i,p in values:
        x,_,z=p["pos"]; sx,_,sz=p["size"]
        color=(145,255,214) if i%6==0 else (201,173,255)
        a,b=xy(x-sx/2,z-sz/2),xy(x+sx/2,z+sz/2)
        draw.rounded_rectangle((*a,*b),4,fill=(69,76,105),outline=color,width=3)
        draw.text(xy(x,z),str(i) if i else "S",font=font(15),fill=(246,245,255),anchor="mm")
    height=steps[last]["pos"][1]+steps[last]["size"][1]/2
    draw.text((left+24,top+304),f"Top height: {height:g} studs  /  Miss a jump: real fall",font=font(19),fill=(185,177,216))
draw.text((800,956),"Native geometry diagram. Retry returns to the start plate. See deploy/studio-test-results.json.",font=font(21),fill=(185,177,216),anchor="mm")
image.save(root/"assets/parkour-preview.png")
print("Created native parkour-preview.png")
