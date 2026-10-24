-- Run only inside the separate Studio test place built by build/studio_test_place.py.
-- Uses engine Humanoid physics, PathfindingService and the production navigation module.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Studio-only test harness")
local Http = game:GetService("HttpService")
local Physics = game:GetService("PhysicsService")
pcall(function() Physics:RegisterCollisionGroup("RiftCharacters") end)
Physics:CollisionGroupSetCollidable("RiftCharacters", "RiftCharacters", false)
local Shared = game:GetService("ReplicatedStorage").RiftShared
local Config, Rules = require(Shared.Config), require(Shared.Rules)
local Server = game:GetService("ServerScriptService")
local Creature, Navigation = require(Server.CreatureRig), require(Server.CatcherNavigation)
local Courses = require(Server.CourseService)
local Arena = workspace.RiftArena
local function report(value) print("[RiftEngine] " .. Http:JSONEncode(value)) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function actor(stage, kind)
	local course = Config.Courses[stage]
	local model = Creature.create("Engine " .. stage .. " " .. kind, false)
	Creature.variant(model, kind)
	model.Parent = workspace
	local spawn = Vector3.new(course.x + (kind == "Stalker" and 10 or -10), 4, course.z-144)
	model:PivotTo(CFrame.lookAt(spawn, spawn+Vector3.new(0,0,1)))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower = Rules.botSpeed(kind, stage), 45, true
	model.PrimaryPart:SetNetworkOwner(nil)
	local bot = {model=model,root=model.PrimaryPart,humanoid=humanoid,spawnPoint=spawn,stage=stage,kind=kind}
	Navigation.reset(bot, os.clock())
	return bot
end
local results = {}
task.wait(2)
report({event="START",version=Config.Version,scope="Studio engine physics and production navigation; automated actors, not human balance data"})
for _, map in ipairs(Config.Maps) do
	local old = Arena:FindFirstChild("ActiveMap")
	if old then old:Destroy() end
	local visual = game:GetService("ServerStorage").RiftMaps[map.id]:Clone()
	visual.Name, visual.Parent = "ActiveMap", Arena
	Courses.activate(map.id)
	task.wait(2)
	local cases = {}
	for stage = 1,5 do
		for _, kind in ipairs(stage >= 3 and {"Bruiser","Stalker"} or {"Bruiser"}) do
			local bot = actor(stage, kind)
			local c = Config.Courses[stage]
			table.insert(cases, {bot=bot,goal={Position=Vector3.new(c.x,4,c.z+124)},map=map.id,stage=stage,kind=kind,jumps=0,recoveries=0,minimumY=100})
		end
	end
	task.wait(1)
	local began, nextTick = os.clock(), 0
	while os.clock()-began < 25 do
		local now = os.clock()
		Courses.step(now,true)
		if now >= nextTick then
			nextTick = now+.1
			for _,case in ipairs(cases) do
				local bot=case.bot
				if case.finished then continue end
				case.minimumY=math.min(case.minimumY,bot.root.Position.Y)
				if flat(bot.root.Position-case.goal.Position).Magnitude < 4 then
					case.finished=now-began
					Navigation.idle(bot,now)
				else
					if bot.root.Position.Y < -8 then Navigation.recover(bot,now) case.recoveries+=1 end
					Navigation.follow(bot,case.goal,now)
					if bot.humanoid.Jump then case.jumps+=1 end
				end
			end
		end
		local complete=true
		for _,case in ipairs(cases) do if not case.finished then complete=false break end end
		if complete then break end
		RunService.Heartbeat:Wait()
	end
	for _,case in ipairs(cases) do
		local bot=case.bot
		local result={event="NAV",map=case.map,stage=case.stage,kind=case.kind,passed=case.finished~=nil,seconds=case.finished,
			jumps=case.jumps,recoveries=case.recoveries,minimumY=case.minimumY,
			position={bot.root.Position.X,bot.root.Position.Y,bot.root.Position.Z},floor=tostring(bot.humanoid.FloorMaterial),
			waypoint=bot.navigation.index,waypoints=#bot.navigation.waypoints,pathFailed=bot.navigation.failed==true}
		table.insert(results,result) report(result)
		Navigation.remove(bot) bot.model:Destroy()
	end
end
-- Test each intended parkour transfer using a standard R6 running jump.
-- Each transfer starts from the previous stone's edge; no midair teleporting.
local makeActor=require(Server.EngineActors)
local parkour=workspace.RiftLobby.Parkour
local transfers={}
for index=1,Config.ParkourSteps do
	local previous=index==1 and parkour.ParkourDock or parkour["ParkourStep_"..(index-1)]
	local nextStone=parkour["ParkourStep_"..index]
	local delta=flat(nextStone.Position-previous.Position)
	local takeoff=previous.Position+Vector3.new(math.sign(delta.X)*math.max(0,previous.Size.X/2-.8),previous.Size.Y/2+3,math.sign(delta.Z)*math.max(0,previous.Size.Z/2-.8))
	local landing=nextStone.Position-Vector3.new(math.sign(delta.X)*math.max(0,nextStone.Size.X/2-.8),0,math.sign(delta.Z)*math.max(0,nextStone.Size.Z/2-.8))
	local model,root,hum=makeActor("Parkour jump "..index,takeoff)
	table.insert(transfers,{index=index,model=model,root=root,hum=hum,stone=nextStone,landing=landing,direction=flat(landing-takeoff).Unit})
end
task.wait(.5)
for _,transfer in ipairs(transfers) do
	transfer.root.AssemblyLinearVelocity=transfer.direction*Config.WalkSpeed
	transfer.hum:Move(transfer.direction) transfer.hum.Jump=true
end
local jumpBegan=os.clock()
while os.clock()-jumpBegan<1.4 do
	for _,transfer in ipairs(transfers) do
		if transfer.passed then continue end
		local root,hum,stone=transfer.root,transfer.hum,transfer.stone
		if hum.FloorMaterial==Enum.Material.Air then transfer.airborne=true end
		if flat(transfer.landing-root.Position):Dot(transfer.direction)<.6 then hum:Move(Vector3.zero) end
		if transfer.airborne and hum.FloorMaterial~=Enum.Material.Air and math.abs(root.Position.Y-stone.Position.Y-stone.Size.Y/2-3)<1
			and math.abs(root.Position.X-stone.Position.X)<stone.Size.X/2 and math.abs(root.Position.Z-stone.Position.Z)<stone.Size.Z/2 then
			transfer.passed=true transfer.seconds=os.clock()-jumpBegan hum:Move(Vector3.zero)
		end
	end
	RunService.Heartbeat:Wait()
end
for _,transfer in ipairs(transfers) do
	local result={event="PARKOUR",step=transfer.index,passed=transfer.passed==true,seconds=transfer.seconds,
		position={transfer.root.Position.X,transfer.root.Position.Y,transfer.root.Position.Z}}
	table.insert(results,result) report(result) transfer.model:Destroy()
end
local passed=0
for _,result in ipairs(results) do if result.passed then passed+=1 end end
report({event="DONE",passed=passed,total=#results,version=Config.Version})
workspace:SetAttribute("EngineTestsComplete",true)
