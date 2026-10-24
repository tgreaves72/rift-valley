"""Build a native Roblox XML place and original artwork from the same arena geometry."""
from pathlib import Path
import json
import math
import random
import copy
import xml.etree.ElementTree as ET
from buff_models import create_resource
from map_vote_icons import create_map_icon
from lobby_icons import create_destination
from activity_icons import activity_icon, vip_activity, gear_displays
from launch_world import launch_world
from coin_models import create_coin
from chase_layouts import create_courses
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
ASSETS = ROOT / "assets"
DIST.mkdir(exist_ok=True)
ASSETS.mkdir(exist_ok=True)
tree = ET.Element("roblox", version="4")
ET.SubElement(tree, "External").text = "null"
ET.SubElement(tree, "External").text = "nil"
counter = 0
geometry = []


def prop(item, tag, name, value):
    p = ET.SubElement(item.find("Properties"), tag, name=name)
    if tag == "Vector3":
        for k, v in zip(("X", "Y", "Z"), value):
            ET.SubElement(p, k).text = str(v)
    elif tag == "Color3":
        for k, v in zip(("R", "G", "B"), value):
            ET.SubElement(p, k).text = str(v / 255)
    elif tag == "CoordinateFrame":
        position, yaw = value
        c, s = math.cos(yaw), math.sin(yaw)
        values = list(position) + [c, 0, s, 0, 1, 0, -s, 0, c]
        for k, v in zip(("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"), values):
            ET.SubElement(p, k).text = str(v)
    elif tag == "UDim2":
        for k, v in zip(("XS", "XO", "YS", "YO"), value):
            ET.SubElement(p, k).text = str(v)
    elif tag == "bool":
        p.text = "true" if value else "false"
    else:
        p.text = str(value)
    return p


def item(parent, cls, name):
    global counter
    counter += 1
    obj = ET.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{counter:06d}"})
    ET.SubElement(obj, "Properties")
    prop(obj, "string", "Name", name)
    return obj


def block(parent, name, size, pos, rgb, material=800, collide=True, yaw=0, cls="Part", alpha=0, preview=True):
    obj = item(parent, cls, name)
    prop(obj, "Vector3", "size", size)
    prop(obj, "CoordinateFrame", "CFrame", (pos, yaw))
    prop(obj, "Color3", "Color", rgb)
    prop(obj, "token", "Material", material)
    for name_, value in (("Anchored", True), ("CanCollide", collide), ("CanTouch", collide), ("CanQuery", collide)):
        prop(obj, "bool", name_, value)
    prop(obj, "float", "Transparency", alpha)
    prop(obj, "token", "TopSurface", 0)
    prop(obj, "token", "BottomSurface", 0)
    if preview and alpha < 0.6:
        geometry.append({"name": name, "size": size, "pos": pos, "color": rgb, "yaw": yaw})
    return obj


def clone_native(source):
    global counter
    clone = copy.deepcopy(source)
    references = {}
    for obj in clone.iter("Item"):
        counter += 1
        references[obj.attrib["referent"]] = f"RBX{counter:06d}"
        obj.set("referent", f"RBX{counter:06d}")
    for ref in clone.iter("Ref"):
        if ref.text in references:
            ref.text = references[ref.text]
    return clone


def sign(parent, text, pos, size=(38, 8, 1), color=(106, 255, 205), yaw=0, preview=True):
    board = block(parent, "Sign", size, pos, (18, 30, 36), 272, False, yaw, preview=preview)
    surface = item(board, "SurfaceGui", "Lettering")
    prop(surface, "token", "Face", 5)
    prop(surface, "token", "SizingMode", 1)
    prop(surface, "float", "PixelsPerStud", 35)
    prop(surface, "float", "LightInfluence", 0)
    text_obj = item(surface, "TextLabel", "Text")
    prop(text_obj, "UDim2", "Size", (1, -12, 1, -8))
    prop(text_obj, "UDim2", "Position", (0, 6, 0, 4))
    prop(text_obj, "float", "BackgroundTransparency", 1)
    prop(text_obj, "string", "Text", text)
    prop(text_obj, "Color3", "TextColor3", color)
    prop(text_obj, "bool", "TextScaled", True)
    prop(text_obj, "bool", "TextWrapped", True)
    prop(text_obj, "token", "Font", 19)
    return board


workspace = item(tree, "Workspace", "Workspace")
prop(workspace, "float", "Gravity", 196.2)
prop(workspace, "bool", "StreamingEnabled", False)
prop(workspace, "float", "FallenPartsDestroyHeight", -1600)
arena = item(workspace, "Model", "RiftArena")
palette = {"stone": (92, 111, 108), "edge": (55, 73, 82), "mint": (108, 255, 204), "violet": (183, 122, 255), "amber": (255, 194, 102)}

# Four unobstructed lanes with cover between them. All gameplay geometry exists in edit mode.
block(arena, "ArenaFloor", (156, 4, 244), (0, -2, 0), palette["stone"], 816)
for side in (-1, 1):
    block(arena, "SafeDeck", (156, 4, 48), (0, -2, side * 146), (82, 115, 108), 816)
    block(arena, "FinishLine", (156, 0.15, 1.2), (0, 0.09, side * 122), palette["mint"], 288, False)
    block(arena, "BackWall", (164, 24, 5), (0, 10, side * 173), palette["edge"])
    for x in (-70, 70):
        block(arena, "GatePillar", (5, 27, 5), (x, 13.5, side * 149), palette["edge"])
        block(arena, "GateLight", (1.5, 24, 5.3), (x, 13, side * 149), palette["mint"], 288, False)
    block(arena, "GateBeam", (145, 4, 5), (0, 27, side * 149), palette["edge"])
    block(arena, "GateBeamLight", (135, 0.7, 5.3), (0, 26, side * 149), palette["mint"], 288, False)

for side in (-1, 1):
    block(arena, "SideWall", (5, 17, 344), (side * 80.5, 6.5, 0), palette["edge"])
    block(arena, "SideAccent", (0.4, 0.7, 326), (side * 77.8, 2, 0), palette["violet"], 288, False)
    for z in range(-150, 151, 30):
        block(arena, "Buttress", (9, 23, 7), (side * 82, 9.5, z), (37, 56, 61))
        lamp = block(arena, "AmberLamp", (1, 5, 2), (side * 77.7, 8, z), palette["amber"], 288, False)
        light = item(lamp, "PointLight", "WarmLight")
        prop(light, "Color3", "Color", palette["amber"])
        prop(light, "float", "Brightness", 0.65)
        prop(light, "float", "Range", 22)

for x in (-52, -26, 0, 26, 52):
    for z in range(-108, 109, 18):
        block(arena, "LaneMark", (0.18, 0.06, 8), (x, 0.04, z), (98, 120, 118), 272, False)
# Four distinct onward courses share safe entry/exit decks.
course_geometry_start = len(geometry)
chase_courses = create_courses(arena, item, block, sign, prop, palette, create_resource)
(ASSETS / "chase-courses-geometry.json").write_text(json.dumps(geometry[course_geometry_start:], indent=2), encoding="utf-8")
# Keep existing artwork framed on the original valley.
del geometry[course_geometry_start:]
storage = item(tree, "ServerStorage", "ServerStorage")
templates = item(storage, "Folder", "RiftMaps")
map_definitions = (
    ("CrystalGrove", "CRYSTAL GROVE", (108, 255, 204), (65, 99, 88)),
    ("SunsetRuins", "SUNSET RUINS", (255, 193, 101), (156, 117, 88)),
    ("NeonHarbor", "NEON HARBOR", (161, 148, 255), (57, 76, 101)),
)

