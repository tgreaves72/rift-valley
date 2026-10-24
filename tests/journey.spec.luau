local r=require("@lune/roblox")
local Rules=require("../src/shared/Rules")
local Config=require("../src/shared/Config")
local h=require("./match-host")(2)
local p,other=h.players[1],h.players[2]
local count=0
local function check(value,message) assert(value,message) count+=1 end
for day=20700,20707 do
	local seen={}
	for _,goal in ipairs(Rules.dailyChallenges(day)) do check(not seen[goal.id] and goal.coins>0,"three distinct daily goals") seen[goal.id]=true end
end
local function root() return p.Character.HumanoidRootPart end
local function hum() return p.Character:FindFirstChildOfClass("Humanoid") end
local function move(z,y,seconds,air)
	root().CFrame=r.CFrame.new(-210,y or 32,z)
	rawset(hum(),"FloorMaterial",air and r.Enum.Material.Air or r.Enum.Material.Concrete)
	h.tick(seconds or .2)
end
h.remote.OnServerEvent:Fire(p,"TutorialStart")
check(p:GetAttribute("TutorialActive") and root().Position.X==-210,"optional lesson is server-started on a separate island")
for _=1,180 do h.tick(.2,true) end
check(p:GetAttribute("TutorialActive") and p:GetAttribute("Role")=="Spectator" and other:GetAttribute("Role")=="Runner","other players race while a lesson remains isolated")
h.remote.OnServerEvent:Fire(other,"TutorialStart")
check(not other:GetAttribute("TutorialActive"),"active racers cannot teleport out into training")
local lessonPosition=root().Position
local otherHum=other.Character:FindFirstChildOfClass("Humanoid")
rawset(otherHum,"Health",0) otherHum.Died:Fire()
for _=1,5 do h.tick(.2,true) end
check(p:GetAttribute("TutorialActive") and root().Position==lessonPosition,"round results cannot teleport or interrupt an active lesson")
move(321,32,1)
check(p:GetAttribute("TutorialStep")==1,"walking past a target cannot claim the jumping lesson")
move(300,35,1,true) move(313,35,.4,true) move(321,32,.3)
check(p:GetAttribute("TutorialStep")==2,"observed airborne jump and grounded landing advance the lesson")
move(359,32,1)
check(p:GetAttribute("TutorialStep")==2 and root().Position.Z==326,"walking cannot claim the sprint target")
h.remote.OnServerEvent:Fire(p,"Sprint",true)
rawset(hum(),"MoveDirection",r.Vector3.new(0,0,1))
for _=1,9 do move(root().Position.Z+3.3,32,.1) end
check(p:GetAttribute("TutorialStep")==3 and hum().WalkSpeed==34,"real game sprint authorization advances the sprint lesson")
move(395,32,1)
check(p:GetAttribute("TutorialActive") and root().Position.Z==359,"last target requires an approved dash")
h.remote.OnServerEvent:Fire(p,"Dash",r.Vector3.new(0,0,1))
for _=1,6 do if p:GetAttribute("TutorialActive") then move(root().Position.Z+6.5,32,.1) end end
check(p:GetAttribute("TutorialCompleted") and not p:GetAttribute("TutorialActive") and math.abs(root().Position.X)<1,"approved dash completes and returns to lobby")
check(h.profiles[p].TutorialCompleted and h.profiles[p].TutorialSeen,"training completion persists in the profile")
local initialCoins=h.profiles[p].Coins
for _,goal in ipairs(Rules.dailyChallenges(h.profiles[p].Daily.day)) do
	for _=1,goal.target+2 do h.launch.event(p,goal.event,1) end
