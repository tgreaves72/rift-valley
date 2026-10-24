-- Pose only the cosmetic skeleton. Root motion and tag checks stay server-authoritative.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Motion = require(game:GetService("ReplicatedStorage"):WaitForChild("RiftShared").CreatureMotion)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("RiftShared").Config)
local rigs = {}
local function scan(model, state)
	local count = 0
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Motor6D") and item:GetAttribute("RestPose") then
			count += 1
			if not state.motors[item.Name] then state.motors[item.Name] = { motor = item, rest = item:GetAttribute("RestPose"), pose = CFrame.identity } end
		end
	end
	state.count = count
end
local function track(model)
	if not model:IsA("Model") then return end
	local state = { motors = {}, blend = 0, stride = 0, speed = 0, landing = 0, nextScan = 0 }
	scan(model, state)
	rigs[model] = state
end
for _, model in ipairs(CollectionService:GetTagged("RiftCreature")) do track(model) end
CollectionService:GetInstanceAddedSignal("RiftCreature"):Connect(track)
CollectionService:GetInstanceRemovedSignal("RiftCreature"):Connect(function(model) rigs[model] = nil end)
RunService.PreSimulation:Connect(function(dt)
	local now = os.clock()
	for model, state in pairs(rigs) do
		if state.count < 6 and now >= state.nextScan then scan(model, state) state.nextScan = now + .25 end
		local root = model.PrimaryPart
		if not model.Parent or not root then continue end
		local camera = workspace.CurrentCamera
		if camera and (camera.CFrame.Position - root.Position).Magnitude > 180 then continue end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		if state.position and dt > 0 then
			local delta = root.Position - state.position
			local observed = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
			if observed < 75 then speed = math.max(speed, observed) end
		end
		state.position = root.Position
		state.speed += (speed - state.speed) * math.min(1, dt * 12)
		state.blend += (math.clamp(state.speed / 7, 0, 1) - state.blend) * math.min(1, dt * 10)
		local clipName = Motion.clipForSpeed(state.speed)
		state.stride += math.min(dt, .1) / Motion.Clips[clipName].duration * math.clamp(state.speed / (clipName == "Sprint" and 36 or 25), .65, 1.4)
		local poses = Motion.sample(clipName, state.stride)
		local idle = Motion.idle(now)
		local humanoid = model:FindFirstChildOfClass("Humanoid") or (model.Parent and model.Parent:FindFirstChildOfClass("Humanoid"))
		local inAir = humanoid and humanoid.FloorMaterial == Enum.Material.Air
		if state.inAir and not inAir then state.landing = .18 end
		state.inAir = inAir
		state.landing = math.max(0, state.landing - dt)
		if inAir then poses = Motion.airborne(velocity.Y > 0) end
		local dashStarted = model.Parent:GetAttribute("DashStartedAt") or 0
		local dashAge = workspace:GetServerTimeNow() - dashStarted
		local dashing = dashStarted > 0 and dashAge >= 0 and dashAge < Config.DashDuration + .16
		if dashing then poses = Motion.dash(dashAge, Config.DashDuration) end
		local grabStage = model:GetAttribute("GrabStage")
		local charge = model:GetAttribute("ChargeStage")
		local recovering = workspace:GetServerTimeNow() < (model:GetAttribute("RecoverUntil") or 0)
		if charge then poses = Motion.charge(charge == "Warning") end
		if recovering then poses = Motion.idle(now) end
		if grabStage then poses = Motion.grab(workspace:GetServerTimeNow() - (model:GetAttribute("GrabStartedAt") or 0), grabStage) end
		for name, joint in pairs(state.motors) do
			local pose = (idle[name] or CFrame.identity):Lerp(poses[name] or CFrame.identity, (inAir or grabStage or dashing or charge or recovering) and 1 or state.blend)
			if name == "CreatureSpine" and state.landing > 0 then pose *= CFrame.new(0, -.16 * state.landing / .18, 0) end
			joint.pose = joint.pose:Lerp(pose, math.min(1, dt * 18))
			joint.motor.Transform = joint.pose
		end
	end
end)