for map_index, (map_id, map_title, accent, stone) in enumerate(map_definitions):
    variant = item(templates, "Model", map_id)
    geometry_start = len(geometry)
    for x, z in ((-38, -60), (38, -60), (-38, 60), (38, 60), (-54, -20), (54, -20), (-54, 20), (54, 20)):
        cover = block(variant, "RouteCover", (9, 6, 14), (x, 3, z), stone, 816 if map_index < 2 else 1088)
        block(variant, "CoverTrim", (9.2, .3, 14.2), (x, 6.15, z), accent, 288, False)
        if map_index == 0:
            for offset in (-2, 2):
                block(variant, "GroveGem", (2.5, 5, 3), (x + offset, 8.6, z), accent, 288, False, cls="WedgePart")
        elif map_index == 1:
            for offset in (-3, 3):
                block(variant, "BrokenPillar", (2, 6, 2), (x + offset, 9, z), (197, 171, 127), 816)
            block(variant, "RuinsLintel", (9, 2, 3), (x, 13, z), (193, 155, 117), 816)
        else:
            for offset in (-3, 0, 3):
                block(variant, "CargoStripe", (.4, 4.5, 14.1), (x + offset, 3, z), accent, 288, False)
    # Large decorations stay beside the playing lanes. The middle crossing stays open.
    for side in (-1, 1):
        for z in (-100, -48, 48, 100):
            x = side * 69
            if map_index == 0:
                block(variant, "GroveTrunk", (3, 15, 3), (x, 7.5, z), (90, 73, 65), 512)
                block(variant, "GroveCrown", (12, 7, 12), (x, 18, z), (74, 160, 121), 1280, False, yaw=math.pi/4)
                block(variant, "GroveCrownLight", (6, 2, 6), (x, 23, z), accent, 288, False, yaw=math.pi/4)
                for dx in (-5, 5):
                    block(variant, "MushroomStem", (1.2, 2, 1.2), (x + dx, 1, z + 6), (197, 200, 178), 272, False)
                    block(variant, "MushroomCap", (4, 1.2, 4), (x + dx, 2.3, z + 6), (163, 123, 217), 272, False)
            elif map_index == 1:
                for dx in (-4, 4):
                    block(variant, "GardenColumn", (2.5, 14, 3), (x + dx, 7, z), (195, 166, 125), 816)
                block(variant, "GardenArch", (11, 3, 4), (x, 15, z), (214, 186, 142), 816)
                block(variant, "GardenBed", (12, 1, 8), (x, .5, z + 11), (110, 136, 83), 1280, False)
                for dx in (-4, 0, 4):
                    block(variant, "Bloom", (2, 2, 2), (x + dx, 2, z + 11), (255, 185, 146), 272, False, yaw=math.pi/4)
            else:
                block(variant, "HarborPost", (3, 17, 3), (x, 8.5, z), (51, 68, 88), 1088)
                block(variant, "NeonSail", (9, 12, .5), (x, 12, z), accent, 288, False)
                block(variant, "CargoStack", (8, 5, 10), (side * 67, 2.5, z + 13), (104, 141, 167), 1088)
    for index, (x, z) in enumerate(((-55, -90), (55, -90), (-30, -36), (30, -36), (-30, 36), (30, 36), (-55, 90), (55, 90)), 1):
        block(variant, "PickupBase", (4, .2, 4), (x, .1, z), stone, 272, False, yaw=math.pi/4)
        create_coin(variant, f"Crystal_{index}", (x, 3.1, z), item, block, prop)
    for index, (x, z) in enumerate(((-20, -74), (20, -74), (-20, 74), (20, 74)), 1):
        kind, tint = ("Stamina", palette["mint"]) if index % 2 else ("Dash", (123, 224, 255))
        create_resource(variant, f"Recharge_{index}", (x, 3, z), kind, item, block, prop)
    if map_index == 0:
        preview_map = clone_native(variant)
        preview_map.find("Properties/string[@name='Name']").text = "ActiveMap"
        arena.append(preview_map)
    else:
        # Launch artwork illustrates Crystal Grove only, without overlaying other maps.
        del geometry[geometry_start:]

from course_variants import create_mechanics
create_mechanics(storage, arena, item, block, sign, prop)
mechanic_templates = next(obj for obj in storage.findall("Item") if obj.find("Properties/string[@name='Name']").text == "RiftMechanics")
preview_mechanics = clone_native(mechanic_templates.find("Item"))
preview_mechanics.find("Properties/string[@name='Name']").text = "ActiveMechanics"
arena.append(preview_mechanics)
lobby_y = 28
lobby_geometry_start = len(geometry)
lobby = item(workspace, "Model", "RiftLobby")
block(lobby, "LobbyFloor", (104, 5, 80), (0, lobby_y - 2.5, 232), (110, 127, 136), 816)
block(lobby, "PlazaConnector", (104, 5, 8), (0, lobby_y - 2.5, 274), (110, 127, 136), 816)
block(lobby, "PlazaFloor", (144, 5, 96), (0, lobby_y - 2.5, 324), (103, 123, 137), 816)
block(lobby, "PlazaFoundation", (148, 7, 100), (0, lobby_y - 8.5, 324), (47, 60, 80), 800)
for x in (-51, 51):
    segments = ((205, 26), (254, 36)) if x < 0 else ((232, 80),)
    for z, length in segments:
        block(lobby, "LobbyRail", (2, 4, length), (x, lobby_y + 2, z), palette["edge"])
        block(lobby, "LobbyRailLight", (2.1, .22, length), (x, lobby_y + 4.1, z), palette["mint"], 288, False)
block(lobby, "ViewRail", (104, 3, 2), (0, lobby_y + 1.5, 193), palette["edge"])
block(lobby, "LobbyBack", (144, 5, 2), (0, lobby_y + 2.5, 373), palette["edge"])
sign(lobby, "RIFT VALLEY\nTHE RIFT GARDENS", (0, lobby_y + 13, 370), (58, 9, 1))

def prompt(part, action, object_text):
    obj = item(part, "ProximityPrompt", "Interact")
    prop(obj, "string", "ActionText", action)
    prop(obj, "string", "ObjectText", object_text)
    prop(obj, "float", "MaxActivationDistance", 12)
    prop(obj, "float", "HoldDuration", 0)
    prop(obj, "token", "Style", 1)
    prop(obj, "bool", "RequiresLineOfSight", False)
    prop(obj, "token", "KeyboardKeyCode", 101)
    return obj

def hovering(parent, name, pos, glyph, title, accent, action):
    anchor = block(parent, name, (1, 1, 1), pos, accent, 288, False, alpha=1)
    marker = item(anchor, "Folder", "HoverIcon")
    for key, value in (("Glyph", glyph), ("Title", title)):
        node = item(marker, "StringValue", key)
        prop(node, "string", "Value", value)
    node = item(marker, "Color3Value", "Tint")
    prop(node, "Color3", "Value", accent)
    prompt(anchor, action, title)
    return anchor

def pressure_plate(parent, name, x, z, accent, width=15, depth=10):
    pad = block(parent, name, (width, .4, depth), (x, lobby_y+.2, z), accent, 288)
    item(pad, "Folder", "PressurePlate")
    for side in (-1, 1):
        block(parent, "PlateTrim", (.3, .14, depth+.6), (x+side*(width/2+.2), lobby_y+.1, z), (225, 235, 244), 288, False)
        block(parent, "PlateFootprint", (1.1, .06, 2.7), (x+side*1.2, lobby_y+.43, z), (240, 245, 238), 288, False)
    return pad

