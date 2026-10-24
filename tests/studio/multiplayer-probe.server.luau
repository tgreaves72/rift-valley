local Run=game:GetService("RunService") assert(Run:IsStudio())
local Players,Rep=game:GetService("Players"),game:GetService("ReplicatedStorage")
local Http=game:GetService("HttpService")
local Config=require(Rep:WaitForChild("RiftShared").Config)
local Server=game:GetService("ServerScriptService")
local Profiles,Launch,World,Gear,Metrics=require(Server.ProfileStore),require(Server.LaunchService),require(Server.WorldService),require(Server.VIPGearService),require(Server.PlaytestService)
local run=Rep:WaitForChild("EngineMPRun").Value
local testGroup=Rep:WaitForChild("EngineMPGroup").Value
local event=Rep:WaitForChild("EngineMPEvent")
local reports={}
local result={version=Config.Version,run=run,testGroup=testGroup,passed=false,humanPlayers=0,scope="Three native Studio clients with automated input. No human/device balance or live save/purchase claim."}
local function log(eventName,data) print("[RiftMP] "..Http:JSONEncode({run=run,event=eventName,data=data,version=Config.Version})) end
local function waitFor(fn,seconds,message)
	local untilAt=os.clock()+seconds
	repeat if fn() then return end task.wait(.05) until os.clock()>untilAt
	error(message)
end
event.OnServerEvent:Connect(function(p,action,data)
	reports[p]=reports[p] or {}
	if action=="UIReady" or action=="Votes" or action=="Ghost" or action=="Warning" or action=="Replica" then reports[p][action]=data end
end)
local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function hum(p) return p.Character and p.Character:FindFirstChildOfClass("Humanoid") end
local function owned(p,r)
	local ok,owner=pcall(function() return r:GetNetworkOwner() end)
	return ok and owner==p
end
local function place(p,pos)
	local r=root(p) r:SetNetworkOwner(nil) r.CFrame=CFrame.new(pos) r.AssemblyLinearVelocity=Vector3.zero
	task.delay(.35,function() if r.Parent then r:SetNetworkOwner(p) end end)
