"""Create an isolated native Studio engine-test copy, without changing the release."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
tree = ET.parse(root / "dist/RiftValley.rbxlx")
server = None
for node in tree.iter("Item"):
    props = node.find("Properties")
    name = props.find("string[@name='Name']")
    if node.get("class") == "ServerScriptService":
        server = node
    if node.get("class") == "Script" and name is not None and name.text == "Game":
        ET.SubElement(props, "bool", name="Disabled").text = "true"
assert server is not None
script = ET.SubElement(server, "Item", {"class": "Script", "referent": "RIFT_ENGINE_TEST"})
props = ET.SubElement(script, "Properties")
ET.SubElement(props, "string", name="Name").text = "EngineMapCheck"
ET.SubElement(props, "ProtectedString", name="Source").text = (root / "tests/studio/maps.server.luau").read_text(encoding="utf-8")
module = ET.SubElement(server, "Item", {"class": "ModuleScript", "referent": "RIFT_ENGINE_ACTORS"})
props = ET.SubElement(module, "Properties")
ET.SubElement(props, "string", name="Name").text = "EngineActors"
ET.SubElement(props, "ProtectedString", name="Source").text = (root / "tests/studio/actors.luau").read_text(encoding="utf-8")
suffix = sys.argv[1] if len(sys.argv) > 1 else ""
assert not suffix or suffix.isalnum()
path = root / f"dist/RiftValley-StudioTests{suffix}.rbxlx"
tree.write(path, encoding="utf-8", xml_declaration=True)
print("Created isolated engine-test place:", path)