for x, (map_id, map_title, accent, _) in zip((-24, 0, 24), map_definitions):
    pad = pressure_plate(lobby, "Vote_" + map_id, x, 244, accent)
    emblem = create_map_icon(pad, map_id, (x, lobby_y+8.5, 244), accent, item, block, prop)
    nameplate = item(pad, "BillboardGui", "MapName")
    prop(nameplate, "Ref", "Adornee", emblem.find("Properties/Ref[@name='PrimaryPart']").text)
    prop(nameplate, "UDim2", "Size", (0, 168, 0, 26))
    prop(nameplate, "Vector3", "StudsOffset", (0, 4.6, 0))
    prop(nameplate, "float", "MaxDistance", 80)
    prop(nameplate, "float", "LightInfluence", 0)
    prop(nameplate, "bool", "AlwaysOnTop", False)
    title = item(nameplate, "TextLabel", "Title")
    prop(title, "UDim2", "Size", (1, 0, 1, 0))
    prop(title, "float", "BackgroundTransparency", 1)
    prop(title, "string", "Text", map_title.title())
    prop(title, "Color3", "TextColor3", accent)
    prop(title, "float", "TextSize", 16)
    font_face = ET.SubElement(title.find("Properties"), "Font", name="FontFace")
    ET.SubElement(ET.SubElement(font_face, "Family"), "url").text = "rbxasset://fonts/families/FredokaOne.json"
    ET.SubElement(font_face, "Weight").text = "400"
    ET.SubElement(font_face, "Style").text = "Normal"
    prop(title, "float", "TextStrokeTransparency", .35)
vendor = hovering(lobby, "PassVendor", (-33, lobby_y + 4.5, 227), "$", "VALLEY OUTFITTERS", palette["amber"], "Browse game passes")
portal = hovering(lobby, "VIPPortal", (33, lobby_y + 4.5, 232), "♛", "VIP SKY LOUNGE", palette["amber"], "Enter lounge")
destination_geometry_start = len(geometry)
for anchor, kind, position in ((vendor, "Shop", (-33, lobby_y+6.5, 227)),
                               (portal, "VIP", (33, lobby_y+6.5, 232))):
    marker = item(anchor.find("Item[@class='Folder']"), "BoolValue", "NativeVisual")
    prop(marker, "bool", "Value", True)
    create_destination(anchor, kind, position, item, block, prop)
(ASSETS / "lobby-destinations-geometry.json").write_text(json.dumps(geometry[destination_geometry_start:], indent=2), encoding="utf-8")

# Midnight velvet, champagne metalwork and an open chandelier canopy.
vip_geometry_start = len(geometry)
block(lobby, "LoungeFloor", (48, 5, 56), (101, lobby_y - 2.5, 224), (34, 38, 55), 816)
vip = item(lobby, "Model", "VIPInterior")
gold, velvet, midnight = (232, 199, 135), (103, 70, 133), (33, 34, 53)
for ix, x in enumerate((83, 92, 101, 110, 119)):
    for iz, z in enumerate((201, 210, 219, 228, 237, 246)):
        block(vip, "LoungeMarbleTile", (8.4, .12, 8.4), (x, lobby_y + .07, z), (47, 49, 68) if (ix+iz)%2 else (62, 62, 78), 816, False)
for x in (80, 122):
    block(vip, "ChampagneInlay", (.2, .15, 50), (x, lobby_y + .16, 224), gold, 1088, False)
for z in (199, 249):
    block(vip, "ChampagneInlay", (42, .15, .2), (101, lobby_y + .16, z), gold, 1088, False)
for x in (77, 125):
    for center, length in (((224, 56),) if x == 77 else ((206, 20), (242, 20))):
        block(vip, "LoungeRailBase", (1.5, 1.2, length), (x, lobby_y + .6, center), midnight, 1088)
        block(vip, "LoungeTintedRail", (.5, 3, length-1), (x, lobby_y + 2.5, center), (137, 164, 193), 272, False, alpha=.7)
        block(vip, "LoungeRailCrest", (1.8, .35, length), (x, lobby_y + 4.2, center), gold, 1088)
for z in (196, 252):
    block(vip, "LoungeRailBase", (48, 1.2, 1.5), (101, lobby_y + .6, z), midnight, 1088)
    block(vip, "LoungeRailCrest", (48, .35, 1.8), (101, lobby_y + 4.2, z), gold, 1088)
for x in (81, 121):
    for z in (200, 248):
        block(vip, "LoungeColumn", (1.6, 19, 1.6), (x, lobby_y + 9.5, z), midnight, 1088)
        block(vip, "ColumnAccent", (.3, 17, 1.8), (x-.9 if x < 101 else x+.9, lobby_y + 9, z), gold, 1088, False)
for z in (199, 249):
    block(vip, "CanopyBeam", (44, 1.8, 4), (101, lobby_y + 20, z), midnight, 1088)
for x in (80, 122):
    block(vip, "CanopyBeam", (3, 1.8, 50), (x, lobby_y + 20, 224), midnight, 1088)
block(vip, "ChandelierSupport", (42, .5, .5), (101, lobby_y + 20, 218), gold, 1088, False)
block(vip, "ChandelierChain", (.25, 4, .25), (101, lobby_y + 18, 218), gold, 1088, False)
for index in range(16):
    angle = index*math.tau/16
    block(vip, "ChandelierRing", (2, .25, .3), (101+math.cos(angle)*5, lobby_y + 16, 218+math.sin(angle)*5), gold, 1088, False, yaw=-angle-math.pi/2)
    block(vip, "ChandelierPendant", (.35, 1.6, .35), (101+math.cos(angle)*5, lobby_y + 14.9, 218+math.sin(angle)*5), palette["amber"], 288, False)
heart = block(vip, "ChandelierHeart", (2.5, 4, 2.5), (101, lobby_y + 14.5, 218), palette["violet"], 288, False, cls="WedgePart")
def vip_light(part, rgb, brightness=1.3, radius=24):
    light = item(part, "PointLight", "VIPGlow")
    prop(light, "Color3", "Color", rgb)
    prop(light, "float", "Brightness", brightness)
    prop(light, "float", "Range", radius)
    prop(light, "bool", "Shadows", False)
vip_light(heart, (222, 185, 255))
for side in (-1, 1):
    x = 101 + side*17
    sofa_shift = -8 if side == 1 else 0
    block(vip, "VelvetSofaBase", (6, 1.4, 18), (x, lobby_y + .7, 218+sofa_shift), midnight, 272)
    for z in (212, 218, 224):
        seat = block(vip, "VIPSeat", (5.2, .8, 4.8), (x, lobby_y + 1.8, z+sofa_shift), velvet, 272, yaw=side*math.pi/2, cls="Seat")
        prop(seat, "bool", "Disabled", False)
        block(vip, "SofaCushion", (1.2, 2, 3.8), (x+side*2.2, lobby_y + 3, z+sofa_shift), (151, 112, 173), 272, False)
    block(vip, "VelvetSofaBack", (1.2, 4, 19), (x+side*3, lobby_y + 2.7, 218+sofa_shift), midnight, 272)
    for z in (208, 228):
        block(vip, "ChampagneSofaArm", (6.5, .4, 1), (x, lobby_y + 3.2, z+sofa_shift), gold, 1088)
    for z in (203, 245):
        plant_x = x-6 if side == 1 and z == 203 else x
        block(vip, "VIPPlanter", (4, 2.2, 4), (plant_x, lobby_y + 1.1, z), midnight, 816)
        leaf = block(vip, "VIPCrystalPlant", (2, 5.5, 2), (plant_x, lobby_y + 4.7, z), palette["violet"] if z == 203 else gold, 288, False, cls="WedgePart")
        vip_light(leaf, (216, 181, 255) if z == 203 else gold, .8, 18)
