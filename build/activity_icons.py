"""Solid, stationary activity emblems and small overhead names."""
import math
import xml.etree.ElementTree as ET


def small_tag(parent, anchor, title, offset, tint, item, prop):
    tag = item(parent, "BillboardGui", "NameTag")
    prop(tag, "Ref", "Adornee", anchor.attrib["referent"])
    for tag_type, key, value in (("UDim2", "Size", (0, 168, 0, 26)), ("Vector3", "StudsOffset", offset),
                                  ("float", "MaxDistance", 65), ("float", "LightInfluence", 0)):
        prop(tag, tag_type, key, value)
    label = item(tag, "TextLabel", "Title")
    for tag_type, key, value in (("UDim2", "Size", (1, 0, 1, 0)), ("float", "BackgroundTransparency", 1),
                                  ("string", "Text", title), ("Color3", "TextColor3", tint),
                                  ("float", "TextSize", 16), ("float", "TextStrokeTransparency", .35)):
        prop(label, tag_type, key, value)
    font = ET.SubElement(label.find("Properties"), "Font", name="FontFace")
    ET.SubElement(ET.SubElement(font, "Family"), "url").text = "rbxasset://fonts/families/FredokaOne.json"
    ET.SubElement(font, "Weight").text = "400"
    ET.SubElement(font, "Style").text = "Normal"
    return tag


def activity_icon(parent, position, kind, item, block, prop):
    model = item(parent, "Model", "ActivityVisual")
    tint = (255, 205, 87) if kind == "Mastery" else (79, 213, 174)
    core = block(model, "ActivityCore", (.1, .1, .1), position, tint, 288, False, alpha=1)
    prop(core, "bool", "CastShadow", False)
    prop(model, "Ref", "PrimaryPart", core.attrib["referent"])
    light = item(core, "PointLight", "ActivityGlow")
    for tag, key, value in (("Color3", "Color", tint), ("float", "Brightness", .65),
                            ("float", "Range", 14), ("bool", "Shadows", False)):
        prop(light, tag, key, value)

    def piece(name, size, offset, rgb=tint, roll=0, yaw=0, material=288, cls="Part"):
        part = block(model, name, size, tuple(a+b for a, b in zip(position, offset)),
                     rgb, material, False, yaw=yaw, cls=cls)
        prop(part, "bool", "CastShadow", False)
        if roll:
            c, s = math.cos(roll), math.sin(roll)
            frame = part.find("Properties/CoordinateFrame")
            for key, value in {"R00": c, "R01": -s, "R10": s, "R11": c}.items():
                frame.find(key).text = str(value)
        return part

    if kind == "Mastery":
        piece("TrophyFoot", (3.8, .45, 2.4), (0, -2.1, 0), (97, 66, 171), material=272)
        piece("TrophyStem", (.6, 1.3, .6), (0, -1.25, 0), (218, 157, 45), material=1088)
        piece("TrophyCup", (2.8, 1.8, 1.8), (0, .1, 0), (218, 157, 45), material=272)
        piece("TrophyRim", (3.2, .25, 2.1), (0, 1.1, 0))
        for side in (-1, 1):
            for index in range(8):
                angle = index*math.tau/8
                piece("TrophyHandle", (.6, .23, .4),
                      (side*1.6+math.cos(angle)*.8, .25+math.sin(angle)*.9, 0), roll=angle+math.pi/2)
        piece("MasteryGem", (1.2, 1.2, .25), (0, .15, -1.05), (145, 255, 214), roll=math.pi/4)
        piece("TrophySpark", (.8, .8, .8), (0, 2.2, 0), (163, 105, 240), roll=math.pi/4)
        height = 3.5
    else:
        for index in range(20):
            angle = index*math.tau/20
            piece("ClockRim", (.65, .25, .6),
                  (math.cos(angle)*1.9, math.sin(angle)*1.9, 0), roll=angle+math.pi/2)
        piece("ClockHub", (.35, .35, .65), (0, 0, -.12), (246, 245, 255))
        piece("ClockHand", (.2, 1.35, .3), (0, .55, -.25), (246, 245, 255))
        piece("ClockHand", (1.05, .2, .3), (.4, 0, -.25), (246, 245, 255))
        piece("ClockCrown", (.9, .4, .7), (0, 2.4, 0), (231, 184, 89), material=1088)
        height = 3.4
    tag = item(parent, "BillboardGui", "ActivityName")
    prop(tag, "Ref", "Adornee", core.attrib["referent"])
    for tag_type, key, value in (("UDim2", "Size", (0, 168, 0, 26)),
                                  ("Vector3", "StudsOffset", (0, height, 0)),
                                  ("float", "MaxDistance", 80), ("float", "LightInfluence", 0),
                                  ("bool", "AlwaysOnTop", False)):
        prop(tag, tag_type, key, value)
    label = item(tag, "TextLabel", "Title")
    for tag_type, key, value in (("UDim2", "Size", (1, 0, 1, 0)), ("float", "BackgroundTransparency", 1),
                                  ("string", "Text", kind), ("Color3", "TextColor3", tint),
                                  ("float", "TextSize", 16), ("float", "TextStrokeTransparency", .35)):
        prop(label, tag_type, key, value)
    font = ET.SubElement(label.find("Properties"), "Font", name="FontFace")
    ET.SubElement(ET.SubElement(font, "Family"), "url").text = "rbxasset://fonts/families/FredokaOne.json"
    ET.SubElement(font, "Weight").text = "400"
    ET.SubElement(font, "Style").text = "Normal"
    return model


