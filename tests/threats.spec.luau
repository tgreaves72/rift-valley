local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local Rules,Config=require("../src/shared/Rules"),require("../src/shared/Config")
local host=require("./native-host")()
local rendered,played,clock={callbacks={}},0,1000
function rendered:Connect(fn) table.insert(self.callbacks,fn) end
function rendered:Fire() for _,fn in ipairs(self.callbacks) do fn() end end
local function instance(cls)
 local obj=host.wrap(r.Instance.new(cls))
 if cls=="Sound" then rawset(obj,"Play",function() played+=1 end) end
 return obj
end
local model,root=instance("Model"),instance("Part")
model.Parent,root.Parent,root.CFrame=host.workspace,model,r.CFrame.new(0,4,0)
model.PrimaryPart=root
rawset(host.workspace,"CurrentCamera",{CFrame=r.CFrame.new(0,6,-14)})
rawset(host.workspace,"GetServerTimeNow",function() return clock end)
rawset(host.workspace,"Raycast",function() return {Position=r.Vector3.zero} end)
local env={workspace=host.workspace,Enum=r.Enum,CFrame=r.CFrame,Vector3=r.Vector3,Color3=r.Color3,UDim2=r.UDim2,
 Instance={new=instance},RaycastParams={new=function() return {} end},require=function(obj) return obj.Name=="Rules" and Rules or Config end,
 game={GetService=function(_,name)
  if name=="RunService" then return {RenderStepped=rendered} end
  if name=="Debris" then return {AddItem=function() end} end
  return host.replicated
 end}}
luau.load(fs.readFile("src/client/ThreatEffects.client.luau"),{environment=env})()
local count=0
local function check(v,message) assert(v,message) count+=1 end
for _,kind in ipairs({"Bruiser","Stalker"}) do
 model:SetAttribute("Archetype",kind)
 host.replicated.RiftAction.OnClientEvent:Fire("GrabWarning",{model=model,duration=.75})
 local warning=host.workspace.RiftWarning
 local marker=warning.ReachWarning
 check(marker:GetAttribute("HalfWidth")==Rules.grabBounds(kind).width,"warning and capture share actual reach limits")
 for _,part in ipairs(marker:GetChildren()) do
  check(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"contact outline never affects physics or raycasts")
 end
 for _,point in ipairs(Rules.grabOutline(kind)) do
  check(Rules.canGrab("Runner","Crossing",point.x*.999,0,point.z*.999,100,0,kind),"every contact edge lies within server hit test")
 end
 root.CFrame=r.CFrame.new(4,4,8) rendered:Fire()
 check(marker:GetChildren()[1].CFrame.Position.Y>.07 and marker:GetChildren()[1].CFrame.Position.Y<.1,"outline follows the actual ground surface")
 host.replicated.RiftAction.OnClientEvent:Fire("WarningEnd",model)
 check(not warning.Parent,"successful dodge removes its canceled attack warning immediately")
end
host.replicated.RiftAction.OnClientEvent:Fire("ChargeWarning",{model=model,duration=.75})
check(host.workspace.RiftWarning.ReachWarning:FindFirstChild("ChargeRail")~=nil,"cyan warning shows the charge corridor")
clock+=1 rendered:Fire()
check(not host.workspace:FindFirstChild("RiftWarning"),"expired warnings leave no objects")
root.CFrame=r.CFrame.new(0,4,300)
host.replicated.RiftAction.OnClientEvent:Fire("GrabWarning",{model=model,duration=.75})
check(played==3,"distant warnings are culled")
print("PASS: "..count.." actual contact-outline, ground projection, charge corridor and cancellation assertions")