block(vip, "LoungeRug", (23, .1, 25), (101, lobby_y + .18, 218), (65, 49, 87), 272, False)
block(vip, "LoungeTable", (9, 1, 8), (101, lobby_y + 2.3, 213), (76, 77, 94), 816)
block(vip, "LoungeTableStem", (2, 1.8, 2), (101, lobby_y + .9, 213), gold, 1088)
block(vip, "LoungeTableGem", (1.4, 2.6, 1.4), (101, lobby_y + 4.1, 213), palette["mint"], 288, False, cls="WedgePart")
block(vip, "ThroneDais", (10, .4, 8), (101, lobby_y + .25, 245), gold, 1088)
throne = block(vip, "VIPThrone", (5, .8, 4), (101, lobby_y + 2, 245), velvet, 272, cls="Seat")
prop(throne, "bool", "Disabled", False)
block(vip, "ThroneBack", (5, 8, 1), (101, lobby_y + 5, 247.5), midnight, 272)
for x in (97.7, 104.3):
    block(vip, "ThroneGoldArm", (.7, .4, 5), (x, lobby_y + 3.4, 245), gold, 1088)
for x, height in ((99, 1.5), (101, 2.5), (103, 1.5)):
    block(vip, "ThroneCrown", (1.2, height, .5), (x, lobby_y + 9 + height/2, 247.5), gold, 1088, False, cls="WedgePart")

# A style studio offers the same earned collection as the public shop.
block(vip, "StyleMirrorFrame", (11, 12, .8), (123, lobby_y + 7, 236), gold, 1088, yaw=math.pi/2)
mirror = block(vip, "StyleMirrorPanel", (9.5, 10.5, .4), (122.45, lobby_y + 7, 236), (142, 184, 224), 288, False, yaw=math.pi/2, alpha=.55)
vip_light(mirror, (151, 208, 255), 1, 16)
hovering(vip, "StyleMirror", (116, lobby_y + 4.5, 236), "◇", "STYLE STUDIO", palette["violet"], "Unlock and equip cosmetics")
block(vip, "CosmeticDisplay", (4, .5, 4), (112, lobby_y + .3, 245), midnight, 816)
for name, size, pos in (("DisplayTorso", (2, 2.4, 1), (112, lobby_y+3, 245)), ("DisplayHead", (1.6, 1.6, 1.6), (112, lobby_y+5, 245)), ("DisplayLeg", (.8, 1.6, .8), (111.5, lobby_y+1, 245)), ("DisplayLeg", (.8, 1.6, .8), (112.5, lobby_y+1, 245))):
    block(vip, name, size, pos, (189, 192, 207), 272, False)
for index in range(12):
    angle = index*math.tau/12
    block(vip, "RoyalHaloDisplay", (.6, .15, .2), (112+math.cos(angle)*1.2, lobby_y+6.2, 245+math.sin(angle)*1.2), gold, 288, False, yaw=-angle-math.pi/2)
exit_pad = hovering(vip, "LoungeExit", (101, lobby_y + 4.5, 201), "↩", "RETURN TO OVERLOOK", palette["mint"], "Return to lobby")
vip_lounge_geometry = list(geometry[vip_geometry_start:])

# Courtyard paving, luminous paths, a central crystal garden and covered benches.
decor = item(lobby, "Model", "OverlookGarden")
for x in range(-40, 41, 16):
    for z in (211, 227, 259):
        block(decor, "CourtyardTile", (14, .12, 14), (x, lobby_y + .08, z), (120, 139, 148), 816, False)
for x in (-15, 15):
    block(decor, "InlaidPath", (.25, .12, 62), (x, lobby_y + .15, 232), palette["mint"], 288, False)
block(decor, "CrystalGardenBasin", (15, 1, 8), (0, lobby_y + .5, 254), palette["edge"], 816)
for x, height, rgb in ((-4, 4, palette["violet"]), (0, 7, palette["mint"]), (4, 5, palette["violet"])):
    block(decor, "GardenCrystal", (2.8, height, 2.8), (x, lobby_y + 1 + height/2, 254), rgb, 288, False, yaw=math.pi/4, cls="WedgePart")
for x in (-43, 43):
    for z in (208, 255):
        block(decor, "GardenPlanter", (9, 3, 9), (x, lobby_y + 1.5, z), palette["edge"], 816)
        block(decor, "GardenTreeTrunk", (1.5, 10, 1.5), (x, lobby_y + 7, z), (83, 75, 86), 512)
        block(decor, "GardenTreeCanopy", (9, 5, 9), (x, lobby_y + 12, z), (118, 125, 169), 1280, False, yaw=math.pi/4)
        block(decor, "GardenTreeTip", (5, 2, 5), (x, lobby_y + 15, z), (157, 140, 188), 1280, False, yaw=math.pi/4)
for x in (-32, 32):
    block(decor, "GardenBench", (12, 2, 4), (x, lobby_y + 1, 260), (153, 131, 112), 512)
    block(decor, "BenchBack", (12, 3, 1), (x, lobby_y + 3, 262), palette["edge"], 512)
for x in (-19, 19):
    for z in (249, 266):
        block(decor, "PergolaPost", (1.4, 17, 1.4), (x, lobby_y + 8.5, z), palette["edge"], 1088)
for x in range(-18, 19, 6):
    block(decor, "PergolaSlat", (2, 1.3, 23), (x, lobby_y + 17, 258), (77, 87, 104), 512)
block(decor, "PergolaFrontBeam", (42, 1.5, 2), (0, lobby_y + 16, 247), palette["violet"], 288, False)

# A broad public garden behind the overlook, clear of the floating parkour wing.
# All decorations use native geometry; seats provide direct social interaction.
plaza = item(lobby, "Model", "RiftGardens")
for x in range(-60, 61, 20):
    for z in range(286, 367, 20):
        block(plaza, "PlazaPaving", (18, .1, 18), (x, lobby_y + .07, z), (115, 134, 147), 816, False)
for x in (-22, 22):
    block(plaza, "GardenPathInlay", (.28, .12, 88), (x, lobby_y + .15, 324), palette["mint"], 288, False)
for z in (284, 356):
    block(plaza, "GardenCrossPath", (130, .12, .28), (0, lobby_y + .15, z), palette["violet"], 288, False)
for side in (-1, 1):
    block(plaza, "PlazaRail", (2, 4, 96), (side*71, lobby_y + 2, 324), palette["edge"])
    block(plaza, "PlazaRailGlow", (2.1, .22, 96), (side*71, lobby_y + 4.1, 324), palette["violet"], 288, False)
    block(plaza, "PlazaShoulderRail", (18, 4, 2), (side*62, lobby_y + 2, 277), palette["edge"])

# Rift fountain: a segmented stone basin, shallow luminous water, floating shards.
fountain = item(plaza, "Model", "RiftFountain")
for index in range(20):
    angle = index*math.tau/20
    x, z = math.cos(angle)*13, 322 + math.sin(angle)*13
    block(fountain, "FountainRim", (4.4, 1.8, 2), (x, lobby_y + .9, z), (68, 87, 108), 816, yaw=-angle-math.pi/2)
for x in range(-10, 11, 2):
    depth = 2*math.sqrt(11*11-x*x)
    block(fountain, "RiftWater", (2, .22, depth), (x, lobby_y + .8, 322), (90, 203, 230), 288, False, alpha=.35)