end
task.spawn(function()
	local ok,err=xpcall(function()
		waitFor(function() return #Players:GetPlayers()==3 end,180,"three native clients did not connect")
		local players=Players:GetPlayers() table.sort(players,function(a,b) return a.UserId>b.UserId end)
		for index,p in ipairs(players) do p:SetAttribute("EngineSlot",index) end
		waitFor(function()
			for _,p in ipairs(players) do if not root(p) or not p:GetAttribute("GoalText1") or not (reports[p] and reports[p].UIReady) then return false end end
			return true
		end,40,"production HUD/goals not initialized on all clients")
		result.nativeClients=3 result.allClientUIReady=true log("READY",{clients=3})
		waitFor(function() return Rep:GetAttribute("Phase")=="Intermission" and (Rep:GetAttribute("Deadline") or 0)-workspace:GetServerTimeNow()>20 end,40,"no fresh voting window")
		Rep:SetAttribute("EngineMPPhase","Lobby")
		for index,p in ipairs(players) do
			local plate=workspace.RiftLobby:FindFirstChild(index==3 and "Vote_SunsetRuins" or "Vote_CrystalGrove")
			place(p,plate.Position+Vector3.new(index==2 and 2 or -2,4,0))
		end
		waitFor(function() return Rep:GetAttribute("Votes_CrystalGrove")==2 and Rep:GetAttribute("Votes_SunsetRuins")==1 end,6,"native plate votes did not tally 2 to 1")
		waitFor(function() for _,p in ipairs(players) do if not reports[p].Votes then return false end end return true end,15,"votes did not replicate to all client tallies")
		result.sharedPressurePlateVotes=true log("VOTES",{grove=2,ruins=1,clients=3})
		for _,p in ipairs(players) do place(p,Vector3.new(0,32,224)) end
		if testGroup~="Races" then
		Rep:SetAttribute("EngineMPPhase","Training")
		waitFor(function() return players[1]:GetAttribute("TutorialCompleted")==true end,60,"native jump/sprint/dash lesson did not complete")
		result.nativeTrainingCompleted=true log("TRAINING",{passed=true})
		local profile=Profiles.get(players[1])
		profile.ParkourBestMs=20000 profile.ParkourGhost={revision=1,durationMs=20000,frames={{0,-730,320,2280,3142},{20000,-1040,790,2600,0}}}
		Launch.sync(players[1])
		Rep:SetAttribute("EngineMPPhase","Ghost")
		place(players[1],workspace.RiftLobby.Parkour.ParkourStart.Position+Vector3.new(0,4,0))
		waitFor(function() return players[1]:GetAttribute("ParkourActive")==true end,5,"ghost test did not start the real parkour plate")
		waitFor(function() return reports[players[1]].Ghost==true end,15,"owner ghost did not render")
		waitFor(function() return reports[players[2]].Ghost~=nil and reports[players[3]].Ghost~=nil end,12,"other clients did not report ghost visibility")
		for index=2,3 do assert(reports[players[index]].Ghost==false,"another client received the private ghost") end
		result.ownerOnlyGhostRendering=true log("GHOST",{ownerVisible=true,otherClientsVisible=false,syntheticRecordFixture=true})
		World.resetParkour(players[1]) profile.ParkourBestMs=0 profile.ParkourGhost=nil Launch.sync(players[1]) Launch.ghost(players[1])
		place(players[1],Vector3.new(0,32,224))
		for index=2,3 do players[index]:SetAttribute("EngineVIPFixture",true) end
		Rep:SetAttribute("EngineMPPhase","Arena")
		waitFor(function() return root(players[2]).Position.X>95 and root(players[3]).Position.X>95 end,5,"VIP sidebar did not authorize both clients")
		place(players[2],Vector3.new(157,32,201)) place(players[3],Vector3.new(166,32,201))
		waitFor(function() return players[2].Character:FindFirstChild("Rift Blaster")~=nil end,5,"native equipped blaster missing")
		task.wait(.6)
		players[2]:SetAttribute("EngineAim",(players[3].Character:FindFirstChild("UpperTorso") or root(players[3])).Position)
		local hp=hum(players[3]).Health
		Rep:SetAttribute("EngineFireTrigger",1)
		waitFor(function() return hum(players[3]).Health<hp end,4,"native PvP activation did not damage the other client")
		assert(hp-hum(players[3]).Health==25,"unexpected native PvP damage")
		result.nativePvPDamage=25
		place(players[2],Vector3.new(101,32,224)) task.wait(.5)
		assert(not Gear.fire(players[2],root(players[3]).Position,os.clock()),"weapon fired outside its arena")
		result.nativeArenaScope=true log("PVP",{damage=25,outsideArenaBlocked=true})
		for _,p in ipairs(players) do place(p,Vector3.new(0,32,224)) end
		task.wait(.4)
		for index=2,3 do players[index]:SetAttribute("EngineVIPFixture",false) end
		waitFor(function() return not players[2].Backpack:FindFirstChild("Rift Blaster") end,3,"native ownership revoke retained gear")
		end
		local races={}
		for _,map in ipairs(Config.Maps) do
			local theme={map=map.id,runners=2,catchers=1,maxCourse=1,escapes=0,captures=0,warning=false,attempts={}}
			for attempt=1,3 do
			Rep:SetAttribute("EngineWantedMap",map.id) Rep:SetAttribute("EngineMPPhase","Race")
			waitFor(function() return Rep:GetAttribute("Phase")=="Ready" end,70,"multiplayer race queue did not begin Ready")
			assert(Rep:GetAttribute("MapId")==map.id,"physical votes selected a different map")
			waitFor(function() return Rep:GetAttribute("Phase")=="Crossing" end,8,"race never unlocked")
			local race={map=map.id,attempt=attempt,runners=0,catchers=0,maxCourse=1,escapes=0,captures=0,warning=false}
			local escapedBefore=Metrics.snapshot().totals.complete or 0
			for _,p in ipairs(players) do
				if p:GetAttribute("Role")=="Runner" then race.runners+=1 elseif p:GetAttribute("Role")=="Catcher" then race.catchers+=1 end
			end
			assert(race.runners==2 and race.catchers==1,"three-player role allocation failed")
			log("RACE_START",{map=map.id,attempt=attempt,runners=2,catchers=1})
			local seenCapture={} local nextPose=0
			local deadline=os.clock()+165
			while Rep:GetAttribute("Phase")=="Crossing" and os.clock()<deadline do
				if os.clock()>=nextPose then
					nextPose=os.clock()+3
					local poses={}
					for i,p in ipairs(players) do local r,h=root(p),hum(p) table.insert(poses,{slot=i,role=p:GetAttribute("Role"),stage=p:GetAttribute("CourseStage"),x=math.floor(r.Position.X),y=math.floor(r.Position.Y),z=math.floor(r.Position.Z),anchored=r.Anchored,owned=owned(p,r),sit=h.Sit,platform=h.PlatformStand,speed=math.floor(r.AssemblyLinearVelocity.Magnitude),walk=h.WalkSpeed,stamina=p:GetAttribute("Stamina"),dash=p:GetAttribute("DashReadyAt") or 0}) end
					log("POSE",poses)
				end
				for _,p in ipairs(players) do
					race.maxCourse=math.max(race.maxCourse,p:GetAttribute("CourseStage") or 0)
					if p:GetAttribute("Role")=="Captured" and not seenCapture[p] then seenCapture[p]=true race.captures+=1 end
					if reports[p].Warning then race.warning=true end
				end
				task.wait(.1)
			end
			-- Results immediately returns roles to Spectator. Count real server finishes.
			race.escapes=(Metrics.snapshot().totals.complete or 0)-escapedBefore
			table.insert(theme.attempts,race) log("RACE_RESULT",race)
			theme.maxCourse=math.max(theme.maxCourse,race.maxCourse) theme.escapes+=race.escapes theme.captures+=race.captures theme.warning=theme.warning or race.warning
			Rep:SetAttribute("EngineMPPhase","Hold")
			waitFor(function() return Rep:GetAttribute("Phase")=="Intermission" end,12,"race did not return safely to the lobby")
			if theme.escapes>0 then break end
			end
			table.insert(races,theme)
		end
		result.races=races
		for _,race in ipairs(races) do
			assert(race.escapes>0,"no complete five-course multiplayer escape in "..race.map)
		end
		local escapes=0 for _,race in ipairs(races) do escapes+=race.escapes end
		assert(escapes>0,"no skillful runner escaped a complete multiplayer run")
		result.totalEscapes=escapes result.multiplayerRolesAndTransitions=true
		for _,p in ipairs(players) do assert(reports[p].Replica,"another client's role/course never replicated") end
		result.clientRoleReplication=true result.passed=true
	end,debug.traceback)
	if not ok then result.error=err end
	result.completed=true Rep:SetAttribute("EngineMPPhase","Complete")
	-- Keep records small enough for Studio's per-line log limit.
	local races=result.races result.races=nil
	log("DONE",result)
	if races then for _,race in ipairs(races) do log("FINAL_RACE",race) end end
end)
