-- Actual game/services and native course clones. Controlled clock/avatars,
-- without engine physics, real navigation or replication.
local r = require("@lune/roblox")
local Config = require("../src/shared/Config")
local h = require("./match-host")(3)
local p,q = h.players[1],h.players[2]
local count=0
local function check(value,message) assert(value,message) count+=1 end
local function root(who) return who.Character.HumanoidRootPart end
local function send(who,map,stage) h.remote.OnServerEvent:Fire(who,"PracticeCourse",{mapId=map,stage=stage}) end
send(p,"CrystalGrove",5)
check(not p:GetAttribute("CoursePractice"),"locked practice request cannot unlock a later course")
h.tick(.8,false) send(p,"CrystalGrove",1)
local attempt=h.practice.get(p)
check(attempt and p:GetAttribute("Role")=="Trainee" and p:GetAttribute("CoursePractice"),"eligible lobby player enters course practice")
local group=attempt.group
check(group.y==-400 and root(p).Position.Y==-396 and group.model.Parent==h.host.workspace,"native course clone uses an isolated supported layer")
check(h.host.workspace.FallenPartsDestroyHeight < -1200,"all three practice layers remain above the engine deletion plane")
check(not group.model:FindFirstChildWhichIsA("Script",true),"practice clone contains geometry rather than duplicated server scripts")
send(q,"CrystalGrove",1)
check(h.practice.get(q).group==group and group.users==2,"equal course selections share one bounded training copy")
h.tick(1.1,false)
check(p.Character.Humanoid.WalkSpeed==Config.WalkSpeed,"practice starts independently of main intermission")
for _=1,220 do if h.host.replicated:GetAttribute("Phase")=="Crossing" then break end h.tick(.2,true) end
check(p:GetAttribute("Role")=="Trainee" and q:GetAttribute("Role")=="Trainee" and h.host.replicated:GetAttribute("Phase")=="Crossing","main race starts while trainees stay in practice")
local coins,xp=h.profiles[p].Coins,h.profiles[p].XP
root(p).CFrame=r.CFrame.new(0,-412,-144)
h.tick(.1,false)
check(root(p).Position.Y==-396 and root(p).Position.Z==-144 and root(p).AssemblyLinearVelocity==r.Vector3.zero,"practice fall immediately restores entry and clears velocity")
check(p:GetAttribute("PracticeStartedAt")>h.now(),"fall restarts only that player's course clock")
h.tick(1.1,false)
for _=1,134 do root(p).CFrame+=r.Vector3.new(0,0,2) h.tick(.1,false) end
check(p:GetAttribute("PracticeFinished") and h.profiles[p].Mastery.Practice.CrystalGrove_1,"legitimate training finish records a separate best")
check(h.profiles[p].MedalPoints==0 and h.profiles[p].Crossings==0 and h.profiles[p].Coins==coins and h.profiles[p].XP==xp,"training grants no race progression, coins or medals")
check(not h.profiles[p].Mastery.Races.CrystalGrove_1,"training never overwrites chase time")
local cards=0
for _,event in ipairs(h.events) do if event.player==p and event.action=="MasteryResult" then cards+=1 check(event.data.practice and event.data.medal==0 and event.data.newBest,"practice finish card carries authoritative time and no race medal") end end
h.tick(1,false)
check(p:GetAttribute("PracticeFinalTime")<15 and cards==1,"finish time freezes and completion emits once")
h.remote.OnServerEvent:Fire(p,"PracticeRetry")
check(not p:GetAttribute("PracticeFinished") and root(p).Position.Z==-144 and not p:GetAttribute("PracticeFinalTime"),"retry immediately resets that course without a lobby trip")
h.tick(1.1,false)
root(p).CFrame+=r.Vector3.new(0,0,200)
h.tick(.1,false)
check(root(p).Position.Z==-144 and not p:GetAttribute("PracticeFinished"),"movement violation cannot generate a training best")
h.remote.OnServerEvent:Fire(p,"PracticeLeave")
check(p:GetAttribute("Role")=="Spectator" and root(p).Position.Y==32 and group.model.Parent and group.users==1,"leaving restores lobby while another trainee keeps the copy")
h.practice.leave(q)
check(group.model.Parent==nil,"last trainee releases cloned geometry and hazards")
for index,map in ipairs(Config.Maps) do
	h.mastery.reached(h.profiles[p],5)
	for stage=1,5 do
		h.tick(1,false) send(p,map.id,stage)
		local training=h.practice.get(p)
		check(training and root(p).Position.Y==4-400*index,"each course/theme uses the requested isolated practice layer")
		check(training.group.model.ActiveMechanics:FindFirstChild(tostring(stage)),"practice includes the selected theme's actual hazards")
		local supported=false
		for _,floor in ipairs(training.group.model.CourseGeometry:GetDescendants()) do
			if floor:IsA("BasePart") and floor.CanCollide and math.abs(floor.Position.Y+floor.Size.Y/2-training.group.y)<.01 then
				if math.abs(root(p).Position.X-floor.Position.X)<=floor.Size.X/2 and math.abs(root(p).Position.Z-floor.Position.Z)<=floor.Size.Z/2 then supported=true end
			end
		end
		check(supported,"all fifteen practice entries retain actual permanent supporting floor")
		h.practice.leave(p)
	end
end
check(h.profiles[p].MedalPoints==0,"practice across all themes cannot farm mastery rewards")
local single=require("./match-host")(1)
local solo=single.players[1]
single.remote.OnServerEvent:Fire(solo,"MasteryMenu",true)
check(solo:GetAttribute("SoloPaused"),"browsing mastery pauses automatic solo replay")
for _=1,100 do single.tick(.2,true) end
check(solo:GetAttribute("Role")=="Spectator","mastery browsing cannot be interrupted by automatic race enrollment")
single.remote.OnServerEvent:Fire(solo,"MasteryMenu",false)
single.remote.OnServerEvent:Fire(solo,"Retry")
for _=1,220 do if single.host.replicated:GetAttribute("Phase")=="Crossing" then break end single.tick(.2,true) end
check(solo:GetAttribute("Role")=="Runner" and single.host.replicated:GetAttribute("Phase")=="Crossing","explicit Play returns from browsing to the normal race")
single.remote.OnServerEvent:Fire(solo,"PracticeCourse",{mapId="CrystalGrove",stage=1})
single.remote.OnServerEvent:Fire(solo,"MasteryMenu",true)
check(not solo:GetAttribute("CoursePractice") and solo:GetAttribute("Role")=="Runner","active racers cannot use practice or mastery browsing to evade a chase")
print("PASS: "..count.." actual practice unlock, isolation, multiplayer, retry, best-time and cleanup assertions")