end
local expected=initialCoins
for _,goal in ipairs(Rules.dailyChallenges(h.profiles[p].Daily.day)) do expected+=goal.coins end
check(h.profiles[p].Coins==expected,"all daily rewards award exactly once")
for _=1,30 do h.launch.event(p,"finish",1) end
check(h.profiles[p].Coins==expected,"repeating completed goals cannot duplicate rewards")
h.remote.OnServerEvent:Fire(p,"ClaimChallenge",1000000)
check(h.profiles[p].Coins==expected,"untrusted claim requests cannot grant coins")
h.profiles[p].Daily.day-=1 h.launch.sync(p)
check(h.profiles[p].Daily.day==math.floor(os.time()/86400) and p:GetAttribute("GoalProgress1")==0,"UTC rollover refreshes goals without a streak penalty")
local frames={{0,-730,320,2280,3142},{20000,-1040,790,2600,0}}
check(h.launch.parkourFinish(p,20,frames,true),"valid ordered parkour finish stores a personal best")
check(h.profiles[p].ParkourGhost.frames[2][1]==20000 and p:GetAttribute("HasParkourGhost"),"recorded server route becomes an owner-only replay")
check(Rules.cosmeticAvailable(h.profiles[p],Config.Cosmetics[1],{}),"one parkour finish unlocks the free Ascent Ace cosmetic")
local old=h.profiles[p].ParkourGhost
h.launch.parkourFinish(p,25,{{0,-730,320,2280,3142},{25000,-1040,790,2600,0}},true)
check(h.profiles[p].ParkourGhost==old and h.profiles[p].ParkourBestMs==20000,"slower finishes preserve the best replay")
check(not h.launch.parkourFinish(p,3,frames,true) and not h.launch.parkourFinish(p,18,frames,false),"invalid and impossibly short attempts earn no parkour milestone")
local saved=Rules.sanitizeProfile(h.profiles[p],Config.Trails,Config.Cosmetics)
check(saved.TutorialCompleted and saved.ParkourFinishes==2 and saved.ParkourGhost.durationMs==20000,"save sanitization retains all launch progression")
saved.ParkourGhost.frames[2][2]=999999
check(Rules.sanitizeProfile(saved,Config.Trails,Config.Cosmetics).ParkourGhost==nil,"invalid replay coordinates cannot survive save sanitization")
root().CFrame=r.CFrame.new(-73,32.4,228)
h.world.beginParkour(p)
for index=1,24 do
	local stone=h.host.workspace.RiftLobby.Parkour:FindFirstChild("ParkourStep_"..index)
	root().CFrame=r.CFrame.new(stone.Position+r.Vector3.new(0,stone.Size.Y/2+3,0))
	h.tick(1)
end
check(p:GetAttribute("ParkourBest")==20 and h.profiles[p].ParkourBestMs==20000,"a slower actual World completion immediately preserves the saved best in the HUD")
local analytics={}
h.services.RunService.IsStudio=function() return false end h.game.GameId=123
h.services.AnalyticsService={}
-- Launch captured this service at startup; test live delivery with a fresh actual module.
local fs,luau=require("@lune/fs"),require("@lune/luau")
local live=luau.load(fs.readFile("src/server/LaunchService.luau"),{environment={
	game={GameId=123,GetService=function(_,name)
		if name=="RunService" then return {IsStudio=function() return false end} end
		if name=="AnalyticsService" then return {LogOnboardingFunnelStepEvent=function(_,_,step) table.insert(analytics,step) end,LogCustomEvent=function(_,_,event) table.insert(analytics,event) end} end
		return h.host.replicated
	end},Enum=r.Enum,Vector3=r.Vector3,require=function(obj) return obj.Name=="Config" and Config or Rules end,task={spawn=function(fn) fn() end},
}})()
live.init({profile=function(who) return h.profiles[who] end,canStart=function() return true end,sync=function() end})
live.attach(p) live.event(p,"start",1) live.event(p,"finish",1) live.event(p,"complete",5)
check(analytics[1]==1 and analytics[2]==2 and analytics[3]==3 and analytics[4]==4,"published server sends ordered onboarding steps")
local before=#analytics live.event(p,"start",1)
check(#analytics==before,"replaying races cannot repeat completed funnel steps")
live.event(p,"catch",4) live.leave(p)
check(analytics[#analytics]=="RiftDeparture" and analytics[#analytics-1]=="RiftFailure","launch analytics includes failure and departure context")
print("PASS: "..count.." actual training, multiplayer isolation, daily rewards, ghost persistence, cosmetic and analytics assertions")