block(fountain, "FountainPedestal", (6, 2.5, 6), (0, lobby_y + 1.25, 322), palette["edge"], 816, yaw=math.pi/4)
heart = block(fountain, "RiftHeart", (4.5, 12, 4.5), (0, lobby_y + 12, 322), palette["mint"], 288, False, yaw=math.pi/4, cls="WedgePart")
light = item(heart, "PointLight", "FountainGlow")
prop(light, "Color3", "Color", palette["mint"])
prop(light, "float", "Range", 26)
prop(light, "float", "Brightness", 1.4)
prop(light, "bool", "Shadows", False)
for index in range(6):
    angle = index*math.tau/6
    block(fountain, "FloatingShard", (2, 4, 2), (math.cos(angle)*6, lobby_y + 7 + index%2*2, 322 + math.sin(angle)*6), palette["violet"], 288, False, yaw=-angle, cls="WedgePart")
for x in (-5, 5):
    for z in (317, 327):
        block(fountain, "FountainJet", (.4, 4, .4), (x, lobby_y + 2.8, z), (148, 233, 255), 288, False, alpha=.35)

# Eight flowering trees and twelve usable seats around two garden courts.
for side in (-1, 1):
    for z in (290, 310, 344, 362):
        x = side*57
        block(plaza, "TreePlanter", (12, 2.5, 12), (x, lobby_y + 1.25, z), palette["edge"], 816)
        block(plaza, "PlanterMoss", (10, .3, 10), (x, lobby_y + 2.6, z), (69, 113, 100), 1280, False)
        block(plaza, "PlazaTreeTrunk", (1.8, 12, 1.8), (x, lobby_y + 8, z), (84, 68, 88), 512)
        for size, height, rgb in ((12, 15, (104, 112, 163)), (9, 18, (140, 125, 182)), (5, 21, (176, 144, 208))):
            block(plaza, "PlazaTreeCrown", (size, 4, size), (x, lobby_y + height, z), rgb, 1280, False, yaw=math.pi/4)
        for dx in (-4, 4):
            block(plaza, "PlanterBloom", (2, 1, 2), (x+dx, lobby_y + 3, z), (212, 150, 208), 272, False, yaw=math.pi/4)
    for z in (301, 352):
        for dz in (-4.5, 0, 4.5):
            seat = block(plaza, "PlazaSeat", (4, .7, 3.6), (side*44, lobby_y + 1.8, z+dz), (166, 140, 125), 512, yaw=side*math.pi/2, cls="Seat")
            prop(seat, "bool", "Disabled", False)
        block(plaza, "GardenSeatBack", (1, 3, 14), (side*46.2, lobby_y + 3, z), (68, 82, 102), 512)
        for dz in (-5, 5):
            block(plaza, "GardenSeatLeg", (3, 1.5, 1.4), (side*44, lobby_y + .75, z+dz), palette["edge"])
        block(plaza, "GardenTable", (5, 1, 9), (side*35, lobby_y + 2.5, z), (114, 129, 143), 816)
        block(plaza, "TableStem", (2, 2, 2), (side*35, lobby_y + 1, z), palette["edge"])
        block(plaza, "TableCrystal", (1.2, 2.2, 1.2), (side*35, lobby_y + 4.1, z), palette["amber"], 288, False, cls="WedgePart")
    # Recessed flower beds and obelisks frame the clear walking routes.
    for z in (326, 370):
        block(plaza, "FlowerBed", (20, 1.5, 5), (side*47, lobby_y + .75, z), palette["edge"], 816)
        for dx in (-7, -3.5, 0, 3.5, 7):
            block(plaza, "FlowerCluster", (2.4, 1.2, 2.4), (side*47+dx, lobby_y + 2, z), (146, 123, 179) if dx%7 else (113, 179, 157), 1280, False, yaw=math.pi/4)

# Warm lantern walk and sagging strings of light, high above normal head height.
for x in (-26, 26):
    for z in (286, 310, 340, 362):
        block(plaza, "GardenLanternPost", (1, 12, 1), (x, lobby_y + 6, z), palette["edge"], 1088)
        block(plaza, "GardenLanternCap", (3.2, .5, 3.2), (x, lobby_y + 13.6, z), palette["edge"], 1088)
        lamp = block(plaza, "GardenLantern", (2, 2.4, 2), (x, lobby_y + 12, z), palette["amber"], 288, False)
        light = item(lamp, "PointLight", "GardenGlow")
        prop(light, "Color3", "Color", (255, 216, 176))
        prop(light, "float", "Range", 30)
        prop(light, "float", "Brightness", 1.2)
        prop(light, "bool", "Shadows", False)
for z in (284, 358):
    for x in (-27, 27):
        block(plaza, "GardenArchPillar", (2, 19, 2), (x, lobby_y + 9.5, z), palette["edge"], 1088)
    block(plaza, "GardenArchBeam", (56, 1.5, 2), (0, lobby_y + 19, z), (77, 87, 104), 512)
    for x in range(-24, 25, 3):
        height = 17 - 3*(1-(x/27)**2)
        block(plaza, "HangingLantern", (.65, 1, .65), (x, lobby_y + height, z), palette["amber"], 288, False)
        block(plaza, "LanternCord", (.1, lobby_y + 19 - (lobby_y + height), .1), (x, lobby_y + (19+height)/2, z), palette["edge"], 272, False)
sign(plaza, "THE RIFT GARDENS", (0, lobby_y + 16, 283.8), (38, 3.5, .25), palette["mint"])

# A walk-up mastery gateway opens course practice and earned medal progress.
mastery = item(plaza, "Model", "MasteryGateway")
for side in (-1, 1):
    block(mastery, "MasteryPillar", (2, 13, 3), (side*8, lobby_y+6.5, 357), (61, 58, 91), 1088)
    block(mastery, "MasteryGlow", (.5, 11, 3.1), (side*8, lobby_y+6, 357), palette["violet"], 288, False)
block(mastery, "MasteryArch", (18, 2, 3), (0, lobby_y+13, 357), (61, 58, 91), 1088)
mastery_anchor = hovering(mastery, "MasteryPortal", (0, lobby_y+5, 353), "*", "Mastery", palette["violet"], "Practice")
marker = item(mastery_anchor.find("Item[@class='Folder']"), "BoolValue", "NativeVisual")
prop(marker, "bool", "Value", True)
activity_icon(mastery_anchor, (0, lobby_y+7.5, 353), "Mastery", item, block, prop)

# Decorative floating crystal islands stay outside the public rails.
for side in (-1, 1):
    for z in (303, 356):
        x = side*91
        block(plaza, "FloatingGardenRock", (15, 8, 15), (x, lobby_y - 5, z), (52, 64, 87), 800, False, yaw=math.pi/4, cls="WedgePart")
        block(plaza, "FloatingGardenTop", (14, 1, 14), (x, lobby_y -.5, z), (72, 112, 105), 1280, False, yaw=math.pi/4)
        for dx in (-3, 2):
            block(plaza, "FloatingGardenCrystal", (2.5, 7 if dx < 0 else 4, 2.5), (x+dx, lobby_y + 4, z), palette["violet"] if dx < 0 else palette["mint"], 288, False, cls="WedgePart")

# Three climbing sections with precise landings, balance beams and real falls.
parkour = item(lobby, "Model", "Parkour")
# A small entry dock replaces the safety floor. Missed jumps fall into the valley.
block(parkour, "ParkourDock", (15, 4, 24), (-71, lobby_y - 2, 230), (92, 111, 126), 816)
block(parkour, "ParkourBridge", (12, 4, 16), (-57, lobby_y - 2, 228), (110, 127, 136), 816)
start = pressure_plate(parkour, "ParkourStart", -73, 228, palette["mint"], 9, 9)
activity_icon(start, (-73, lobby_y+7.5, 228), "Parkour", item, block, prop)
steps = ((-84, 30, 228), (-94, 32, 220), (-104, 34, 214), (-114, 36, 210),
         (-124, 38, 214), (-130, 40, 224), (-128, 42, 236), (-121, 44, 244),
         (-112, 46, 250), (-103, 48, 254), (-93, 50, 252), (-84, 52, 244),
         (-81, 54, 233), (-88, 56, 225), (-97, 58, 219), (-106, 60, 214),
         (-115, 62, 216), (-124, 64, 224), (-125, 66, 235), (-119, 68, 244),
         (-110, 70, 250), (-101, 72, 253), (-92, 74, 248), (-84, 76, 239))
