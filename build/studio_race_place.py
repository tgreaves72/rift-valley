"""Package an actual-game Studio Play test with automated legitimate player input."""
from pathlib import Path
import xml.etree.ElementTree as ET
import sys

root=Path(__file__).resolve().parents[1]
tree=ET.parse(root/"dist/RiftValley.rbxlx")
scripts=None
server=None
for node in tree.iter("Item"):
    if node.get("class")=="ServerScriptService": server=node
    name=node.find("Properties/string[@name='Name']")
    if name is not None and name.text=="StarterPlayerScripts": scripts=node
    if name is not None and name.text=="Controller":
        # The real input poll otherwise resends "Shift is up" over the pilot.
        # Only this input value changes in the test copy. The server and its
        # validation, stamina, speed and dash code remain byte-for-byte exact.
        source=node.find("Properties/ProtectedString[@name='Source']")
        source.text=source.text.replace('Remote:FireServer("Sprint", sprinting)',
            'Remote:FireServer("Sprint", player:GetAttribute("EnginePilotSprint") == true)')
assert scripts is not None
assert server is not None
for name,cls,path in (("EngineRacePilot","LocalScript","tests/studio/race-pilot.client.luau"),
                      ("EngineAudioProbe","LocalScript","tests/studio/audio-probe.client.luau"),
                      ("EnginePilotNavigation","ModuleScript","src/server/CatcherNavigation.luau")):
    item=ET.SubElement(scripts,"Item",{"class":cls,"referent":"ENGINE_"+name})
    props=ET.SubElement(item,"Properties")
    ET.SubElement(props,"string",name="Name").text=name
    ET.SubElement(props,"ProtectedString",name="Source").text=(root/path).read_text(encoding="utf-8")
probe=ET.SubElement(server,"Item",{"class":"Script","referent":"ENGINE_STARTUP_PROBE"})
props=ET.SubElement(probe,"Properties")
ET.SubElement(props,"string",name="Name").text="EngineStartupProbe"
ET.SubElement(props,"ProtectedString",name="Source").text=(root/"tests/studio/startup-probe.server.luau").read_text(encoding="utf-8")
suffix=sys.argv[1] if len(sys.argv)>1 else ""
assert not suffix or suffix.isalnum()
path=root/f"dist/RiftValley-RaceTests{suffix}.rbxlx"
tree.write(path,encoding="utf-8",xml_declaration=True)
print("Created actual-game Studio race test:",path)
