local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local host=require("./native-host")()
local Rules=require("../src/shared/Rules")
local function instance(cls) return host.wrap(r.Instance.new(cls)) end
local people,owners,eligible,characters={},{},{},{}
local function actor(name,point,isPlayer)
	local model,root,torso,hum=instance("Model"),instance("Part"),instance("Part"),instance("Humanoid")
	model.Name,model.Parent=name,host.workspace
	root.Name,root.CFrame,root.Parent="HumanoidRootPart",r.CFrame.new(point),model
	torso.Name,torso.CFrame,torso.Parent="Torso",root.CFrame,model
	model.PrimaryPart,hum.Parent=root,model
	rawset(hum,"Health",100) rawset(hum,"MaxHealth",100)
	rawset(hum,"TakeDamage",function(_,damage) rawset(hum,"Health",hum.Health-damage) end)
	rawset(hum,"MoveTo",function(_,point) rawset(hum,"LastMoveTo",point) end) rawset(root,"SetNetworkOwner",function() end)
	if not isPlayer then return model,hum end
	local p,bag=instance("Player"),instance("Backpack")
	p.Name,bag.Parent=name,p
	rawset(p,"Character",model)
	characters[model],owners[p],eligible[p]=p,true,true
	table.insert(people,p)
	return p,root,hum,bag,torso
end
local a,ar,ah,bag=actor("VIP",r.Vector3.new(180,32,224),true)
local b,br,bh,bbag,body=actor("Opponent",r.Vector3.new(190,32,224),true)
local hit,shots,range=nil,0,0
rawset(host.workspace,"Raycast",function(_,_,direction) range=direction.Magnitude return hit end)
local env={workspace=host.workspace,Instance={new=instance},Vector3=r.Vector3,CFrame=r.CFrame,Color3=r.Color3,Enum=r.Enum,
	RaycastParams={new=function() return {} end},require=function() return Rules end,
	task={spawn=function(fn) fn() end},
	game={GetService=function(_,name)
		if name=="Players" then return {GetPlayers=function() return people end,GetPlayerFromCharacter=function(_,model) return characters[model] end} end
		if name=="PathfindingService" then return {CreatePath=function() return {Status=r.Enum.PathStatus.Success,ComputeAsync=function() end,
			GetWaypoints=function() return {{Position=r.Vector3.new(205,32,204)},{Position=r.Vector3.new(193,32,214)}} end} end} end
		return host.replicated
	end}}
local Gear=luau.load(fs.readFile("src/server/VIPGearService.luau"),{environment=env})()
Gear.init({owns=function(p) return owners[p]==true end,inLobby=function(p) return eligible[p]==true end,
	shot=function() shots+=1 end,creature=function(name) return actor(name,r.Vector3.zero,false) end})
local count=0
local function check(value,message) assert(value,message) count+=1 end
local speed,jump=Gear.update(a,ah)
check(#bag:GetChildren()==3 and speed==nil and jump==nil,"verified owner receives three functional tools without a passive movement grant")
Gear.update(a,ah)
check(#bag:GetChildren()==3,"refresh cannot duplicate tools")
local tools={}
for _,tool in ipairs(bag:GetChildren()) do
	tools[tool:GetAttribute("RiftVIPGear")]=tool
	check(not tool.CanBeDropped and tool.Handle and tool.Enabled,"real tools have handles, bounded activation and cannot be dropped")
end
tools.Speed.Parent=a.Character
speed,jump=Gear.update(a,ah)
check(speed==38 and jump==nil,"equipped speed coil works in the arena")
tools.Speed.Parent=bag tools.Jump.Parent=a.Character
speed,jump=Gear.update(a,ah)
check(speed==nil and jump==72,"equipped jump coil works in the arena")
tools.Jump.Parent=bag tools.Blaster.Parent=a.Character
hit={Instance=body,Position=br.Position}
check(Gear.fire(a,br.Position,1000) and bh.Health==75 and math.abs(range-120)<.001,"server raycast inflicts exactly 25 damage on another eligible player within 120 studs")
check(not Gear.fire(a,br.Position,1000.1) and bh.Health==75,"server cooldown rejects rapid fire")
check(not Gear.fire(a,"forged",1001) and not Gear.fire(a,r.Vector3.new(0/0,0,0),1001),"malformed and nonfinite aim rejected")
br.CFrame=r.CFrame.new(0,4,0)
check(Gear.fire(a,br.Position,1001) and bh.Health==75,"arena weapon cannot damage a racer outside the arena")
br.CFrame=r.CFrame.new(190,32,224) eligible[b]=false
check(Gear.fire(a,br.Position,1002) and bh.Health==75,"active racers receive no damage even if their position is forged into the arena")
eligible[b]=true owners[b]=false
check(Gear.fire(a,br.Position,1003) and bh.Health==75,"non-owners outside the activity are protected")
owners[b]=true
hit={Instance=host.workspace.RiftLobby.VIPActivity.SparringCover,Position=r.Vector3.new(185,32,224)}
check(Gear.fire(a,br.Position,1004) and bh.Health==75,"cover blocks hits instead of trusting a client target")
Gear.stepEnemies(1005)
local enemy
for _,obj in ipairs(host.workspace.RiftLobby.VIPActivity:GetChildren()) do if obj:GetAttribute("VIPArenaEnemy") then enemy=obj break end end
check(enemy~=nil,"occupied arena creates enemy opponents")
local eh=enemy:FindFirstChildOfClass("Humanoid")
hit={Instance=enemy.Torso,Position=enemy.Torso.Position}
check(Gear.fire(a,enemy.Torso.Position,1005) and eh.Health==75,"same blaster damages real enemy humanoids")
Gear.stepEnemies(1005.5)
check(eh.LastMoveTo==r.Vector3.new(193,32,214),"arena enemy follows a computed route around cover")
ar.CFrame=r.CFrame.new(101,32,224)
rawset(ah,"Health",60)
speed,jump=Gear.update(a,ah)
check(speed==nil and jump==nil and ah.Health==100 and not a:GetAttribute("VIPGearActive"),"leaving activity removes boosts and restores noncompetitive health")
check(not Gear.fire(a,br.Position,1006),"gun never fires in the lounge, parkour or races")
ar.CFrame=r.CFrame.new(180,32,224) eligible[a]=false
Gear.update(a,ah)
check(#bag:GetChildren()==0 and not a.Character:FindFirstChildOfClass("Tool"),"starting a race removes the issued inventory")
eligible[a]=true owners[a]=false
Gear.update(a,ah)
check(#bag:GetChildren()==0,"client attributes cannot grant server ownership")
eligible[b]=false
Gear.stepEnemies(1007)
local living=0
for _,obj in ipairs(host.workspace.RiftLobby.VIPActivity:GetChildren()) do if obj:GetAttribute("VIPArenaEnemy") then living+=1 end end
check(living==0,"empty activity cleans up enemy actors")
check(shots==6,"only accepted shots broadcast effects")
print("PASS: "..count.." actual VIP tool grants, movement, raycasts, damage, cooldown and race-isolation assertions")
