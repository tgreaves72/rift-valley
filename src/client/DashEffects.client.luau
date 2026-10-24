-- Server-approved wind and procedural poses, visible to nearby players.
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(Replicated:WaitForChild("RiftShared").Config)
local Remote = Replicated:WaitForChild("RiftAction")
local effects = {}
local duration = Config.DashDuration + .16

local function restore(effect)
	for joint, original in pairs(effect.originals) do
		if joint.Parent then joint.Transform = original end
	end
	effect.originals = {}
end

local function cleanup(player)
	local effect = effects[player]
	if not effect then return end
	restore(effect)
	for _, item in ipairs(effect.items) do item:Destroy() end
	effects[player] = nil
end

local function jointPose(joint, strength, root)
	local name = string.lower(string.gsub(joint.Name, "[ _]", ""))
	local angle
	if name == "rootjoint" or name == "root" or name == "waist" then
		angle = name == "root" and -10 or (name == "waist" and -18 or -28)
	elseif name == "neck" then angle = 12
	elseif name == "leftshoulder" or name == "rightshoulder" then
		angle = -65
	elseif name == "leftelbow" or name == "rightelbow" then angle = -20
	end
	if not angle then return nil end
	local frame
	if joint:IsA("Motor6D") and joint.Part0 then frame = joint.Part0.CFrame * joint.C0
	elseif joint:IsA("AnimationConstraint") and joint.Attachment0 then frame = joint.Attachment0.WorldCFrame end
	if not frame then return nil end
	return CFrame.fromAxisAngle(frame:VectorToObjectSpace(root.CFrame.RightVector), math.rad(angle)*strength)
end

local function start(payload)
	if type(payload) ~= "table" or typeof(payload.direction) ~= "Vector3" or type(payload.started) ~= "number" then return end
	local player = payload.player
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or workspace:GetServerTimeNow() - payload.started > duration then return end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - root.Position).Magnitude > 180 then return end
	cleanup(player)
	local effect = { root = root, character = character, began = payload.started, direction = payload.direction,
		joints = {}, originals = {}, items = {}, ribbons = {}, streaks = {} }
	for _, joint in ipairs(character:GetDescendants()) do
		if (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) and jointPose(joint, 1, root) then table.insert(effect.joints, joint) end
	end
	local tint = player:GetAttribute("Role") == "Catcher" and Color3.fromRGB(190, 148, 255) or Color3.fromRGB(175, 255, 231)
	for index = 1, 6 do
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Name, b.Name = "DashWindA", "DashWindB"
		a.Parent, b.Parent = root, root
		local trail = Instance.new("Trail")
		trail.Name, trail.Attachment0, trail.Attachment1 = "DashWind", a, b
		trail.Color, trail.Lifetime, trail.LightEmission = ColorSequence.new(tint), .18, 1
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, .1), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
		trail.MinLength, trail.FaceCamera, trail.Parent = .05, true, root
		table.insert(effect.ribbons, { a = a, b = b, trail = trail, angle = index*math.pi/3 })
		local streak = Instance.new("Part")
		streak.Name, streak.Size, streak.Color, streak.Material = "DashGust", Vector3.new(.065, .065, 2 + index*.25), tint, Enum.Material.Neon
		streak.Anchored, streak.CanCollide, streak.CanTouch, streak.CanQuery, streak.CastShadow = true, false, false, false, false
		streak.CFrame = CFrame.new(root.Position)
		streak.Parent = workspace
		table.insert(effect.streaks, streak)
		for _, instance in ipairs({ a, b, trail, streak }) do table.insert(effect.items, instance) end
	end
	effects[player] = effect
end

Remote.OnClientEvent:Connect(function(action, payload)
	if action == "DashFX" then start(payload) end
	if action == "DashCancel" then cleanup(payload) end
end)

-- Remove our last offset before the Animator writes this frame's pose.
RunService.PreAnimation:Connect(function()
	for _, effect in pairs(effects) do restore(effect) end
end)

RunService.PreSimulation:Connect(function()
	local now = workspace:GetServerTimeNow()
	for player, effect in pairs(effects) do
		local age = now - effect.began
		if not player.Parent or player.Character ~= effect.character or not effect.root.Parent or age > duration + .18
			or player:GetAttribute("BeingCaptured") then
			cleanup(player)
			continue
		end
		local strength = math.clamp(age/.04, 0, 1) * math.clamp((duration - age)/.16, 0, 1)
		if age < duration then
			for _, joint in ipairs(effect.joints) do
				if joint.Parent then
					local original = joint.Transform
					effect.originals[joint] = original
					joint.Transform = original * (jointPose(joint, strength, effect.root) or CFrame.identity)
				end
			end
		end
		local frame = CFrame.lookAt(effect.root.Position, effect.root.Position + effect.direction)
		for index, ribbon in ipairs(effect.ribbons) do
			local angle = ribbon.angle + age*12
			local offset = Vector3.new(math.cos(angle)*1.5, math.sin(angle)*1.5, .9 + age*3)
			local localFrame = effect.root.CFrame:ToObjectSpace(frame)
			ribbon.a.Position = localFrame:PointToWorldSpace(offset)
			ribbon.b.Position = localFrame:PointToWorldSpace(offset + Vector3.new(.12, .12, 0))
			ribbon.trail.Enabled = age < Config.DashDuration
			local streak = effect.streaks[index]
			streak.CFrame = frame * CFrame.new(offset + Vector3.new(0, 0, 2 + age*12))
			streak.Transparency = age < duration and (.2 + .8*(1 - strength)) or 1
		end
	end
end)
