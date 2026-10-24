-- All ownership, movement effects, hit tests and damage stay on the server.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Rules = require(Shared.Rules)
local Gear = {}
local callbacks, issued, enemies = nil, {}, {}
local catalog = {
	Speed = {name="Speed Coil", color=Color3.fromRGB(63,197,151)},
	Jump = {name="Jump Coil", color=Color3.fromRGB(130,81,218)},
	Blaster = {name="Rift Blaster", color=Color3.fromRGB(68,174,215)},
}

local function part(parent, name, size, frame, color, handle)
	local p = Instance.new("Part")
	p.Name,p.Size,p.CFrame,p.Color = name,size,frame,color
	p.Material,p.CanCollide,p.CanTouch,p.CanQuery,p.Massless = Enum.Material.Neon,false,false,false,true
	p.Parent = parent
	if handle then
		local weld = Instance.new("WeldConstraint")
		weld.Part0,weld.Part1,weld.Parent = handle,p,p
	end
	return p
end

local function makeTool(key)
	local definition = catalog[key]
	local tool = Instance.new("Tool")
	tool.Name,tool.ToolTip,tool.CanBeDropped = definition.name,"VIP Arena only",false
	tool:SetAttribute("RiftVIPGear",key)
	local handle = part(tool,"Handle",Vector3.new(.35,.9,.45),CFrame.new(),Color3.fromRGB(64,50,90))
	handle.Material = Enum.Material.SmoothPlastic
	if key == "Blaster" then
		part(tool,"Body",Vector3.new(.8,.65,1.5),CFrame.new(0,.65,-.35),Color3.fromRGB(80,55,123),handle).Material=Enum.Material.SmoothPlastic
		part(tool,"Barrel",Vector3.new(.3,.3,1.7),CFrame.new(0,.7,-1.6),definition.color,handle)
		part(tool,"Sight",Vector3.new(.18,.18,.6),CFrame.new(0,1.05,-.5),Color3.fromRGB(255,221,137),handle)
	else
		for index=0,29 do
			local a,b = index/30*math.pi*6,(index+1)/30*math.pi*6
			local from = Vector3.new(math.cos(a)*.55,.2+index/30*2.1,math.sin(a)*.55)
			local to = Vector3.new(math.cos(b)*.55,.2+(index+1)/30*2.1,math.sin(b)*.55)
			part(tool,"Coil",Vector3.new(.15,.15,(to-from).Magnitude+.04),CFrame.lookAt((from+to)/2,to),definition.color,handle)
		end
	end
	return tool
end

function Gear.init(handlers) callbacks=handlers end

function Gear.remove(player)
	local record = issued[player]
	if record then for _,tool in pairs(record.tools) do tool:Destroy() end end
	issued[player]=nil
	player:SetAttribute("VIPGearActive",false)
end

function Gear.inArena(player)
	if not callbacks or not callbacks.owns(player,"VIP") or not callbacks.inLobby(player) then return false end
	local char = player.Character
	local root,hum = char and char:FindFirstChild("HumanoidRootPart"),char and char:FindFirstChildOfClass("Humanoid")
	return root and hum and hum.Health>0 and Rules.lobbyZone(root.Position.X,root.Position.Y,root.Position.Z)=="VIPActivity" or false
end

function Gear.update(player, humanoid)
	if not callbacks.owns(player,"VIP") or not callbacks.inLobby(player) then Gear.remove(player) return nil,nil end
	local bag = player:FindFirstChildOfClass("Backpack")
	if not bag then return nil,nil end
	local record = issued[player]
	if not record then record={tools={},lastShot=-100,inArena=false} issued[player]=record end
	for key in pairs(catalog) do
		if not record.tools[key] or not record.tools[key].Parent then
			local tool = makeTool(key)
			tool.Parent,record.tools[key] = bag,tool
		end
	end
	local active = Gear.inArena(player)
	player:SetAttribute("VIPGearActive",active)
	for _,tool in pairs(record.tools) do tool.Enabled=active end
	if record.inArena and not active and humanoid.Health>0 then humanoid.Health=humanoid.MaxHealth end
	record.inArena=active
	if not active then return nil,nil end
	local char=player.Character
	return record.tools.Speed.Parent==char and 38 or nil,record.tools.Jump.Parent==char and 72 or nil
end

local function targetModel(part_)
	local node = part_
	while node and node~=workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then return node end
		node=node.Parent
	end
	return nil
end

