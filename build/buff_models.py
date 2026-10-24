"""Native, noncolliding 3D resource symbols, visible even in Studio edit mode."""
import math


def create_resource(parent, name, pos, kind, item, block, prop):
    tint = (108, 255, 190) if kind == "Stamina" else (105, 221, 255)
    anchor = block(parent, name, (1, 1, 1), pos, tint, 288, False, alpha=1)
    marker = item(anchor, "Folder", "HoverIcon")
    for key, value in (("Glyph", ""), ("Title", kind), ("Kind", kind)):
        prop(item(marker, "StringValue", key), "string", "Value", value)
    prop(item(marker, "Color3Value", "Tint"), "Color3", "Value", tint)
    visual = item(anchor, "Model", "BuffVisual")
    core = block(visual, "BuffCore", (.1, .1, .1), pos, tint, 288, False, alpha=1)
    prop(visual, "Ref", "PrimaryPart", core.attrib["referent"])
    light = item(core, "PointLight", "BuffGlow")
    prop(light, "Color3", "Color", tint)
    prop(light, "float", "Range", 12)
    prop(light, "float", "Brightness", 1.5)
    prop(light, "bool", "Shadows", False)

    def piece(label, size, offset, color=tint, angle=0, material=288):
        xyz = tuple(a+b for a, b in zip(pos, offset))
        part = block(visual, label, size, xyz, color, material, False)
        if angle:
            c, s = math.cos(angle), math.sin(angle)
            cf = part.find("Properties/CoordinateFrame")
            for key, value in {"R00": c, "R01": -s, "R10": s, "R11": c}.items():
                cf.find(key).text = str(value)
        prop(part, "bool", "CastShadow", False)
        return part

    if kind == "Stamina":
        piece("BatteryBody", (3.3, 1.9, .8), (0, .2, 0), (38, 64, 68), material=1088)
        piece("BatteryTerminal", (.5, .8, .65), (1.85, .2, 0))
        for side in (-1, 1):
            piece("BatteryRim", (3.4, .18, 1), (0, .2+side*.94, 0))
            piece("BatteryRim", (.18, 1.9, 1), (side*1.65, .2, 0))
            for index in (-1, 0, 1):
                piece("EnergyCell", (.66, 1.12, .18), (index*.93, .2, side*.48))
    else:
        for index in (0, 1):
            x = -.6+index*1.45
            for side in (-1, 1):
                piece("DashChevron", (1.8, .38, .65), (x, .2+side*.53, 0), angle=-side*math.pi/4)
        for index in range(3):
            piece("WindStreak", (1.15-index*.15, .18, .4), (-2.2+index*.1, 1-index*.75, 0))
    for index in range(12):
        angle = index*math.pi/6
        piece("BuffOrbit", (.35, .12, .35), (math.cos(angle)*2.1, -1.55, math.sin(angle)*2.1))
    return anchor