def vip_activity(lobby, item, block, prop):
    arena = item(lobby, "Model", "VIPActivity")
    dark, gold, violet = (42, 36, 67), (196, 143, 53), (119, 71, 204)
    block(arena, "ActivityFloor", (72, 5, 60), (182, 25.5, 224), dark, 816)
    block(arena, "ActivityConnector", (24, 5, 16), (136, 25.5, 224), dark, 816)
    for side in (-1, 1):
        block(arena, "ActivityRail", (74, 3, 1), (182, 29.5, 224+side*29), dark, 1088)
        block(arena, "ActivityEdge", (74, .2, 1.2), (182, 31.1, 224+side*29), violet, 288, False)
        block(arena, "BridgeRail", (22, 3, 1), (136, 29.5, 224+side*8.5), dark, 1088)
        for z in (203, 245):
            block(arena, "ActivityPillar", (2, 14, 2), (182+side*30, 35, z), dark, 1088)
            block(arena, "ActivityPillarGlow", (.3, 12, 2.2), (182+side*30, 35, z), violet, 288, False)
    block(arena, "ActivityRail", (1, 3, 60), (217, 29.5, 224), dark, 1088)
    for x, z, angle in ((166, 210, .3), (180, 239, -.3), (200, 224, 0)):
        block(arena, "SparringCover", (5, 5, 9), (x, 30.5, z), (76, 66, 97), 816, yaw=angle)
        block(arena, "CoverAccent", (5.1, .15, 9.1), (x, 33.1, z), gold, 288, False, yaw=angle)
    for x in (155, 177, 199):
        block(arena, "ActivityInlay", (17, .05, .2), (x, 28.05, 224), violet, 288, False)
    tag_anchor = block(arena, "ActivityLabel", (.1, .1, .1), (142, 38, 224), violet, 288, False, alpha=1)
    small_tag(tag_anchor, tag_anchor, "VIP Arena", (0, 0, 0), (255, 221, 137), item, prop)
    return arena


def gear_displays(vip, item, block, prop):
    for index, (kind, title, tint) in enumerate((("Speed", "Speed Coil", (63, 197, 151)),
                                                ("Jump", "Jump Coil", (130, 81, 218)),
                                                ("Blaster", "Rift Blaster", (68, 174, 215)))):
        x, z = 87+index*14, 235
        model = item(vip, "Model", "GearDisplay_"+kind)
        core = block(model, "GearCore", (.1, .1, .1), (x, 33, z), tint, 288, False, alpha=1)
        prop(model, "Ref", "PrimaryPart", core.attrib["referent"])
        block(model, "GearPlinth", (5, .6, 4), (x, 28.4, z), (48, 35, 82), 816, False)
        block(model, "GearPlinthGlow", (4.7, .12, 3.7), (x, 28.8, z), tint, 288, False)
        if kind != "Blaster":
            for turn in range(3):
                for segment in range(12):
                    angle = segment*math.tau/12
                    block(model, "CoilTurn", (.8, .22, .22),
                          (x+math.cos(angle)*1.4, 31.4+turn*.8+segment*.8/12, z+math.sin(angle)*1.4),
                          tint, 288, False, yaw=-angle-math.pi/2)
        else:
            block(model, "BlasterBody", (1.6, 1.4, 3), (x, 32, z), (62, 49, 91), 272, False)
            block(model, "BlasterGrip", (.9, 2.4, 1), (x, 30.7, z+.6), (83, 71, 114), 1088, False)
            block(model, "BlasterBarrel", (.8, .8, 2.8), (x, 32.2, z-2.4), tint, 288, False)
            block(model, "BlasterSight", (.4, .35, 1.2), (x, 33, z-.2), (255, 221, 137), 288, False)
        small_tag(model, core, title, (0, 3, 0), (255, 221, 137), item, prop)
