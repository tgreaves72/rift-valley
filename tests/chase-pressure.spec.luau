-- Integrates actual server-issued movement on unobstructed flat ground.
-- Not Roblox engine physics or an obstacle-course difficulty measurement.
local r=require("@lune/roblox")
local Config,Rules=require("../src/shared/Config"),require("../src/shared/Rules")
local count=0
local function check(value,message) assert(value,message) count+=1 end
for stage=1,5 do
	check(Rules.botSpeed("Bruiser",stage)>Config.WalkSpeed and Rules.botSpeed("Bruiser",stage)<Config.SprintSpeed,"walking loses ground; sprint gains ground in every course")
end
local function run(skilled,reactionDelay)
	local h=require("./match-host")(1)
	local p=h.players[1]
	for _=1,220 do if h.host.replicated:GetAttribute("Phase")=="Crossing" then break end h.tick(.2,true) end
	local root,hum=p.Character.HumanoidRootPart,p.Character.Humanoid
	rawset(hum,"MoveDirection",r.Vector3.new(0,0,1))
	local began,dashes,sprintTicks=h.now(),0,0
	local lastSprint,lastSprintSent=nil,-100
	local reactionAt=nil
	check(p:GetAttribute("SafeUntil")>h.now()+2.3,"initial arrival protection starts after Ready releases movement")
	for _=1,240 do
		local elapsed=h.now()-began
		local warned=false
		for _,model in ipairs(h.host.workspace:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("CourseStage")==1 and model:GetAttribute("GrabStage")=="Reach" then warned=true end
		end
		local sprint=skilled and elapsed>2.3 and (p:GetAttribute("Stamina") or 100)>35
		if sprint then sprintTicks+=1 end
		if sprint~=lastSprint or h.now()-lastSprintSent>.8 then
			h.remote.OnServerEvent:Fire(p,"Sprint",sprint)
			lastSprint,lastSprintSent=sprint,h.now()
		end
		if warned then reactionAt=reactionAt or h.now()+(reactionDelay or 0) else reactionAt=nil end
		if skilled and reactionAt and h.now()>=reactionAt and (p:GetAttribute("DashReadyAt") or 0)<=h.now() and (p:GetAttribute("Stamina") or 100)>=Config.DashCost then
			local previous=p:GetAttribute("DashStartedAt")
			h.remote.OnServerEvent:Fire(p,"Dash",r.Vector3.new(0,0,1))
			if p:GetAttribute("DashStartedAt")~=previous then dashes+=1 end
		end
		if not root.Anchored then
			local dashing=h.now()-(p:GetAttribute("DashStartedAt") or 0)<Config.DashDuration
			local speed=dashing and Config.DashSpeed or hum.WalkSpeed
			root.CFrame+=r.Vector3.new(0,0,speed*.1)
			root.AssemblyLinearVelocity=r.Vector3.new(0,0,speed)
		end
		for _,model in ipairs(h.host.workspace:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("CourseStage")==1 then
				local br,bh=model.HumanoidRootPart,model.Humanoid
				local direction=rawget(bh,"LastMove") or r.Vector3.zero
				if not br.Anchored and direction.Magnitude>.01 then
					local nextPosition=br.Position+direction*bh.WalkSpeed*.1
					br.CFrame=r.CFrame.lookAt(nextPosition,nextPosition+direction)
					br.AssemblyLinearVelocity=direction*bh.WalkSpeed
				end
			end
		end
		h.tick(.1,false)
		if p:GetAttribute("Role")~="Runner" then return {caught=true,time=h.now()-began,dashes=dashes,sprintTicks=sprintTicks} end
		if p:GetAttribute("CourseStage")==2 then return {escaped=true,time=h.now()-began,dashes=dashes,sprintTicks=sprintTicks} end
	end
	return {timeout=true,dashes=dashes,sprintTicks=sprintTicks}
end
local walking,skilled=run(false),run(true)
check(walking.caught and walking.time<12,"actual warned capture catches a walking runner before the finish")
check(skilled.escaped and skilled.sprintTicks>0,"managed sprint can pass the frontal interception on flat ground")
-- Model the server still seeing the old root after a late authorized dash.
local late=require("./match-host")(1)
local runner=late.players[1]
for _=1,220 do if late.host.replicated:GetAttribute("Phase")=="Crossing" then break end late.tick(.2,true) end
late.tick(3,false)
local br=late.host.workspace:FindFirstChild("Rift Stalker 1/1")
local rr=runner.Character.HumanoidRootPart
br.HumanoidRootPart.CFrame=r.CFrame.lookAt(rr.Position+r.Vector3.new(0,0,2),rr.Position)
br:SetAttribute("NavigationRecoverUntil",0)
check(late.captures.tryGrab(runner,br,br.HumanoidRootPart,nil),"close-contact grab starts before the late dodge")
late.tick(.4,false)
late.remote.OnServerEvent:Fire(runner,"Dash",r.Vector3.new(0,0,1))
check(runner:GetAttribute("DashStartedAt")==late.now(),"late dash gets server authorization")
check(not late.captures.busy(br.HumanoidRootPart),"approved dash immediately interrupts the pending reach")
late.tick(Config.GrabWindup-.4+.01,false)
check(runner:GetAttribute("Role")=="Runner" and not late.captures.isVictim(runner),"approved late dash cancels the grab even while its old root remains in reach")
require("@lune/fs").writeFile("assets/chase-pressure-model.json",require("@lune/serde").encode("json",{scope="Controlled flat-ground frontal interception; not engine gameplay or human balance data",walking=walking,managedAbilities=skilled,delayedDashInterruptVerified=true,reactionDelaySeconds=.4},true))
print("PASS: "..count.." actual-server flat-ground walking capture, warned dash and sprint-pressure assertions")
