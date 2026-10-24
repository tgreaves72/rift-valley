local Players,Rep,Run=game:GetService("Players"),game:GetService("ReplicatedStorage"),game:GetService("RunService")
assert(Run:IsStudio())
local p=Players.LocalPlayer
local Config=require(Rep:WaitForChild("RiftShared").Config)
local Nav=require(script.Parent:WaitForChild("EnginePilotNavigation"))
local Remote,event=Rep:WaitForChild("RiftAction"),Rep:WaitForChild("EngineMPEvent")
local controls=require(p.PlayerScripts:WaitForChild("PlayerModule")):GetControls() controls:Disable()
local nextTick,lastPhase,lastFire,nextBrowse,lastSprint,nextSprint=0,"",0,0,nil,0
local bot,lastStage,lessonStarted=nil,0,false
local warned,reactAt=false,0
local enteredAt=0
local lessonBack=false
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local Paths=game:GetService("PathfindingService")
local function driveRunner(actor,goal,now)
	local route=actor.inputPath
	if not route then route={points={},index=1,nextAt=0,progressAt=now,origin=actor.root.Position} actor.inputPath=route end
	local position=actor.root.Position
	if flat(position-route.origin).Magnitude>1.5 then route.origin=position route.progressAt=now end
	if not route.busy and now>=route.nextAt and (#route.points==0 or route.index>#route.points or now-route.progressAt>1) then
		route.busy=true route.nextAt=now+1
		task.spawn(function()
			local ok,points=pcall(function()
				local path=Paths:CreatePath({AgentRadius=2.2,AgentHeight=6,AgentCanJump=false,WaypointSpacing=3,Costs={Unstable=math.huge}})
				path:ComputeAsync(position,goal.Position)
				return path.Status==Enum.PathStatus.Success and path:GetWaypoints() or nil
			end)
			route.busy=false
			if actor.inputPath==route and ok and points and #points>1 then route.points=points route.index=2 end
		end)
	end
	local point=route.points[route.index]
	while point and flat(point.Position-position).Magnitude<2.4 do route.index+=1 point=route.points[route.index] end
	local toward=flat((point and point.Position or goal.Position)-position)
	if toward.Magnitude>.1 and (point or Nav.safeSegment(position,position+toward.Unit*4)) then actor.humanoid:Move(toward.Unit,false)
	else actor.humanoid:Move(Vector3.zero,false) end
	if now-route.progressAt>2 and now-(route.lastJump or 0)>1 and actor.humanoid.FloorMaterial~=Enum.Material.Air then
		actor.humanoid.Jump=true route.lastJump=now
	end
end
local function sprint(enabled,now)
	p:SetAttribute("EnginePilotSprint",enabled)
	if lastSprint~=enabled or now>=nextSprint then Remote:FireServer("Sprint",enabled) lastSprint,nextSprint=enabled,now+.8 end
end
Remote.OnClientEvent:Connect(function(action,data)
	if action=="GrabWarning" and data.victim==p then
		event:FireServer("Warning",true) warned=true reactAt=workspace:GetServerTimeNow()+.3
	end
end)
task.spawn(function()
	p.PlayerGui:WaitForChild("RiftHUD"):WaitForChild("Menu"):WaitForChild("JourneyButton")
	local goals=p.PlayerGui:WaitForChild("RiftJourney"):WaitForChild("GoalsPanel")
	assert(goals:WaitForChild("Goal3") and goals:WaitForChild("GhostToggle"))
	Remote:FireServer("MasteryMenu",true) event:FireServer("UIReady",true)
end)
Run.Heartbeat:Connect(function()
	local now=workspace:GetServerTimeNow() if now<nextTick then return end nextTick=now+.06
	local char=p.Character local root=char and char:FindFirstChild("HumanoidRootPart") local hum=char and char:FindFirstChildOfClass("Humanoid")
	local slot=p:GetAttribute("EngineSlot") local phase=Rep:GetAttribute("EngineMPPhase")
	if not root or not hum or not slot then return end
	if phase~=lastPhase then
		lastPhase=phase bot=nil lastStage=0
		if phase=="Training" and slot==1 then Remote:FireServer("TutorialStart")
		elseif phase=="Arena" and slot>=2 then Remote:FireServer("VisitVIP")
		elseif phase=="Race" then Remote:FireServer("MasteryMenu",false)
		elseif phase=="Complete" or phase=="Hold" then Remote:FireServer("MasteryMenu",true) end
	end
	if phase~="Race" and now>=nextBrowse then Remote:FireServer("MasteryMenu",true) nextBrowse=now+3 end
	if phase=="Lobby" then
		hum:Move(Vector3.zero,false)
		if Rep:GetAttribute("Votes_CrystalGrove")==2 and Rep:GetAttribute("Votes_SunsetRuins")==1 then
			local tally=p.PlayerGui.RiftHUD:FindFirstChild("VoteTally")
			if tally and tally.CrystalGrove.Count.Text=="2" and tally.SunsetRuins.Count.Text=="1" then event:FireServer("Votes",true) end
		end
		return
	elseif phase=="Training" and slot==1 and p:GetAttribute("TutorialActive") then
		local step=p:GetAttribute("TutorialStep")
		if step==1 then
			if root.Position.Z>319 then lessonBack=true elseif root.Position.Z<298 then lessonBack=false end
		else lessonBack=false end
		hum:Move(Vector3.new(0,0,lessonBack and -1 or 1),false) sprint(step==2,now)
		if step==1 and not lessonBack and root.Position.Z>=303 and root.Position.Z<314 and hum.FloorMaterial~=Enum.Material.Air then hum.Jump=true end
		if step==3 and root.Position.Z>=362 and now>=(p:GetAttribute("DashReadyAt") or 0) then Remote:FireServer("Dash",Vector3.new(0,0,1)) end
		return
	elseif phase=="Ghost" then
		hum:Move(Vector3.zero,false) sprint(false,now)
		event:FireServer("Ghost",workspace:FindFirstChild("RiftParkourGhost")~=nil)
		return
	elseif phase=="Arena" then
		hum:Move(Vector3.zero,false) sprint(false,now)
		if slot==2 then
			local tool=char:FindFirstChild("Rift Blaster") or p.Backpack:FindFirstChild("Rift Blaster")
			if tool and tool.Parent~=char then hum:EquipTool(tool) end
			local trigger=Rep:GetAttribute("EngineFireTrigger") or 0
			if tool and tool.Parent==char and trigger>lastFire then lastFire=trigger tool:Activate() end
		end
		return
	elseif phase~="Race" then hum:Move(Vector3.zero,false) sprint(false,now) return end
	local gamePhase=Rep:GetAttribute("Phase") local role=p:GetAttribute("Role")
	for _,other in ipairs(Players:GetPlayers()) do
		if other~=p and other:GetAttribute("CourseStage") and other:GetAttribute("Role") then event:FireServer("Replica",true) break end
	end
	if gamePhase=="Intermission" then
		local plate=workspace.RiftLobby:FindFirstChild("Vote_"..(Rep:GetAttribute("EngineWantedMap") or "CrystalGrove"))
		local delta=flat(plate.Position-root.Position) hum:Move(delta.Magnitude>1 and delta.Unit or Vector3.zero,false) sprint(false,now) return
	end
	if gamePhase~="Crossing" or (role~="Runner" and role~="Catcher") then hum:Move(Vector3.zero,false) sprint(false,now) return end
	local stage=p:GetAttribute("CourseStage") local course=Config.Courses[stage] if not course then return end
	if stage~=lastStage or not bot then bot={model=char,root=root,humanoid=hum,spawnPoint=root.Position,stage=stage} Nav.reset(bot,os.clock()) lastStage=stage enteredAt=now end
	-- Keep the wide first course's outer lane instead of converging both runners
	-- onto the same central intercept. All motion remains native humanoid input.
	local lane=stage==1 and (root.Position.X<course.x and -55 or 55) or 0
	local goal={Position=Vector3.new(course.x+lane,root.Position.Y,course.z+132)}
	if role=="Catcher" then
		local nearest=math.huge
		for _,other in ipairs(Players:GetPlayers()) do
			local otherRoot=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if other:GetAttribute("Role")=="Runner" and other:GetAttribute("CourseStage")==stage and otherRoot then
				local distance=(otherRoot.Position-root.Position).Magnitude if distance<nearest then nearest=distance goal=otherRoot end
			end
		end
		if nearest==math.huge then hum:Move(Vector3.zero,false) return end
	end
	if role=="Runner" and stage>=4 then driveRunner(bot,goal,os.clock()) else
		-- Never invoke the NPC helper's recovery teleport for a player.
		if os.clock()-bot.navigation.progressAt>3 then Nav.reset(bot,os.clock()) end
		Nav.follow(bot,goal,os.clock())
		local waypoint=bot.navigation.waypoints[bot.navigation.index]
		if not bot.navigation.direct and waypoint then local toward=flat(waypoint.Position-root.Position) if toward.Magnitude>.1 then hum:Move(toward.Unit,false) end end
	end
	local skilled=role=="Runner" and slot~=3
	local stamina=p:GetAttribute("Stamina") or 0
	if bot.sprinting and stamina<30 then bot.sprinting=false elseif not bot.sprinting and stamina>72 then bot.sprinting=true end
	sprint(skilled and now-enteredAt>2.3 and bot.sprinting==true,now)
	if skilled and not warned then
		for _,model in ipairs(workspace:GetChildren()) do
			local actor=model:IsA("Model") and model:FindFirstChild("HumanoidRootPart")
			if actor and model:GetAttribute("CourseStage")==stage and flat(actor.Position-root.Position).Magnitude<16
				and (model:GetAttribute("GrabStage")=="Reach" or model:GetAttribute("ChargeStage")=="Warning") then
				warned=true reactAt=now+.2 break
			end
		end
	end
	if warned and now>=reactAt and skilled then
		local move=flat(hum.MoveDirection)
		local direction
		if move.Magnitude>.1 then
			local side=Vector3.new(-move.Unit.Z,0,move.Unit.X)
			for _,candidate in ipairs({move.Unit,(move.Unit+side).Unit,(move.Unit-side).Unit,side,-side}) do
				if Nav.safeSegment(root.Position,root.Position+candidate*14) then direction=candidate break end
			end
		end
		if stamina>=Config.DashCost and now>=(p:GetAttribute("DashReadyAt") or 0) and direction then
			Remote:FireServer("Dash",direction)
		elseif hum.FloorMaterial~=Enum.Material.Air then hum.Jump=true end
		warned=false
	end
end)
