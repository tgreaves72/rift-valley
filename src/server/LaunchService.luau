-- Optional lessons, daily goals and owner-only parkour replays share server authority.
local Rep=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Analytics=game:GetService("AnalyticsService")
local Shared=Rep:WaitForChild("RiftShared")
local Config,Rules=require(Shared.Config),require(Shared.Rules)
local Launch={}
local callbacks,people,lessons=nil,{},{}
local funnel={"Joined","Queued","First Race","First Course","Escaped"}
local function live() return not Run:IsStudio() and game.GameId>0 end
local function analytics(fn)
	if not live() then return end
	task.spawn(function()
		local ok=pcall(fn)
		if not ok then Rep:SetAttribute("AnalyticsDeliveryFailed",true) end
	end)
end
local function fields(stage,reason)
	return {[Enum.AnalyticsCustomFieldKeys.CustomField01.Name]=Rep:GetAttribute("MapId") or "Lobby",
		[Enum.AnalyticsCustomFieldKeys.CustomField02.Name]=tostring(stage or 0),
		[Enum.AnalyticsCustomFieldKeys.CustomField03.Name]=reason or ""}
end
local function reach(player,step)
	local person=people[player]
	if not person or step<=person.funnel then return end
	for index=person.funnel+1,step do
		analytics(function() Analytics:LogOnboardingFunnelStepEvent(player,index,funnel[index]) end)
	end
	person.funnel=step
	player:SetAttribute("LaunchFunnelStep",step)
end
function Launch.init(handlers) callbacks=handlers end
local function daily(profile)
	local day=math.floor(os.time()/86400)
	if not profile.Daily or profile.Daily.day~=day then profile.Daily={day=day,progress={},claimed={}} end
	return profile.Daily,Rules.dailyChallenges(day)
end
function Launch.sync(player)
	local profile=callbacks.profile(player)
	if not profile then return end
	local state,goals=daily(profile)
	player:SetAttribute("ChallengesResetAt",(state.day+1)*86400)
	for index,goal in ipairs(goals) do
		player:SetAttribute("GoalText"..index,goal.text)
		player:SetAttribute("GoalProgress"..index,state.progress[goal.id] or 0)
		player:SetAttribute("GoalTarget"..index,goal.target)
		player:SetAttribute("GoalReward"..index,goal.coins)
		player:SetAttribute("GoalDone"..index,state.claimed[goal.id]==true)
	end
	player:SetAttribute("TutorialSeen",profile.TutorialSeen==true)
	player:SetAttribute("TutorialCompleted",profile.TutorialCompleted==true)
	player:SetAttribute("ParkourFinishes",profile.ParkourFinishes or 0)
	if (profile.ParkourBestMs or 0)>0 then player:SetAttribute("ParkourBest",profile.ParkourBestMs/1000) end
	player:SetAttribute("HasParkourGhost",profile.ParkourGhost~=nil)
end
function Launch.attach(player)
	people[player]={joined=os.clock(),funnel=0,stage=0,events=0,failures=0}
	Launch.sync(player) reach(player,1)
	if callbacks.canStart(player) then reach(player,2) end
end
function Launch.event(player,event,stage)
	local person=people[player]
	local profile=callbacks.profile(player)
	if not person or not profile then return end
	person.stage=stage or person.stage
	if event=="start" then reach(player,3)
	elseif event=="finish" and stage==1 then reach(player,4)
	elseif event=="complete" then reach(player,5) end
	if event=="fall" or event=="catch" then
		person.failures+=1
		if person.failures<=30 then analytics(function() Analytics:LogCustomEvent(player,"RiftFailure",1,fields(stage,event)) end) end
	elseif event=="finish" or event=="complete" then
		person.events+=1
		if person.events<=60 then analytics(function() Analytics:LogCustomEvent(player,"RiftProgress",1,fields(stage,event)) end) end
	end
	local state,goals=daily(profile)
	local changed=false
	for _,goal in ipairs(goals) do
		if goal.event==event and not state.claimed[goal.id] then
			state.progress[goal.id]=math.min(goal.target,(state.progress[goal.id] or 0)+1)
			if state.progress[goal.id]==goal.target then
				state.claimed[goal.id]=true
				profile.Coins=math.min(1000000000,profile.Coins+goal.coins)
			end
			changed=true
		end
	end
	if changed then Launch.sync(player) callbacks.sync(player) end
end
function Launch.ghost(player)
	local profile=callbacks.profile(player)
	callbacks.send(player,"ParkourGhost",profile and profile.ParkourGhost or false)
