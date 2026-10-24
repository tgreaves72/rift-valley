"""Separate local test copy. Ownership and mouse aim fixtures never enter release."""
from pathlib import Path
import xml.etree.ElementTree as ET
import hashlib
import json
import sys

root=Path(__file__).resolve().parents[1]
tree=ET.parse(root/'dist/RiftValley.rbxlx')
server=next(n for n in tree.iter('Item') if n.get('class')=='ServerScriptService')
client=next(n for n in tree.iter('Item') if n.findtext("Properties/string[@name='Name']")=='StarterPlayerScripts')
sources={}
overrides=[]
for node in tree.iter('Item'):
    if node.get('class') not in ('Script','LocalScript','ModuleScript'):continue
    name=node.findtext("Properties/string[@name='Name']")
    source=node.find("Properties/ProtectedString[@name='Source']")
    sources[name]=source.text
    if name=='PassService':
        needle='function Passes.owns(player, key)\n'
        assert source.text.count(needle)==1
        source.text=source.text.replace(needle,needle+'\tif RunService:IsStudio() and player:GetAttribute("StudioVIPFixture") == true then return key == "VIP" end\n')
        overrides.append(name)
    elif name=='VIPGear':
        needle='else aim=player:GetMouse().Hit.Position end'
        assert source.text.count(needle)==1
        source.text=source.text.replace(needle,'else aim=player:GetAttribute("StudioAim") or player:GetMouse().Hit.Position end')
        overrides.append(name)
for parent,cls,name,file in ((server,'Script','EngineActivityProbe','activity-probe.server.luau'),
                              (client,'LocalScript','EngineActivityUI','activity-probe.client.luau')):
    obj=ET.SubElement(parent,'Item',{'class':cls,'referent':'ACTIVITY_'+name})
    props=ET.SubElement(obj,'Properties')
    ET.SubElement(props,'string',name='Name').text=name
    ET.SubElement(props,'ProtectedString',name='Source').text=(root/'tests/studio'/file).read_text(encoding='utf-8')
suffix=sys.argv[1] if len(sys.argv)>1 else '14'
assert suffix.isalnum()
out=root/f'dist/RiftValley-ActivityTests{suffix}.rbxlx'
tree.write(out,encoding='utf-8',xml_declaration=True)
record={'version':'0.14.0','productionSources':len(sources),'productionSourceSHA256':hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest(),
        'ownershipAndAimFixtures':sorted(overrides),'productionServerAndGeometryUnchanged':True,'testCopy':str(out.relative_to(root))}
(root/'deploy/activity-test-preparation.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
print('Created isolated Studio activity test:',out)
