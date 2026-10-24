local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Replicated = game:GetService("ReplicatedStorage")
local Remote = Replicated:WaitForChild("RiftAction")
local localPlayer = Players.LocalPlayer
local effects = {}

local function finish(id)
	local effect = effects[id]
	if not effect then return end
	effects[id] = nil
	if effect.clone then effect.clone:Destroy() end
	for part, size in pairs(effect.mouthSizes) do if part.Parent then part.Size = size end end
	if effect.camera and workspace.CurrentCamera then
		workspace.CurrentCamera.CameraType = effect.camera.type
		workspace.CurrentCamera.CameraSubject = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid") or effect.camera.subject
		workspace.CurrentCamera.FieldOfView = effect.camera.fov
	end
end

Remote.OnClientEvent:Connect(function(action, payload)
	if action == "CaptureEnd" then finish(payload) return end
	if action ~= "Capture" or not payload.victim.Character or not payload.model.Parent then return end
	local victim = payload.victim
	finish(victim.UserId)
	local source = victim.Character
	local archivable = source.Archivable
	source.Archivable = true
	local ok, clone = pcall(function() return source:Clone() end)
	source.Archivable = archivable
	if not ok or not clone then return end
	for _, item in ipairs(clone:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") or item:IsA("Humanoid") or item:IsA("Highlight") then item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery = true, false, false, false
			item.Transparency = item:GetAttribute("CaptureTransparency") or (item.Name == "HumanoidRootPart" and 1 or 0)
		elseif item:IsA("Decal") or item:IsA("Texture") then item.Transparency = item:GetAttribute("CaptureTransparency") or 0 end
	end
	clone.Name = "LocalCaptureVictim"
	clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart")
	if not clone.PrimaryPart then clone:Destroy() return end
	clone.Parent = workspace
	local effect = { clone = clone, model = payload.model, started = payload.started, duration = payload.duration, mouthSizes = {} }
	for _, name in ipairs({ "Mouth", "LowerJaw", "Tongue" }) do
		local part = payload.model:FindFirstChild(name)
		if part then effect.mouthSizes[part] = part.Size end
	end
	if victim == localPlayer and workspace.CurrentCamera then
		local camera = workspace.CurrentCamera
		effect.camera = { type = camera.CameraType, subject = camera.CameraSubject, fov = camera.FieldOfView }
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = 68
	end
	effects[victim.UserId] = effect
end)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for id, effect in pairs(effects) do
		local root, head = effect.model.PrimaryPart, effect.model:FindFirstChild("Head")
		if not effect.model.Parent or not root or not head or now - effect.started > effect.duration + .5 then finish(id) continue end
		local elapsed = now - effect.started
		local lift = math.clamp(elapsed / 1.1, 0, 1)
		lift = lift * lift * (3 - 2 * lift)
		local consume = math.clamp((elapsed - 1.1) / .7, 0, 1)
		local mouth = head.CFrame:PointToWorldSpace(Vector3.new(0, -.6, -1.25))
		local held = root.CFrame:PointToWorldSpace(Vector3.new(0, .3, -3))
		local position = held:Lerp(mouth + Vector3.new(0, .6 * (1 - consume), 0), lift)
		effect.clone:ScaleTo(math.max(.04, 1 - consume * .96))
		effect.clone:PivotTo(CFrame.lookAt(position, position - root.CFrame.LookVector))
		for part, size in pairs(effect.mouthSizes) do
			part.Size = size * Vector3.new(1 + lift*.2, 1 + lift * (part.Name == "Mouth" and 2.6 or .6), 1)
		end
		if consume >= 1 then
			for _, part in ipairs(effect.clone:GetDescendants()) do if part:IsA("BasePart") or part:IsA("Decal") then part.Transparency = 1 end end
		end
		if effect.camera and workspace.CurrentCamera then
			workspace.CurrentCamera.CFrame = CFrame.lookAt(root.CFrame:PointToWorldSpace(Vector3.new(8, 5.5, -10)), root.Position + Vector3.new(0, 2, 0))
		end
	end
end)
localPlayer.CharacterAdded:Connect(function() finish(localPlayer.UserId) end)
