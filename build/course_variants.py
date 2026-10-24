"""Native interactive routes. All themes preserve a continuous introductory floor."""
from map_details import decorate
from coin_models import create_coin
def create_mechanics(storage, arena, item, block, sign, prop):
    templates = item(storage, "Folder", "RiftMechanics")
    origins = ((0, 0), (230, 0), (-230, 0), (0, -430), (230, -430))
    for theme, tint in (("CrystalGrove", (108, 255, 204)), ("SunsetRuins", (255, 193, 101)), ("NeonHarbor", (161, 148, 255))):
        model = item(templates, "Model", theme)
        for stage, (ox, oz) in enumerate(origins, 1):
            section = item(model, "Model", str(stage))
            decorate(section, stage, ox, oz, theme, block, item, prop)
            if theme in ("CrystalGrove", "SunsetRuins"):
                name = "GroveBridge" if theme == "CrystalGrove" else "CrumbleTile"
                if stage <= 3:
                    for side in (-1, 1):
                        for z in (-54, -30, -6, 18, 42, 66):
                            tile = block(section, name, (8, 1.2, 16), (ox+side*(26 if stage == 1 else 16), 1.4, oz+z), tint, 512 if theme == "CrystalGrove" else 816, preview=False)
                            if name == "CrumbleTile":
                                modifier = item(tile, "PathfindingModifier", "AvoidUnstable")
                                prop(modifier, "string", "Label", "Unstable")
                else:
                    for z in ((-66, 0, 66) if stage == 4 else (-52, 52)):
                        tile = block(section, name, (8, 1, 11), (ox, .5, oz+z), tint, 512 if theme == "CrystalGrove" else 816, preview=False)
                        if name == "CrumbleTile":
                            modifier = item(tile, "PathfindingModifier", "AvoidUnstable")
                            prop(modifier, "string", "Label", "Unstable")
            else:
                positions = ((-26, -30), (26, 30)) if stage == 1 else ((0, -70), (0, 64)) if stage == 5 else ((8, -30), (-8, 30)) if stage == 4 else ((0, -14), (0, 58))
                for x, z in positions:
                    block(section, "CargoGate", (8 if stage == 4 else 20, 2.6, 4), (ox+x, 1.3, oz+z), (89, 104, 141), 1088, preview=False)
            for x, z in (((-26, -6), (26, 42)) if stage == 1 else ((0, -66), (0, 66))):
                create_coin(section, "BonusCrystal", (ox+x, 4.4 if stage == 1 else 3.6, oz+z), item, block, prop, preview=False)
