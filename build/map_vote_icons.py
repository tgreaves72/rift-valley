"""Native map emblems above the physical vote plates, without boards or poles."""
import math


def create_map_icon(plate, map_id, position, tint, item, block, prop):
    model = item(plate, "Model", "MapVoteVisual")
    identity = item(model, "StringValue", "MapId")
    prop(identity, "string", "Value", map_id)
    core = block(model, "VoteCore", (.1, .1, .1), position, tint, 288, False, alpha=1)
    prop(model, "Ref", "PrimaryPart", core.attrib["referent"])
    light = item(core, "PointLight", "VoteGlow")
    for tag, key, value in (("Color3", "Color", tint), ("float", "Range", 14),
                            ("float", "Brightness", 1.5), ("bool", "Shadows", False)):
        prop(light, tag, key, value)

    def piece(name, size, offset, color=tint, yaw=0, roll=0, cls="Part", material=288):
        pos = tuple(a+b for a, b in zip(position, offset))
        part = block(model, name, size, pos, color, material, False, yaw=yaw, cls=cls)
        prop(part, "bool", "CastShadow", False)
        if roll:
            # All rolled pieces face forward; rotate about their local Z axis.
            c, s = math.cos(roll), math.sin(roll)
            frame = part.find("Properties/CoordinateFrame")
            for key, value in {"R00": c, "R01": -s, "R10": s, "R11": c}.items():
                frame.find(key).text = str(value)
        return part

    if map_id == "CrystalGrove":
        for x, z, width, height in ((0, 0, 1.45, 3.5), (-1.7, .35, 1.05, 2.3), (1.65, .45, 1, 2.7)):
            base_y = -1.4+height/2
            piece("GroveCrystal", (width, height, width), (x, base_y, z))
            for side in (-1, 1):
                piece("CrystalTip", (width, .9, width/2),
                      (x, base_y+height/2+.45, z+side*width/4),
                      yaw=0 if side < 0 else math.pi, cls="WedgePart")
            piece("CrystalFacet", (.22, height*.73, .12), (x-width*.25, base_y, z-width/2-.04), (224, 255, 246))
    elif map_id == "SunsetRuins":
        piece("TempleSteps", (5.5, .35, 2.2), (0, -1.9, 0), (230, 175, 95))
        piece("TempleBase", (4.9, .3, 1.8), (0, -1.55, 0))
        for x in (-1.75, 0, 1.75):
            piece("TempleColumn", (.65, 2.7, 1.15), (x, -.05, 0), (255, 219, 151))
        piece("TempleLintel", (5.2, .4, 1.65), (0, 1.5, 0))
        for side in (-1, 1):
            piece("TempleRoof", (1.9, 1.35, 2.7), (side*1.35, 2.35, 0),
                  yaw=-side*math.pi/2, cls="WedgePart")
    else:
        piece("AnchorShaft", (.6, 4.4, .85), (0, -.05, 0))
        piece("AnchorStock", (3.6, .48, .95), (0, .8, 0), (202, 191, 255))
        for side in (-1, 1):
            piece("AnchorArm", (2.3, .5, .85), (side*1.05, -1.65, 0), roll=side*.5)
            piece("AnchorFluke", (.5, 1.15, 1), (side*2, -1.05, 0), (214, 203, 255), roll=-side*.3)
        for index in range(10):
            angle = index*math.tau/10
            piece("AnchorRing", (.48, .35, .72), (math.cos(angle)*.65, 2.7+math.sin(angle)*.65, 0),
                  roll=angle+math.pi/2)
    for index in range(12):
        angle = index*math.pi/6
        piece("VoteOrbit", (.45, .14, .45), (math.cos(angle)*3.2, -2.45, math.sin(angle)*3.2))
    return model