step_sizes = ((5,5),(4,4),(3.5,3.5),(3,7),(4,4),(6,6),
              (3,5),(3.5,3.5),(3,6),(3,3),(4,3.5),(6,6),
              (3.5,3.5),(3.2,3.2),(2.8,7),(3.2,3.2),(3,3.5),(6,6),
              (2.8,6),(3,3),(2.8,6),(3,3),(3.5,3),(7,7))
for index, (x, top, z) in enumerate(steps, 1):
    sx, sz = step_sizes[index-1]
    block(parkour, f"ParkourStep_{index}", (sx, 1.2, sz), (x, top - .6, z), (67, 82, 103), 816)
    checkpoint = index % 6 == 0
    block(parkour, "StepGlow", (sx+.1, .14, sz+.1), (x, top + .05, z), palette["mint"] if checkpoint else palette["violet"], 288, False)
    sign(parkour, "FINISH" if index == len(steps) else str(index), (x, top - .5, z - sz/2 - .15), (min(sx, 5), 1.1, .15), palette["mint"])
    if checkpoint:
        for side in (-1,1):
            block(parkour, "CheckpointBeacon", (.3, 3, .3), (x+side*(sx/2-.2), top+1.5, z+sz/2-.2), palette["mint"], 288, False)
for x, z in ((-76, 220),):
    block(parkour, "ParkourPlanter", (5, 3, 5), (x, lobby_y + 1.5, z), palette["edge"], 816)
    block(parkour, "ParkourCrystal", (3, 7, 3), (x, lobby_y + 6, z), palette["violet"], 288, False, cls="WedgePart")

# Transparent walls cover the complete spawn perimeter, including both side wings.
barriers = item(lobby, "Model", "SpawnBarriers")
def barrier(name, size, pos):
    obj = block(barriers, name, size, pos, palette["edge"], 272, True, alpha=1, preview=False)
    prop(obj, "bool", "CastShadow", False)
    return obj
for name, x, z, length in (("MainEast", 53, 232, 84), ("MainWestNorth", -53, 205, 30), ("MainWestSouth", -53, 255, 38)):
    barrier(name, (2, 62, length), (x, 58, z))
barrier("CourtyardFront", (108, 62, 2), (0, 58, 190))
for z in (219, 237): barrier("BridgeSide", (10, 62, 2), (-57, 58, z))
barrier("CourtyardCeiling", (108, 2, 84), (0, 90, 232))
for x in (-73, 73): barrier("PlazaSide", (2, 62, 100), (x, 58, 324))
for x in (-63, 63): barrier("PlazaShoulder", (22, 62, 2), (x, 58, 275))
barrier("PlazaBack", (148, 62, 2), (0, 58, 374))
barrier("PlazaCeiling", (148, 2, 100), (0, 90, 324))
barrier("ConnectorCeiling", (104, 2, 4), (0, 90, 275))
barrier("LoungeSide", (2, 62, 60), (76, 58, 224))
for z in (205, 243): barrier("LoungeSide", (2, 62, 22), (126, 58, z))
for z in (194, 254): barrier("LoungeEnd", (52, 62, 2), (101, 58, z))
barrier("LoungeCeiling", (52, 2, 62), (101, 90, 224))
vip_activity_geometry_start = len(geometry)
vip_activity(lobby, item, block, prop)
gear_displays(vip, item, block, prop)
(ASSETS / "vip-geometry.json").write_text(json.dumps(vip_lounge_geometry + geometry[vip_activity_geometry_start:], indent=2), encoding="utf-8")
barrier("ActivityEast", (2, 62, 64), (219, 58, 224))
for z in (192, 256): barrier("ActivityEnd", (76, 62, 2), (182, 58, z))
for z in (204, 244): barrier("ActivityWest", (2, 62, 24), (145, 58, z))
for z in (215, 233): barrier("ActivityBridgeSide", (24, 62, 2), (136, 58, z))
barrier("ActivityCeiling", (76, 2, 64), (182, 90, 224))
barrier("ActivityBridgeCeiling", (24, 2, 18), (136, 90, 224))
for x in (-34, 34):
    block(lobby, "LobbyLampPost", (2, 15, 2), (x, lobby_y + 7.5, 243), palette["edge"])
    lamp = block(lobby, "LobbyLamp", (5, 1.5, 5), (x, lobby_y + 15, 243), palette["amber"], 288, False)
    light = item(lamp, "PointLight", "LobbyFill")
    prop(light, "Color3", "Color", (255, 232, 199))
    prop(light, "float", "Brightness", 2)
    prop(light, "float", "Range", 55)
    prop(light, "bool", "Shadows", False)
spawn = block(lobby, "LobbySpawn", (8, 0.4, 8), (0, lobby_y + 0.3, 224), palette["mint"], 288, cls="SpawnLocation")
prop(spawn, "bool", "Neutral", True)
prop(spawn, "bool", "Enabled", True)
prop(spawn, "int", "Duration", 0)
lobby_geometry = geometry[lobby_geometry_start:]
launch_world(lobby,item,block,prop)
lobby_geometry = geometry[lobby_geometry_start:]

scenery = item(workspace, "Model", "ValleyScenery")
random.seed(614)
for side in (-1, 1):
    for index in range(17):
        z = -235 + index * 30
        height = random.randint(42, 90)
        x = side * random.randint(111, 142)
        if z >= 170:
            x += side * 210  # Keep cliffs clear of the lobby and onward-course exits.
        block(scenery, "BasaltRidge", (random.randint(24, 45), height, 43), (x, height / 2 - 22, z), (23 + index % 5, 46 + index % 7, 48 + index % 4), yaw=random.uniform(-0.35, 0.35))
        block(scenery, "RidgeCrown", (35, 14, 34), (x, height - 22, z), (32, 68, 59), yaw=random.uniform(-0.4, 0.4))
    for index in range(20):
        z = -240 + index * 25
        x = side * random.randint(94, 104)
        height = random.randint(12, 22)
        block(scenery, "PineTrunk", (2, height, 2), (x, height / 2 - 8, z), (61, 55, 44), 512, False)
        block(scenery, "PineCanopy", (9, 12, 9), (x, height - 7, z), (35, 78, 64), 1280, False, yaw=math.pi / 4)

lighting = item(tree, "Lighting", "Lighting")
prop(lighting, "float", "ClockTime", 0.6)
prop(lighting, "string", "TimeOfDay", "00:36:00")
prop(lighting, "float", "Brightness", 3)
prop(lighting, "float", "ExposureCompensation", 0.3)
prop(lighting, "float", "EnvironmentDiffuseScale", 0.65)
prop(lighting, "float", "EnvironmentSpecularScale", 0.3)
prop(lighting, "Color3", "Ambient", (160, 180, 192))
prop(lighting, "Color3", "OutdoorAmbient", (175, 191, 192))
prop(lighting, "bool", "GlobalShadows", True)
atmosphere = item(lighting, "Atmosphere", "ValleyMist")
prop(atmosphere, "float", "Density", 0.18)
prop(atmosphere, "float", "Offset", 0.1)
prop(atmosphere, "Color3", "Color", (175, 165, 198))
prop(atmosphere, "Color3", "Decay", (64, 52, 88))
prop(atmosphere, "float", "Haze", 0.8)
prop(atmosphere, "float", "Glare", 0.15)
bloom = item(lighting, "BloomEffect", "GateBloom")
prop(bloom, "float", "Intensity", 0.25)
prop(bloom, "float", "Size", 20)
prop(bloom, "float", "Threshold", 1.4)
color = item(lighting, "ColorCorrectionEffect", "ValleyGrade")
prop(color, "float", "Contrast", 0.015)
prop(color, "float", "Saturation", -0.03)
sky = item(lighting, "Sky", "RiftNight")
prop(sky, "bool", "CelestialBodiesShown", False)