function Gear.fire(player, aim, now)
	local record = issued[player]
	if not record or not Gear.inArena(player) or record.tools.Blaster.Parent~=player.Character then return false end
	if typeof(aim)~="Vector3" or aim.X~=aim.X or aim.Y~=aim.Y or aim.Z~=aim.Z
		or math.abs(aim.X)>100000 or math.abs(aim.Y)>100000 or math.abs(aim.Z)>100000 then return false end
	if now-record.lastShot<.45 then return false end
	local root = player.Character:FindFirstChild("HumanoidRootPart")
	local origin = root.Position+Vector3.new(0,1,0)
	local direction=aim-origin
	if direction.Magnitude<.1 then return false end
	record.lastShot=now
	local params=RaycastParams.new()
	params.FilterType,params.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude,{player.Character}
	local hit=workspace:Raycast(origin,direction.Unit*120,params)
	local endpoint=hit and hit.Position or origin+direction.Unit*120
	if hit then
		local model=targetModel(hit.Instance)
		local victim=model and Players:GetPlayerFromCharacter(model)
		local enemy=model and enemies[model]
		if model and ((victim and victim~=player and Gear.inArena(victim)) or enemy) then
			local hum=model:FindFirstChildOfClass("Humanoid")
			local targetRoot=model:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health>0 and targetRoot and Rules.lobbyZone(targetRoot.Position.X,targetRoot.Position.Y,targetRoot.Position.Z)=="VIPActivity" then
				hum:TakeDamage(25)
			end
		end
	end
	callbacks.shot(origin,endpoint)
	return true
end

local spawnAt={0,0}
local lastEnemies=0
function Gear.stepEnemies(now)
	if now-lastEnemies<.25 then return end
	lastEnemies=now
	local fighters={}
	for _,player in ipairs(Players:GetPlayers()) do if Gear.inArena(player) then table.insert(fighters,player) end end
	local occupied={}
	for model,record in pairs(enemies) do
		if not model.Parent or record.hum.Health<=0 or #fighters==0 then
			spawnAt[record.slot]=now+5
			enemies[model]=nil
			model:Destroy()
		else
			occupied[record.slot]=true
			local root=record.root
			if Rules.lobbyZone(root.Position.X,root.Position.Y,root.Position.Z)~="VIPActivity" then
				model:PivotTo(CFrame.new(record.home)) root.AssemblyLinearVelocity=Vector3.zero
			end
			local target,distance=nil,math.huge
			for _,player in ipairs(fighters) do
				local pr=player.Character:FindFirstChild("HumanoidRootPart")
				local gap=(pr.Position-root.Position).Magnitude
				if gap<distance then target,distance=player,gap end
			end
			if target then
				local pr=target.Character:FindFirstChild("HumanoidRootPart")
				if now>=(record.nextPath or 0) and not record.pathPending then
					record.nextPath,record.pathPending=now+1.5,true
					local goal=pr.Position
					task.spawn(function()
						local path=game:GetService("PathfindingService"):CreatePath({AgentRadius=2.4,AgentHeight=6,AgentCanJump=false,WaypointSpacing=4})
						local ok=pcall(function() path:ComputeAsync(root.Position,goal) end)
						if enemies[model]~=record then return end
						record.pathPending=false
						if ok and path.Status==Enum.PathStatus.Success then record.path,record.node=path:GetWaypoints(),2 end
					end)
				end
				local waypoint=record.path and record.path[record.node or 2]
				if waypoint and (Vector3.new(waypoint.Position.X,root.Position.Y,waypoint.Position.Z)-root.Position).Magnitude<2.5 then
					record.node+=1 waypoint=record.path[record.node]
				end
				record.hum:MoveTo(waypoint and waypoint.Position or pr.Position)
				if distance<4.5 and now-record.lastHit>=1.5 then
					local params=RaycastParams.new()
					params.FilterType,params.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{model}
					local hit=workspace:Raycast(root.Position,pr.Position-root.Position,params)
					if hit and hit.Instance:IsDescendantOf(target.Character) then
						record.lastHit=now
						target.Character:FindFirstChildOfClass("Humanoid"):TakeDamage(10)
					end
				end
			end
		end
	end
	if #fighters==0 then return end
	for slot=1,2 do
		if not occupied[slot] and now>=spawnAt[slot] then
			local home=Vector3.new(205,32,slot==1 and 204 or 244)
			local model=callbacks.creature("Arena Stalker "..slot)
			local root,hum=model:FindFirstChild("HumanoidRootPart"),model:FindFirstChildOfClass("Humanoid")
			model:SetAttribute("VIPArenaEnemy",true)
			hum.DisplayName,hum.WalkSpeed,hum.MaxHealth,hum.Health="RIFT SPARRER",10,100,100
			model.Parent=workspace:WaitForChild("RiftLobby"):WaitForChild("VIPActivity")
			model:PivotTo(CFrame.new(home))
			root:SetNetworkOwner(nil)
			enemies[model]={root=root,hum=hum,home=home,slot=slot,lastHit=now}
		end
	end
end

return Gear
