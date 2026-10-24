"""Hand-built biome landmarks and surface detail, with clear gameplay lanes."""
import math


def decorate(section, stage, ox, oz, theme, block, item, prop):
    outer = 65 if stage == 1 else 35
    mint, amber, cyan = (108, 255, 190), (255, 194, 120), (120, 218, 255)

    def part(name, size, pos, color, material=816, **kwargs):
        return block(section, name, size, (ox+pos[0], pos[1], oz+pos[2]), color, material, False, preview=False, **kwargs)

    for side in (-1, 1):
        for index, z in enumerate((-96, 0, 96)):
            x = side*outer
            if theme == "CrystalGrove":
                part("GroveRootBase", (10, 2, 13), (x, 0, z), (48, 77, 72), 800, yaw=.3*side)
                part("GroveBark", (2.4, 16, 3), (x, 7, z), (78, 66, 76), 512)
                for dx, y in ((-2, 15), (2, 19)):
                    part("GroveLeafCloud", (10, 5, 11), (x+dx, y, z), (63+index*9, 121, 107+index*8), 1280, yaw=.4*side)
                part("GroveCrystalTip", (2, 6, 2), (x, 22, z), mint, 288, cls="WedgePart")
                for dz in (-4, 4):
                    part("GroveMushroomStem", (.7, 2.2, .7), (x-side*3, 1, z+dz), (178, 192, 178), 272)
                    part("GroveMushroomCap", (3.2, .7, 3.2), (x-side*3, 2.3, z+dz), (176, 143, 232), 288)
            elif theme == "SunsetRuins":
                part("RuinsFooting", (9, 1.4, 10), (x, .3, z), (135, 100, 82))
                for level in range(3):
                    part("RuinsCarvedColumn", (3.4, 4, 3.6), (x, 3+level*4, z), (193-level*9, 155-level*7, 113), yaw=level*.07)
                    part("RuinsColumnBand", (3.7, .3, 3.9), (x, 5+level*4, z), (222, 182, 126))
                part("RuinsCapital", (7, 1.2, 6), (x, 15, z), (205, 170, 125))
                part("RuinsTornBanner", (3.2, 7, .18), (x-side*2, 10, z-2), (148, 75, 101), 272)
                part("RuinsRune", (.3, 3, .2), (x-side*2, 10, z-2.12), amber, 288)
            else:
                part("HarborQuay", (11, 2, 14), (x, 0, z), (46, 58, 83), 1088)
                part("HarborFloodMast", (1.4, 19, 1.4), (x, 9, z), (58, 75, 103), 1088)
                part("HarborLampHead", (5, 1, 2.4), (x-side, 19, z), cyan, 288)
                part("HarborCrate", (6, 5, 8), (x+side*2, 3.5, z+5), (88, 112, 145), 1088)
                for dx in (-2, 2):
                    part("HarborCrateRib", (.3, 4.6, 8.1), (x+side*2+dx, 3.5, z+5), cyan, 288)
                part("HarborCraneArm", (12, 1, 1), (x-side*3, 16, z), (68, 81, 106), 1088)
                part("HarborHangingCable", (.12, 7, .12), (x-side*8, 12.5, z), (115, 145, 179), 1088)
            if index == 1:
                lamp = part("BiomeLantern", (1, 1.5, 1), (x-side*3, 6, z-4), mint if theme == "CrystalGrove" else amber if theme == "SunsetRuins" else cyan, 288)
                light = item(lamp, "PointLight", "BiomeGlow")
                prop(light, "Color3", "Color", mint if theme == "CrystalGrove" else amber if theme == "SunsetRuins" else cyan)
                prop(light, "float", "Range", 18)
                prop(light, "float", "Brightness", .8)
                prop(light, "bool", "Shadows", False)
    if stage > 1:
        # Overhead architecture creates a different silhouette for every theme.
        for z in (-64, 64):
            part("GroveCanopyVine" if theme == "CrystalGrove" else "RuinsBrokenLintel" if theme == "SunsetRuins" else "HarborOverheadGantry",
                 (62, 1.3, 2.4), (0, 19 if theme == "CrystalGrove" else 16, z),
                 (75, 112, 99) if theme == "CrystalGrove" else (174, 133, 99) if theme == "SunsetRuins" else (65, 80, 117),
                 512 if theme == "CrystalGrove" else 816 if theme == "SunsetRuins" else 1088)
        if stage in (2, 3, 5):
            if theme == "SunsetRuins":
                for side in (-1, 1):
                    block(section, "ThemeObstacle", (4, 3.4, 5), (ox+side*18, 1.7, oz-108), (161, 124, 91), 816, True, preview=False)
            elif theme == "CrystalGrove":
                block(section, "ThemeObstacle", (14, 2.2, 3), (ox+18, 1.1, oz-108), (69, 96, 79), 512, True, yaw=.2, preview=False)

    # Detail the surface the player actually crosses. These thin inserts never
    # cover a void cut or change movement/collision.
    for z in (-100, -36, 36, 100):
        xs = (-58, 58) if stage == 1 else (-24, 24)
        if stage == 4:
            xs = (-12,) if z < -66 or 0 < z < 66 else (12,)
        for x in xs:
            if theme == "CrystalGrove":
                part("GroveMossInlay", (4.5, .06, 8), (x, .045, z), (61, 124, 99), 1280, yaw=.12)
                part("GroveGrassSprout", (.45, .8, .45), (x+1, .45, z+2), (110, 178, 125), 1280, cls="WedgePart")
            elif theme == "SunsetRuins":
                part("RuinsEngravedTile", (4.8, .06, 8), (x, .045, z), (184, 148, 109))
                part("RuinsTileCrack", (.12, .08, 5), (x, .09, z), (100, 78, 76), yaw=.3)
            else:
                part("HarborDeckGrate", (4.8, .06, 8), (x, .045, z), (45, 63, 90), 1088)
                part("HarborSafetyStripe", (.25, .08, 6), (x, .09, z), (193, 163, 109), 288, yaw=.3)
