"""Isolated three-client test, preserving production Game and native geometry."""
from pathlib import Path
import hashlib
import json
import sys
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
tree=ET.parse(root/'dist/RiftValley.rbxlx')
server=next(n for n in tree.iter('Item') if n.get('class')=='ServerScriptService')
client=next(n for n in tree.iter('Item') if n.findtext("Properties/string[@name='Name']")=='StarterPlayerScripts')
rep=next(n for n in tree.iter('Item') if n.get('class')=='ReplicatedStorage')
sources={}
replacements={
 'Controller': [('Remote:FireServer("Sprint", sprinting)','Remote:FireServer("Sprint", player:GetAttribute("EnginePilotSprint")==true)')],
 'PassService': [('function Passes.owns(player, key)\n','function Passes.owns(player, key)\n\tif RunService:IsStudio() and player:GetAttribute("EngineVIPFixture")==true then return key=="VIP" end\n')],
 'VIPGear': [('else aim=player:GetMouse().Hit.Position end','else aim=player:GetAttribute("EngineAim") or player:GetMouse().Hit.Position end')],
}
for node in tree.iter('Item'):
 if node.get('class') not in ('Script','LocalScript','ModuleScript'):continue
 name=node.findtext("Properties/string[@name='Name']")
 source=node.find("Properties/ProtectedString[@name='Source']")
 sources[name]=source.text
 for old,new in replacements.get(name,[]):
  assert old in source.text,name
  source.text=source.text.replace(old,new)
suffix=sys.argv[1] if len(sys.argv)>1 else '15a'
assert suffix.isalnum()
group='Races' if '--races-only' in sys.argv else 'All'
for parent,cls,name,path in ((server,'Script','EngineMultiplayerProbe','tests/studio/multiplayer-probe.server.luau'),
 (client,'LocalScript','EngineMultiplayerPilot','tests/studio/multiplayer-pilot.client.luau'),
 (client,'ModuleScript','EnginePilotNavigation','src/server/CatcherNavigation.luau'),
 (client,'LocalScript','EngineLaunchProbe','tests/studio/launch-probe.client.luau'),
 (server,'Script','EngineStartupProbe','tests/studio/startup-probe.server.luau')):
 obj=ET.SubElement(parent,'Item',{'class':cls,'referent':'ENGINE_MP_'+name})
 props=ET.SubElement(obj,'Properties')
 ET.SubElement(props,'string',name='Name').text=name
 ET.SubElement(props,'ProtectedString',name='Source').text=(root/path).read_text(encoding='utf-8')
obj=ET.SubElement(rep,'Item',{'class':'RemoteEvent','referent':'ENGINE_MP_REMOTE'})
ET.SubElement(ET.SubElement(obj,'Properties'),'string',name='Name').text='EngineMPEvent'
obj=ET.SubElement(rep,'Item',{'class':'StringValue','referent':'ENGINE_MP_RUN'})
props=ET.SubElement(obj,'Properties')
ET.SubElement(props,'string',name='Name').text='EngineMPRun'
ET.SubElement(props,'string',name='Value').text=suffix
obj=ET.SubElement(rep,'Item',{'class':'StringValue','referent':'ENGINE_MP_GROUP'})
props=ET.SubElement(obj,'Properties')
ET.SubElement(props,'string',name='Name').text='EngineMPGroup'
ET.SubElement(props,'string',name='Value').text=group
out=root/f'dist/RiftValley-MultiplayerTests{suffix}.rbxlx'
tree.write(out,encoding='utf-8',xml_declaration=True)
record={'version':'0.15.0','run':suffix,'testCopy':str(out.relative_to(root)),'createdUnix':out.stat().st_mtime,
 'productionSources':len(sources),'productionSourceSHA256':hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest(),
 'replacements':replacements,'additionalFixtures':['server-staged lobby/arena poses','synthetic owner-only ghost record, cleared before racing'],
 'productionGameAndGeometryUnchanged':True,'humanPlayers':0,'nativeClientsRequested':3,'testGroup':group}
(root/'deploy/multiplayer-test-preparation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('Created isolated native multiplayer test:',out)
