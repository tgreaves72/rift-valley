"""Stationary native destination sculptures, with small names instead of boards."""
import math
import xml.etree.ElementTree as ET


def create_destination(anchor, kind, position, item, block, prop):
    model = item(anchor, "Model", "DestinationVisual")
    mint, gold, pearl = (145, 255, 214), (255, 221, 137), (246, 245, 255)
    violet, ink = (201, 173, 255), (48, 35, 82)
    tint = mint if kind == "Shop" else gold

    def piece(name, size, offset, color=tint, roll=0, yaw=0, material=288, cls="Part"):
        part = block(model, name, size, tuple(a+b for a, b in zip(position, offset)),
                     color, material, False, yaw=yaw, cls=cls)
        prop(part, "bool", "CastShadow", False)
        if roll:
            c, s = math.cos(roll), math.sin(roll)
            frame = part.find("Properties/CoordinateFrame")
            for key, value in {"R00": c, "R01": -s, "R10": s, "R11": c}.items():
                frame.find(key).text = str(value)
        return part

    core = block(model, "DestinationCore", (.1, .1, .1), position, tint, 288, False, alpha=1)
    prop(core, "bool", "CastShadow", False)
    prop(model, "Ref", "PrimaryPart", core.attrib["referent"])
    glow = item(core, "PointLight", "DestinationGlow")
    for tag, key, value in (("Color3", "Color", tint), ("float", "Range", 18),
                            ("float", "Brightness", .7), ("bool", "Shadows", False)):
        prop(glow, tag, key, value)
    piece("DisplayPlinth", (10, .5, 7), (0, -6.1, 0), ink, material=816)
    for index in range(16):
        angle = index*math.tau/16
        piece("PlinthInlay", (1.1, .1, .2),
              (math.cos(angle)*4.2, -5.8, math.sin(angle)*2.8), (94, 59, 175), yaw=-angle-math.pi/2)

    if kind == "Shop":
        piece("BagBody", (4.7, 4.5, 2.1), (0, -.3, 0), (73, 117, 119), material=272)
        for side in (-1, 1):
            piece("BagSeam", (.2, 4.7, 2.3), (side*2.4, -.3, 0), (54, 185, 147))
        for y in (-2.6, 2):
            piece("BagRim", (4.9, .22, 2.3), (0, y, 0), (54, 185, 147))
        for z in (-.7, .7):
            for index in range(11):
                angle = index*math.pi/10
                piece("BagHandle", (.6, .25, .25),
                      (math.cos(angle)*1.3, 2+math.sin(angle)*1.5, z), gold, roll=angle+math.pi/2, material=1088)
        for face in (-1, 1):
            piece("BagRiftGem", (1.6, 1.6, .22), (0, -.25, face*1.18), pearl, roll=math.pi/4)
            piece("BagGemInset", (.75, .75, .25), (0, -.25, face*1.32), gold, roll=math.pi/4)
        for x, y, roll in ((-3.8, 1.6, .4), (3.7, -.6, -.4), (3, 3.5, .2)):
            piece("StyleShard", (.8, 1.5, .8), (x, y, .3), violet, roll=roll, cls="WedgePart", material=272)
        tag_height, title = 5.1, "Shop"
    else:
        for index in range(24):
            angle = index*math.tau/24
            piece("PortalArc", (1.35, .27, .7),
                  (math.cos(angle)*4.5, math.sin(angle)*5.3-.2, .2), (117, 75, 210),
                  roll=math.atan2(5.3*math.cos(angle), -4.5*math.sin(angle)))
        piece("CrownBand", (5.6, .75, 1.5), (0, -.8, -.2), (213, 151, 47), material=272)
        for x, height in ((-2, 2.2), (0, 3.4), (2, 2.2)):
            for side in (-1, 1):
                piece("CrownPoint", (1.45, height, .8), (x+side*.4, -.4+height/2, -.2),
                      (213, 151, 47), yaw=-side*math.pi/2, cls="WedgePart", material=272)
            piece("CrownJewel", (.6, .6, .35), (x, -.8, -1.02), mint if x == 0 else pearl, roll=math.pi/4)
        for side in (-1, 1):
            piece("PortalFoot", (1.5, 1.2, 2), (side*3, -5.3, .2), gold, material=1088)
            piece("PortalSpark", (.55, .55, .55), (side*5.4, 2, .2), pearl, roll=math.pi/4)
        tag_height, title = 6.9, "VIP Lounge"

    nameplate = item(anchor, "BillboardGui", "DestinationName")
    prop(nameplate, "Ref", "Adornee", core.attrib["referent"])
    prop(nameplate, "UDim2", "Size", (0, 168, 0, 26))
    prop(nameplate, "Vector3", "StudsOffset", (0, tag_height, 0))
    prop(nameplate, "float", "MaxDistance", 80)
    prop(nameplate, "float", "LightInfluence", 0)
    prop(nameplate, "bool", "AlwaysOnTop", False)
    label = item(nameplate, "TextLabel", "Title")
    for tag, key, value in (("UDim2", "Size", (1, 0, 1, 0)), ("float", "BackgroundTransparency", 1),
                            ("string", "Text", title), ("Color3", "TextColor3", tint),
                            ("float", "TextSize", 16), ("float", "TextStrokeTransparency", .35)):
        prop(label, tag, key, value)
    font = ET.SubElement(label.find("Properties"), "Font", name="FontFace")
    ET.SubElement(ET.SubElement(font, "Family"), "url").text = "rbxasset://fonts/families/FredokaOne.json"
    ET.SubElement(font, "Weight").text = "400"
    ET.SubElement(font, "Style").text = "Normal"
    return model