end
function Launch.parkourFinish(player,seconds,frames,valid)
	local profile=callbacks.profile(player)
	if not profile or not valid or seconds<15 or seconds>3600 then return false end
	local ms=math.floor(seconds*1000+.5)
	profile.ParkourFinishes=(profile.ParkourFinishes or 0)+1
	if (profile.ParkourBestMs or 0)==0 or ms<profile.ParkourBestMs then
		profile.ParkourBestMs=ms
		profile.ParkourGhost=Rules.sanitizeGhost({revision=1,durationMs=ms,frames=frames})
	end
	Launch.event(player,"parkour",0)
	Launch.sync(player) callbacks.sync(player) Launch.ghost(player)
	return true
end
function Launch.isLearning(player) return lessons[player]~=nil end
function Launch.cancel(player)
	lessons[player]=nil
	player:SetAttribute("TutorialActive",false)
	player:SetAttribute("TutorialStep",0)
	if callbacks then callbacks.leave(player) end
end
function Launch.start(player)
	if not callbacks.canStart(player) or lessons[player] then return false end
	local profile=callbacks.profile(player)
	if not profile then return false end
	profile.TutorialSeen=true
	callbacks.enter(player) callbacks.reset(player)
	callbacks.move(player,Vector3.new(-210,32,289),1)
	lessons[player]={step=1,last=Vector3.new(-210,32,289),sampleAt=os.clock(),sprintDistance=0}
	player:SetAttribute("TutorialActive",true) player:SetAttribute("TutorialStep",1)
	Launch.sync(player)
	return true
end
function Launch.skip(player)
	local profile=callbacks.profile(player)
	if not profile or not (callbacks.canStart(player) or lessons[player]) then return end
	profile.TutorialSeen=true
	if lessons[player] then Launch.cancel(player) callbacks.move(player,Vector3.new(0,32,224),-1) end
	Launch.sync(player)
end
function Launch.dash(player)
	local lesson=lessons[player]
	if not lesson then return end
	lesson.dashAt=os.clock()
	if lesson.step==3 and lesson.last.Z>=356 and lesson.last.Z<=394 then lesson.dashed=true end
end
function Launch.step(player,root,hum,sprinting,now)
	local lesson=lessons[player]
	if not lesson then
		local person=people[player]
		if person and now>=(person.dailyAt or 0) then person.dailyAt=now+10 Launch.sync(player) end
		return false
	end
	local position=root.Position
	local delta=position-lesson.last
	local elapsed=math.clamp(now-lesson.sampleAt,.05,1)
	local dash=now-(lesson.dashAt or -100)<.45
	if hum.Health<=0 then Launch.cancel(player) return true end
	if Rules.lobbyZone(position.X,position.Y,position.Z)~="Tutorial" or position.Y<27 or position.Y>49
		or Vector3.new(delta.X,0,delta.Z).Magnitude>(dash and 76 or 40)*elapsed+3 then
		local z=({289,326,359})[lesson.step]
		callbacks.reset(player) callbacks.move(player,Vector3.new(-210,32,z),1)
		lesson.last,lesson.sampleAt=Vector3.new(-210,32,z),now
		lesson.jumped,lesson.dashed,lesson.sprintDistance=false,false,0
		return true
	end
	if lesson.step==1 then
		if hum.FloorMaterial==Enum.Material.Air and position.Y>33.5 and position.Z>=299 and position.Z<=316 then lesson.jumped=true end
		if lesson.jumped and position.Z>=318 and hum.FloorMaterial~=Enum.Material.Air then lesson.step=2 end
	elseif lesson.step==2 then
		if sprinting then lesson.sprintDistance+=math.max(0,delta.Z) end
		if position.Z>=351 and lesson.sprintDistance>=18 then lesson.step=3
		elseif position.Z>357 then callbacks.move(player,Vector3.new(-210,32,326),1) position=root.Position lesson.sprintDistance=0 end
	elseif position.Z>=394 then
		if lesson.dashed then
			local profile=callbacks.profile(player)
			profile.TutorialCompleted=true
			Launch.cancel(player) callbacks.reset(player) callbacks.move(player,Vector3.new(0,32,224),-1)
			Launch.sync(player) callbacks.sync(player)
			analytics(function() Analytics:LogCustomEvent(player,"RiftTutorial",1) end)
			return true
		else callbacks.move(player,Vector3.new(-210,32,359),1) position=root.Position end
	end
	lesson.last,lesson.sampleAt=position,now
	player:SetAttribute("TutorialStep",lesson.step)
	return true
end
function Launch.leave(player)
	local person=people[player]
	if person then analytics(function() Analytics:LogCustomEvent(player,"RiftDeparture",math.min(7200,os.clock()-person.joined),fields(person.stage,"exit")) end) end
	lessons[player],people[player]=nil,nil
end
return Launch
