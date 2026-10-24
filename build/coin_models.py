"""Golden native 3D coins on stationary server collection anchors."""
import math


def create_coin(parent, name, pos, item, block, prop, preview=True):
    gold, rim, face = (255, 200, 78), (255, 224, 132), (198, 125, 40)
    anchor = block(parent, name, (1, 1, 1), pos, gold, 288, False, alpha=1, preview=preview)
    model = item(anchor, "Model", "CoinVisual")
    core = block(model, "CoinCore", (.1, .1, .1), pos, gold, 288, False, alpha=1, preview=preview)
    prop(model, "Ref", "PrimaryPart", core.attrib["referent"])
    light = item(core, "PointLight", "CoinGlow")
    for tag, key, value in (("Color3", "Color", gold), ("float", "Range", 9),
                            ("float", "Brightness", 1.4), ("bool", "Shadows", False)):
        prop(light, tag, key, value)

    def piece(label, size, offset, color, cylinder=False, roll=0):
        part = block(model, label, size, tuple(a+b for a, b in zip(pos, offset)), color,
                     288 if label != "CoinFace" else 1088, False,
                     yaw=math.pi/2 if cylinder else 0, preview=preview)
        if cylinder:
            prop(part, "token", "shape", 2)
        if roll:
            c, s = math.cos(roll), math.sin(roll)
            frame = part.find("Properties/CoordinateFrame")
            for key, value in {"R00": c, "R01": -s, "R10": s, "R11": c}.items():
                frame.find(key).text = str(value)
        prop(part, "bool", "CastShadow", False)

    piece("CoinEdge", (.5, 3.2, 3.2), (0, 0, 0), gold, cylinder=True)
    for side in (-1, 1):
        piece("CoinRim", (.12, 3.35, 3.35), (0, 0, side*.29), rim, cylinder=True)
        piece("CoinFace", (.1, 2.8, 2.8), (0, 0, side*.38), face, cylinder=True)
        for x, y, angle in ((-.33, .33, math.pi/4), (.33, .33, -math.pi/4),
                            (-.33, -.33, -math.pi/4), (.33, -.33, math.pi/4)):
            piece("CoinRune", (.93, .18, .14), (x, y, side*.48), rim, roll=angle)
    return anchor