# A self-contained 3D backdrop needs no uploaded skybox images or external IDs.
backdrop = item(workspace, "Model", "RiftBackdrop")
for name, size, pos, rgb in (("SkyEast", (4, 1600, 1804), (900, 300, 0), (28, 26, 49)), ("SkyWest", (4, 1600, 1804), (-900, 300, 0), (28, 26, 49)), ("SkyNorth", (1804, 1600, 4), (0, 300, -900), (28, 26, 49)), ("SkySouth", (1804, 1600, 4), (0, 300, 900), (28, 26, 49)), ("SkyCanopy", (1804, 4, 1804), (0, 1100, 0), (17, 19, 37)), ("SkyBelow", (1804, 4, 1804), (0, -500, 0), (36, 29, 48))):
    obj = block(backdrop, name, size, pos, rgb, 288, False, preview=False)
    prop(obj, "bool", "CastShadow", False)
moon = block(backdrop, "RiftMoon", (130, 130, 130), (-430, 420, -750), (180, 192, 232), 288, False, preview=False)
prop(moon, "token", "shape", 0)
prop(moon, "bool", "CastShadow", False)
random.seed(2214)
for index in range(48):
    z = -850 if index % 2 else 850
    star = block(backdrop, "RiftStar", (3, 3, 3), (random.randint(-800, 800), random.randint(280, 980), z), (176, 180, 225), 288, False, preview=False)
    prop(star, "bool", "CastShadow", False)
for side in (-1, 1):
    for index in range(9):
        x, z = side * (280 + index * 33), -360 + index * 88
        height = 110 + (index % 4) * 25
        block(backdrop, "DistantSpire", (50, height, 55), (x, height/2, z), (49, 46, 70), 800, False, yaw=.25, cls="WedgePart", preview=False)
        block(backdrop, "RiftSeam", (2, height*.7, 3), (x-24*side, height*.55, z-28), palette["violet"], 288, False, preview=False)
        block(backdrop, "FloatingShard", (15, 32, 18), (x, height+32, z), (68, 62, 96), 800, False, yaw=.7, cls="WedgePart", preview=False)
    for index in range(6):
        block(backdrop, "AuroraRibbon", (150, 5, 2), (side * (140 + index * 35), 220 + index * 13, -550), (91 + index * 7, 105 + index * 8, 159 + index * 7), 288, False, yaw=side*.35, alpha=.25, preview=False)

replicated = item(tree, "ReplicatedStorage", "ReplicatedStorage")
shared = item(replicated, "Folder", "RiftShared")
item(replicated, "RemoteEvent", "RiftAction")
server = item(tree, "ServerScriptService", "ServerScriptService")
prop(server, "bool", "LoadStringEnabled", False)
starter = item(tree, "StarterPlayer", "StarterPlayer")
prop(starter, "float", "CameraMinZoomDistance", 10)
prop(starter, "float", "CameraMaxZoomDistance", 38)
client = item(starter, "StarterPlayerScripts", "StarterPlayerScripts")
item(tree, "StarterGui", "StarterGui")
for path, parent, cls, name in (
    ("src/shared/Config.luau", shared, "ModuleScript", "Config"),
    ("src/shared/Rules.luau", shared, "ModuleScript", "Rules"),
    ("src/shared/PassIds.luau", shared, "ModuleScript", "PassIds"),
    ("src/shared/CreatureMotion.luau", shared, "ModuleScript", "CreatureMotion"),
    ("src/shared/MusicIds.luau", shared, "ModuleScript", "MusicIds"),
    ("src/server/ProfileStore.luau", server, "ModuleScript", "ProfileStore"),
    ("src/server/PassService.luau", server, "ModuleScript", "PassService"),
    ("src/server/WorldService.luau", server, "ModuleScript", "WorldService"),
    ("src/server/CreatureRig.luau", server, "ModuleScript", "CreatureRig"),
    ("src/server/CaptureService.luau", server, "ModuleScript", "CaptureService"),
    ("src/server/StyleService.luau", server, "ModuleScript", "StyleService"),
    ("src/server/CourseService.luau", server, "ModuleScript", "CourseService"),
    ("src/server/PlaytestService.luau", server, "ModuleScript", "PlaytestService"),
    ("src/server/CatcherNavigation.luau", server, "ModuleScript", "CatcherNavigation"),
    ("src/server/MasteryService.luau", server, "ModuleScript", "MasteryService"),
    ("src/server/PracticeService.luau", server, "ModuleScript", "PracticeService"),
    ("src/server/VIPGearService.luau", server, "ModuleScript", "VIPGearService"),
    ("src/server/LaunchService.luau", server, "ModuleScript", "LaunchService"),
    ("src/server/Game.server.luau", server, "Script", "Game"),
    ("src/client/Controller.client.luau", client, "LocalScript", "Controller"),
    ("src/client/CreatureAnimation.client.luau", client, "LocalScript", "CreatureAnimation"),
    ("src/client/CaptureEffects.client.luau", client, "LocalScript", "CaptureEffects"),
    ("src/client/HoverIcons.client.luau", client, "LocalScript", "HoverIcons"),
    ("src/client/BuffEffects.client.luau", client, "LocalScript", "BuffEffects"),
    ("src/client/Music.client.luau", client, "LocalScript", "Music"),
    ("src/client/SkyAmbience.client.luau", client, "LocalScript", "SkyAmbience"),
    ("src/client/DashEffects.client.luau", client, "LocalScript", "DashEffects"),
    ("src/client/ThreatEffects.client.luau", client, "LocalScript", "ThreatEffects"),
    ("src/client/Mastery.client.luau", client, "LocalScript", "Mastery"),
    ("src/client/VictoryEffects.client.luau", client, "LocalScript", "VictoryEffects"),
    ("src/client/VIPGear.client.luau", client, "LocalScript", "VIPGear"),
    ("src/client/Journey.client.luau", client, "LocalScript", "Journey"),
):
    obj = item(parent, cls, name)
    prop(obj, "ProtectedString", "Source", (ROOT / path).read_text(encoding="utf-8"))
    if cls != "ModuleScript":
        prop(obj, "bool", "Disabled", False)

# Editor view looks down the arena from the lobby. Runtime camera follows the player.
camera = item(workspace, "Camera", "Camera")
camera_frame = prop(camera, "CoordinateFrame", "CFrame", ((200, 170, 275), 0))
forward = [-200, -165, -275]
length = math.sqrt(sum(v * v for v in forward))
look = [v / length for v in forward]
right = [-look[2], 0, look[0]]
right_len = math.sqrt(sum(v * v for v in right))
right = [v / right_len for v in right]
up = [right[1] * look[2] - right[2] * look[1], right[2] * look[0] - right[0] * look[2], right[0] * look[1] - right[1] * look[0]]
for row in range(3):
    for col, vec in enumerate((right, up, [-v for v in look])):
        camera_frame.find(f"R{row}{col}").text = str(vec[row])
prop(camera, "CoordinateFrame", "Focus", ((0, 5, 0), 0))
prop(camera, "token", "CameraType", 5)
prop(workspace, "Ref", "CurrentCamera", camera.attrib["referent"])

