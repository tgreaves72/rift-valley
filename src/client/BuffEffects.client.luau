-- Native 3D objects remain visible without a GUI. Only their cosmetic motion
-- and per-player collection cooldown brightness run on the client.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Remote = game:GetService("ReplicatedStorage"):WaitForChild("RiftAction")
local player = Players.LocalPlayer
local models = {}
local function track(model)
	if not model or not model:IsA("Model") or models[model] or not model.PrimaryPart then return end
	local vote = model.Name == "MapVoteVisual" and model:FindFirstChild("MapId")
	local coin = model.Name == "CoinVisual"
	if model.Name ~= "BuffVisual" and not vote and not coin then return end
	local marker = model.Parent and model.Parent:FindFirstChild("HoverIcon")
	local kind = marker and marker:FindFirstChild("Kind")
	if not kind and not vote and not coin then return end
	local parts = {}
	for _,part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") and part.Transparency < 1 then table.insert(parts,part) end end
	models[model] = {base=model.PrimaryPart.CFrame,kind=coin and "Coin" or (vote and "MapVote" or kind.Value),mapId=vote and vote.Value,
		anchor=model.Parent,parts=parts,light=model.PrimaryPart:FindFirstChild(coin and "CoinGlow" or (vote and "VoteGlow" or "BuffGlow")),seed=math.random()*6}
end
for _,obj in ipairs(workspace:GetDescendants()) do track(obj) end
workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") then task.defer(track,obj)
	elseif obj.Name == "BuffCore" or obj.Name == "VoteCore" or obj.Name == "CoinCore" or obj.Name == "MapId" then task.defer(track,obj.Parent) end
end)
Remote.OnClientEvent:Connect(function(action, anchor)
	if action ~= "Crystal" then return end
	for _,record in pairs(models) do
		if record.kind == "Coin" and record.anchor == anchor then
			record.collected = true
			for _,part in ipairs(record.parts) do part.LocalTransparencyModifier = 1 end
			if record.light then record.light.Enabled = false end
		end
	end
end)
local last = 0
RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	if now-last < 1/30 then return end
	last = now
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for model,record in pairs(models) do
		if not model.Parent then models[model] = nil continue end
		if not root or (root.Position-record.base.Position).Magnitude > 90 then continue end
		local voting = record.kind == "MapVote"
		local cooling = not voting and record.kind ~= "Coin" and now < (player:GetAttribute(record.kind .. "BuffReadyAt") or 0)
		for _,part in ipairs(record.parts) do part.LocalTransparencyModifier = record.collected and 1 or (cooling and .65 or 0) end
		local selected = voting and player:GetAttribute("MapVote") == record.mapId
		if record.light then
			record.light.Enabled = not record.collected
			record.light.Brightness = cooling and .2 or (selected and 2.25 or (1.35+.35*math.sin(now*3+record.seed)))
		end
		-- Gentle height motion keeps every icon's original orientation fixed.
		if not record.collected then model:PivotTo(record.base*CFrame.new(0,math.sin(now*2+record.seed)*.3,0)) end
	end
end)
