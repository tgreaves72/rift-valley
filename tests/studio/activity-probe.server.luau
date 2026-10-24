local Run=game:GetService("RunService")
assert(Run:IsStudio())
local Players=game:GetService("Players")
local Rep=game:GetService("ReplicatedStorage")
local Gear=require(script.Parent.VIPGearService)
local World=require(script.Parent.WorldService)
local Config=require(Rep:WaitForChild("RiftShared").Config)
local Http=game:GetService("HttpService")
local report={version=Config.Version,passed=false,scope="Native VIP equipment and parkour retry with Studio-only ownership/aim fixtures; not multiplayer balance."}
local function untilTrue(predicate,timeout)
	local deadline=os.clock()+timeout
	repeat if predicate() then return true end task.wait(.05) until os.clock()>deadline
	return false
end
local function check(value,message) assert(value,message) end
task.spawn(function()
	local ok,err=xpcall(function()
		check(untilTrue(function() return Players:GetPlayers()[1]~=nil end,20),"player missing")
		local p=Players:GetPlayers()[1]
		check(untilTrue(function() return p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p:GetAttribute("SaveStatus") end,20),"character not ready")
		local function root() return p.Character.HumanoidRootPart end
		local function hum() return p.Character:FindFirstChildOfClass("Humanoid") end
		p:SetAttribute("StudioVIPFixture",true)
		Rep:SetAttribute("ActivityProbeMode","Mastery")
		task.wait(18)
		Rep:SetAttribute("ActivityProbeMode","Parkour")
		task.wait(.3)
		root().CFrame=CFrame.new(-73,32.4,228) root().AssemblyLinearVelocity=Vector3.zero
		check(untilTrue(function() return p:GetAttribute("ParkourActive")==true end,5),"plate did not start timer")
		local began=p:GetAttribute("ParkourStartedAt")
		task.wait(.7)
		check(p:GetAttribute("ParkourStartedAt")==began,"holding plate restarted timer")
		hum().Health=0
		check(untilTrue(function() return p:GetAttribute("ParkourRetryPending")==true end,3),"dead retry was not queued")
		report.retryTrace={}
		check(untilTrue(function()
			if p.Character and hum() and p.Character:FindFirstChild("HumanoidRootPart") then
				if #report.retryTrace<60 then table.insert(report.retryTrace,{at=os.clock(),x=root().Position.X,y=root().Position.Y,z=root().Position.Z,health=hum().Health,
					pending=p:GetAttribute("ParkourRetryPending"),available=p:GetAttribute("ParkourRetryAvailable"),active=p:GetAttribute("ParkourActive")}) end
				return hum().Health>0 and root().Position.X < -65 and p:GetAttribute("ParkourActive")==true
			end
		end,12),"respawn did not retry at the plate")
		report.parkourPlateTimer=true report.deathRetryQueued=true report.respawnAtPlate=true
		World.resetParkour(p)
		Rep:SetAttribute("ActivityProbeMode","Lounge")
		check(untilTrue(function() return math.abs(root().Position.X-101)<3 end,4),"VIP sidebar did not enter lounge")
		report.vipSidebarOwnerTeleport=true
		root().CFrame=CFrame.new(157,32,224) root().AssemblyLinearVelocity=Vector3.zero
		local bag=p:WaitForChild("Backpack")
		check(untilTrue(function() return bag:FindFirstChild("Speed Coil") and bag:FindFirstChild("Jump Coil") and bag:FindFirstChild("Rift Blaster") end,4),"three VIP tools missing")
		hum():EquipTool(bag:FindFirstChild("Speed Coil")) task.wait(.4)
		check(hum().WalkSpeed==38,"native speed coil did not apply") report.speedCoil=38
		hum():EquipTool(bag:FindFirstChild("Jump Coil")) task.wait(.4)
		check(hum().JumpPower==72 and hum().WalkSpeed==22,"native jump coil did not replace speed") report.jumpCoil=72
		hum():UnequipTools()
		check(untilTrue(function() return workspace.RiftLobby.VIPActivity:FindFirstChild("Arena Stalker 1")~=nil end,5),"arena enemy missing")
		local enemy=workspace.RiftLobby.VIPActivity:FindFirstChild("Arena Stalker 1")
		local eh=enemy:FindFirstChildOfClass("Humanoid")
		p:SetAttribute("StudioAim",enemy.Torso.Position)
		Rep:SetAttribute("ActivityProbeMode","Fire")
		task.wait(.4)
		p:SetAttribute("StudioAim",enemy.Torso.Position)
		Rep:SetAttribute("ActivityProbeTrigger",1)
		check(untilTrue(function() return eh.Health<100 end,4),"client weapon activation caused no server damage")
		check(eh.Health==75,"unexpected native blaster damage")
		report.nativeToolActivation=true report.enemyDamage=25
		root().CFrame=CFrame.new(101,32,224) root().AssemblyLinearVelocity=Vector3.zero
		task.wait(.4)
		check(hum().WalkSpeed==22 and hum().JumpPower==45 and not p:GetAttribute("VIPGearActive"),"VIP effects escaped the activity")
		check(not Gear.fire(p,Vector3.new(205,32,204),os.clock()),"weapon fired in the lounge")
		report.outsideAreaDisabled=true
		p:SetAttribute("StudioVIPFixture",false)
		task.wait(.4)
		check(not p.Backpack:FindFirstChild("Speed Coil") and not p.Character:FindFirstChild("Rift Blaster"),"ownership revocation retained tools")
		report.revocationRemovesGear=true
		report.passed=true
	end,debug.traceback)
	if not ok then report.error=err end
	report.completed=true
	Rep:SetAttribute("ActivityProbeMode","Complete")
	-- Studio truncates long output lines. Keep the result separate from traces.
	for _,sample in ipairs(report.retryTrace or {}) do
		print("[RiftRetryTrace] "..Http:JSONEncode(sample))
	end
	report.retryTrace=nil
	print("[RiftActivityEngine] "..Http:JSONEncode(report))
end)