ET.indent(tree, space="  ")
output = DIST / "RiftValley.rbxlx"
temporary_output = output.with_suffix(".rbxlx.tmp")
ET.ElementTree(tree).write(temporary_output, encoding="utf-8", xml_declaration=False)
temporary_output.replace(output)
(ASSETS / "arena-geometry.json").write_text(json.dumps(geometry, indent=2), encoding="utf-8")
(ASSETS / "lobby-geometry.json").write_text(json.dumps(lobby_geometry, indent=2), encoding="utf-8")


def font(size):
    for name in ("C:/Windows/Fonts/bahnschrift.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if Path(name).exists():
            return ImageFont.truetype(name, size)
    return ImageFont.load_default()


def render(destination, width, height, icon=False):
    img = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(img)
    for y in range(height):
        t = y / height
        draw.line((0, y, width, y), fill=(int(13 + 13 * t), int(29 + 16 * t), int(43 + 12 * t)))
    scale = width / (640 if icon else 525)
    ox, oy = width * (0.50 if icon else 0.55), height * (0.70 if icon else 0.60)

    def project(x, y, z):
        return (ox + (x - z * 0.55) * scale, oy + (x * 0.23 + z * 0.38 - y) * scale)

    def box(g):
        x, y, z = g["pos"]
        sx, sy, sz = g["size"]
        rgb = g["color"]
        yaw = g["yaw"]

        def vertex(a, b, c):
            dx, dz = a * sx / 2, c * sz / 2
            return project(x + dx * math.cos(yaw) + dz * math.sin(yaw), y + b * sy / 2, z - dx * math.sin(yaw) + dz * math.cos(yaw))

        for verts, shade in (
            (((-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)), .72),
            (((1, -1, -1), (1, -1, 1), (1, 1, 1), (1, 1, -1)), .87),
            (((-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)), 1.05),
        ):
            points = [vertex(*v) for v in verts]
            color = tuple(min(255, int(channel * shade)) for channel in rgb)
            draw.polygon(points, fill=color)

    filtered = [g for g in geometry if abs(g["pos"][0]) < 110 and g["pos"][2] < 180]
    # Back-to-front ordering in this projection, so foreground walls retain their silhouette.
    for g in sorted(filtered, key=lambda g: g["pos"][0] * .23 + g["pos"][2] * .38):
        box(g)
    for x, z, color in ((-19, 48, (108, 255, 204)), (15, 72, (249, 193, 95)), (42, 22, (183, 122, 255))):
        for name, size, pos in (
            ("Body", (7, 10, 5), (x, 9, z)), ("Head", (6, 6, 6), (x, 17, z)),
            ("LeftArm", (3, 9, 3), (x - 5, 10, z - 2)), ("RightArm", (3, 9, 3), (x + 5, 10, z + 2)),
            ("LeftLeg", (3, 7, 3), (x - 2, 3, z + 1)), ("RightLeg", (3, 7, 3), (x + 2, 3, z - 2)),
        ):
            box({"name": name, "size": size, "pos": pos, "color": color if name not in ("LeftLeg", "RightLeg") else (24, 33, 49), "yaw": 0})
    draw.text((width * .055, height * .06), "RIFT", font=font(int(height * .13)), fill=(244, 243, 227))
    draw.text((width * .055, height * .19), "VALLEY", font=font(int(height * .13)), fill=(108, 255, 204))
    if not icon:
        draw.text((width * .06, height * .34), "CROSS. DODGE. SURVIVE.", font=font(int(height * .035)), fill=(196, 219, 207))
        draw.text((width * .06, height * .40), "3 MAPS / CRYSTALS / RECHARGE PADS", font=font(int(height * .025)), fill=(255, 196, 99))
        draw.rounded_rectangle((width * .06, height * .88, width * .28, height * .94), radius=8, fill=(108, 255, 204))
        draw.text((width * .075, height * .885), "ARENA TAG", font=font(int(height * .033)), fill=(17, 26, 34))
    img.save(destination)


render(ASSETS / "thumbnail.png", 1920, 1080)
render(ASSETS / "icon.png", 512, 512, icon=True)

def pass_icon(key, title, accent):
    folder = ASSETS / "passes"
    folder.mkdir(exist_ok=True)
    img = Image.new("RGB", (512, 512), (17, 26, 34))
    draw = ImageDraw.Draw(img)
    draw.ellipse((35, 35, 477, 477), fill=(29, 43, 53), outline=accent, width=10)
    draw.ellipse((52, 52, 460, 460), outline=tuple(int(c*.4) for c in accent), width=3)
    if key == "VIP":
        draw.polygon(((137, 175), (180, 219), (256, 122), (332, 219), (375, 175), (351, 292), (161, 292)), fill=accent)
        draw.rounded_rectangle((158, 304, 354, 325), radius=9, fill=accent)
        for x in (137, 256, 375): draw.ellipse((x-12, (110 if x == 256 else 163), x+12, (134 if x == 256 else 187)), fill=(255, 241, 199))
    elif key == "DoubleCoins":
        for x, y in ((170, 226), (238, 180), (306, 226)):
            draw.ellipse((x-66, y-66, x+66, y+66), fill=(216, 157, 64), outline=(255, 227, 145), width=8)
            draw.ellipse((x-46, y-46, x+46, y+46), outline=(255, 227, 145), width=4)
        draw.text((256, 258), "2X", font=font(92), anchor="mm", stroke_width=5, stroke_fill=(17, 26, 34), fill=(244, 243, 227))
    else:
        for offset, rgb in ((0, (255, 124, 168)), (56, (159, 141, 255)), (112, (94, 237, 255))):
            draw.polygon(((118, 158+offset), (328, 131+offset), (388, 178+offset), (168, 207+offset)), fill=rgb)
        draw.polygon(((349, 111), (363, 87), (377, 111), (401, 125), (377, 139), (363, 163), (349, 139), (325, 125)), fill=(244, 243, 227))
    draw.text((256, 375), title, font=font(42 if len(title) > 8 else 52), anchor="mm", fill=(244, 243, 227))
    img.save(folder / f"{key}.png")

pass_icon("VIP", "VALLEY VIP", (255, 196, 99))
pass_icon("DoubleCoins", "COINS", (108, 255, 204))
pass_icon("StylePack", "PRISM", (190, 139, 255))

banner = Image.new("RGB", (1920, 1080), (17, 26, 34))
bd = ImageDraw.Draw(banner)
bd.text((90, 70), "YOUR CHASE. YOUR SIGNATURE.", font=font(78), fill=(244, 243, 227))
bd.text((90, 170), "RIFT VALLEY / GAME PASSES", font=font(34), fill=(108, 255, 204))
for x, key, title, line in ((85, "VIP", "VALLEY VIP", "Lounge + Gold + Royal Halo"), (685, "DoubleCoins", "DOUBLE COINS", "2x multiplayer coin earnings"), (1285, "StylePack", "PRISM TRAIL PACK", "Three animated color trails")):
    icon = Image.open(ASSETS / "passes" / f"{key}.png").resize((480, 480))
    banner.paste(icon, (x+15, 275))
    bd.text((x+255, 820), title, font=font(40), anchor="mm", fill=(244, 243, 227))
    bd.text((x+255, 880), line, font=font(27), anchor="mm", fill=(158, 182, 179))
bd.text((960, 1000), "One-time Robux purchases. Same chase abilities for everyone.", font=font(30), anchor="mm", fill=(255, 196, 99))
banner.save(ASSETS / "passes" / "store-banner.png")
print(json.dumps({"place": str(output), "instances": counter, "geometry_parts": len(geometry), "bytes": output.stat().st_size}))
