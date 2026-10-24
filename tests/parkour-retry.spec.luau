local r=require("@lune/roblox")
local h=require("./match-host")(1,{spawnPlacementAfterEvent=true})
local p=h.players[1]
local function root() return p.Character.HumanoidRootPart end
local function hum() return p.Character:FindFirstChildOfClass("Humanoid") end
local count=0
local function check(value,message) assert(value,message) count+=1 end
local before=root().Position
p:SetAttribute("ParkourRetryAvailable",true)
h.remote.OnServerEvent:Fire(p,"ParkourRetry")
check(root().Position==before,"forging a retry attribute cannot authorize teleport")
root().CFrame=r.CFrame.new(-73,32.2,228)
h.tick(.1)
check(p:GetAttribute("ParkourActive"),"real game starts timer on the plate")
rawset(hum(),"Health",0) hum().Died:Fire()
check(p:GetAttribute("ParkourRetryAvailable") and not p:GetAttribute("ParkourActive"),"game death callback offers retry and stops timer")
h.remote.OnServerEvent:Fire(p,"ParkourRetry")
check(p:GetAttribute("ParkourRetryPending"),"clicking during death queues the retry")
h.runDelayed()
check(root().Position.X==-73 and root().Position.Z==228 and not p:GetAttribute("ParkourRetryPending"),"respawn consumes queued retry and reaches the plate")
check(not p:GetAttribute("ParkourActive"),"respawn teleport waits for a grounded plate contact")
h.tick(.1)
check(p:GetAttribute("ParkourActive"),"grounded respawn contact starts a fresh timer")
rawset(hum(),"Health",0) hum().Died:Fire()
h.runDelayed()
check(math.abs(root().Position.X)<16 and p:GetAttribute("ParkourRetryAvailable"),"without a click, death respawns normally and leaves the retry available")
h.tick(1)
h.remote.OnServerEvent:Fire(p,"ParkourRetry")
check(root().Position.X==-73,"clicking after respawn also returns to the start")
for _=1,180 do h.tick(.2,true) end
check(p:GetAttribute("Role")=="Spectator" and p:GetAttribute("ParkourActive"),"automatic race selection never interrupts an active parkour timer")
h.world.resetParkour(p)
root().CFrame=r.CFrame.new(0,32,224)
for _=1,180 do
	if h.host.replicated:GetAttribute("Phase")=="Crossing" then break end
	h.tick(.2,true)
end
check(p:GetAttribute("Role")=="Runner" and not p:GetAttribute("ParkourRetryAvailable"),"match entry clears parkour retry state")
before=root().Position
h.remote.OnServerEvent:Fire(p,"ParkourRetry")
check(root().Position==before,"parkour retry cannot be used to leave an active race")
print("PASS: "..count.." actual game parkour death, queued retry, respawn and race-gating assertions")
