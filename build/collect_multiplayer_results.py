"""Read tagged native multiplayer evidence and verify the isolated copy's sources."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[1]
prepared=json.loads((root/'deploy/multiplayer-test-preparation.json').read_text())
production=ET.parse(root/'dist/RiftValley.rbxlx').getroot()
fixture=ET.parse(root/prepared['testCopy']).getroot()
def scripts(tree):
 return {n.findtext("Properties/string[@name='Name']"):n.findtext("Properties/ProtectedString[@name='Source']") for n in tree.iter('Item') if n.get('class') in ('Script','LocalScript','ModuleScript')}
sources,tested=scripts(production),scripts(fixture)
assert len(sources)==32
for name,source in sources.items():
 expected=source
 for old,new in prepared['replacements'].get(name,[]):expected=expected.replace(old,new)
 assert tested[name]==expected,name
sha=hashlib.sha256(json.dumps(sources,sort_keys=True).encode()).hexdigest()
assert sha==prepared['productionSourceSHA256']
workspace=lambda tree:next(n for n in tree if n.get('class')=='Workspace')
assert ET.tostring(workspace(production))==ET.tostring(workspace(fixture))
records=[]
for log in (Path.home()/'AppData/Local/Roblox/logs').glob('*Studio*last.log'):
 for line in log.read_text(encoding='utf-8',errors='replace').splitlines():
  match=re.search(r'\[RiftMP\] (\{.*\})',line)
  if not match:continue
  try:value=json.loads(match[1])
  except json.JSONDecodeError:continue
  if value.get('run')!=prepared['run']:continue
  at=line.split(',')[0]
  if datetime.fromisoformat(at.replace('Z','+00:00')).timestamp()<prepared['createdUnix']:continue
  records.append({'timestamp':at,'log':log.name,**value})
records.sort(key=lambda row:row['timestamp'])
finished=[row for row in records if row['event']=='DONE']
latest=finished[-1]['data'] if finished else None
report={'version':'0.15.0','checkedOn':datetime.now(timezone.utc).date().isoformat(),'completed':bool(latest and latest.get('completed')),
 'passed':bool(latest and latest.get('passed')),'nativeClients':latest.get('nativeClients',0) if latest else 0,
 'humanPlayers':0,'humanPlaytestPassed':False,'sourceVerification':prepared,
 'workspaceSHA256':hashlib.sha256(ET.tostring(workspace(production))).hexdigest(),'records':records,
 'liveSavesTested':False,'livePurchasesTested':False,'analyticsDashboardDeliveryTested':False}
(root/'deploy/multiplayer-studio-results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'completed':report['completed'],'passed':report['passed'],'latest':records[-1] if records else None}))
