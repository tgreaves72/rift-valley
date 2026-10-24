-- Automated input in a separate Studio test copy. Uses real server remotes,
-- player physics, stamina, dash authorization, catchers and finish validation.
local Players,Run=game:GetService("Players"),game:GetService("RunService")
assert(Run:IsStudio())
local p=Players.LocalPlayer
local Rep=game:GetService("ReplicatedStorage")
local Config=require(Rep:WaitForChild("RiftShared").Config)
local Nav=require(script.Parent:WaitForChild("EnginePilotNavigation"))
local Remote=Rep:WaitForChild("RiftAction")
local controls=require(p.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
controls:Disable()
local Http=game:GetService("HttpService")
local function report(data) print("[RiftRaceEngine] "..Http:JSONEncode(data)) end
local cases={{map="CrystalGrove",skilled=true},{map="SunsetRuins",skilled=true},{map="NeonHarbor",skilled=true},{map="CrystalGrove",skilled=false}}
local index,active,bot,lastPhase=1,false,nil,""
local began,stage,lastSprint,lastSent,dashes,sprintTicks=0,0,nil,-100,0,0
local lastDashStamp,nextTick,lastVote=0,0,-100
local checkedParkour,parkourCheckAt=false,nil
local sprinting=false
local nextSample=0
local function flat(v) return Vector3.new(v.X,0,v.Z) end
Remote.OnClientEvent:Connect(function(action,payload)
	local case=cases[index]
	if not active or not case or not case.skilled then return end
	if action~="GrabWarning" or payload.victim~=p then return end
	local root=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local direction=flat(hum.MoveDirection)
	local ready=(p:GetAttribute("Stamina") or 0)>=Config.DashCost and workspace:GetServerTimeNow()>=(p:GetAttribute("DashReadyAt") or 0)
	if ready and direction.Magnitude>.1 and Nav.safeSegment(root.Position,root.Position+direction.Unit*13) then Remote:FireServer("Dash",direction.Unit)
	else
		-- Time a normal jump near contact when the dash is recharging.
		local attempt=index
		task.delay(math.max(0,payload.duration-.42),function()
			if active and index==attempt and p:GetAttribute("Role")=="Runner" and hum.Parent and hum.FloorMaterial~=Enum.Material.Air then hum.Jump=true end
		end)
	end
	report({event="GRAB_REACTION",case=index,stage=stage,stamina=p:GetAttribute("Stamina")})
end)
Run.Heartbeat:Connect(function()
	local now=workspace:GetServerTimeNow()
	if now<nextTick then return end nextTick=now+.08
	local phase=Rep:GetAttribute("Phase")
	local case=cases[index]
	if not case then return end
	if phase=="Intermission" then
		local char=p.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		local hum=char and char:FindFirstChildOfClass("Humanoid")
		if not root or not hum then return end
		local target=workspace.RiftLobby:FindFirstChild("Vote_"..case.map)
		if not checkedParkour then
			target=workspace.RiftLobby.Parkour.ParkourStart
			if p:GetAttribute("ParkourActive") then
				parkourCheckAt=parkourCheckAt or now
				if now-parkourCheckAt>1 then checkedParkour=true report({event="PLATE",kind="Parkour",passed=true}) end
			end
		end
		local delta=flat(target.Position-root.Position)
		hum:Move(delta.Magnitude>1 and delta.Unit or Vector3.zero,false)
		return
	end
	if phase=="Crossing" and not active and p:GetAttribute("Role")=="Runner" then
		active,began,stage,bot,dashes,sprintTicks=true,now,0,nil,0,0
		lastSprint,lastSent,lastDashStamp=nil,-100,0 sprinting=false
		report({event="START",case=index,map=Rep:GetAttribute("MapId"),skilled=case.skilled,version=Config.Version,pilotRevision=14,grabWarning=Config.GrabWindup,staminaDrain=Config.StaminaDrain,dashDodge=Config.DashDodgeSeconds,plateVote=p:GetAttribute("MapVote")})
	end
	if active and (p:GetAttribute("Role")=="Captured" or p:GetAttribute("Role")=="Catcher" or p:GetAttribute("Role")=="Escaped" or phase=="Results") then
		report({event="RESULT",case=index,map=case.map,skilled=case.skilled,escaped=p:GetAttribute("Role")=="Escaped",role=p:GetAttribute("Role"),stage=stage,seconds=now-began,dashes=dashes,sprintTicks=sprintTicks,stamina=p:GetAttribute("Stamina")})
		active,bot=false,nil index+=1
		if not cases[index] then Remote:FireServer("PauseSolo") report({event="DONE",cases=#cases}) end
		return
	end
	if not active or phase~="Crossing" then return end
	local char=p.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	local current=p:GetAttribute("CourseStage")
	if current~=stage then
		stage=current bot={model=char,root=root,humanoid=hum,spawnPoint=root.Position,stage=current} sprinting=true
		Nav.reset(bot,os.clock())
		report({event="COURSE",case=index,stage=stage,stamina=p:GetAttribute("Stamina")})
	end
	local course=Config.Courses[stage]
	if not course then return end
	local goal={Position=Vector3.new(course.x,root.Position.Y,course.z+126)}
	local stamina=p:GetAttribute("Stamina") or 100
	if p:GetAttribute("EnginePilotUseBuffs")==true and case.skilled and stamina<40 and now>=(p:GetAttribute("StaminaBuffReadyAt") or 0) then
		local group=stage==1 and workspace.RiftArena.ActiveMap or workspace.RiftArena.ChaseCourses:FindFirstChild("Course_"..stage)
		local closest=math.huge
		for _,part in ipairs(group:GetChildren()) do
			local marker=part:FindFirstChild("HoverIcon")
			if part:IsA("BasePart") and marker and marker:FindFirstChild("Kind") and marker.Kind.Value=="Stamina" and part.Position.Z>=root.Position.Z-4 then
				local distance=flat(part.Position-root.Position).Magnitude
				if distance<75 and distance<closest then goal.Position=Vector3.new(part.Position.X,root.Position.Y,part.Position.Z) closest=distance end
			end
		end
	end
	-- Never use recovery teleports to complete an attempt.
	if os.clock()-bot.navigation.progressAt>3 then
		report({event="PILOT_STUCK",case=index,stage=stage,position={root.Position.X,root.Position.Y,root.Position.Z}})
		Nav.reset(bot,os.clock())
	end
	Nav.follow(bot,goal,os.clock())
	-- Feed the selected path direction through Move, like keyboard input.
	-- MoveTo alone can leave MoveDirection zero and suppress sprinting.
	local waypoint=bot.navigation.waypoints[bot.navigation.index]
	if not bot.navigation.direct and waypoint then
		local toward=flat(waypoint.Position-root.Position)
		if toward.Magnitude>.1 then hum:Move(toward.Unit,false) end
	end
	local nearest,warned=math.huge,false
	for _,model in ipairs(workspace:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("CourseStage")==stage and model:FindFirstChild("HumanoidRootPart") then
			local distance=flat(model.HumanoidRootPart.Position-root.Position).Magnitude
			nearest=math.min(nearest,distance)
			if distance<16 and (model:GetAttribute("GrabStage")=="Reach" or model:GetAttribute("ChargeStage")=="Warning") then warned=true end
		end
	end
	if sprinting and stamina<30 then sprinting=false elseif not sprinting and stamina>65 then sprinting=true end
	local sprint=case.skilled and now-began>2.3 and stamina>35
	if sprint then sprintTicks+=1 end
	if sprint~=lastSprint or now-lastSent>.8 then
		p:SetAttribute("EnginePilotSprint",sprint)
		Remote:FireServer("Sprint",sprint) lastSprint,lastSent=sprint,now
	end
	local direction=flat(hum.MoveDirection)
	if direction.Magnitude<.1 then direction=flat(root.CFrame.LookVector) end
	if case.skilled and warned and stamina>=Config.DashCost and now>=(p:GetAttribute("DashReadyAt") or 0) and direction.Magnitude>.1 then
		if Nav.safeSegment(root.Position,root.Position+direction.Unit*13) then Remote:FireServer("Dash",direction.Unit)
		elseif hum.FloorMaterial~=Enum.Material.Air then hum.Jump=true end
	end
	local stamp=p:GetAttribute("DashStartedAt") or 0
	if stamp>lastDashStamp then dashes+=1 lastDashStamp=stamp end
	if now>nextSample then
		nextSample=now+1
		report({event="SAMPLE",case=index,stage=stage,stamina=stamina,sprinting=sprint,speed=hum.WalkSpeed,
			position={root.Position.X,root.Position.Y,root.Position.Z},nearest=nearest<1000 and nearest or -1,warned=warned,dashes=dashes})
	end
	lastPhase=phase
end)
