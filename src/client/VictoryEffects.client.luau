local Replicated = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Remote = Replicated:WaitForChild("RiftAction")
local rng = Random.new()
local colors = { Bloom=Color3.fromRGB(123,255,176),Sparks=Color3.fromRGB(255,187,125),Fireworks=Color3.fromRGB(140,209,255),Confetti=Color3.fromRGB(201,173,255) }
local live = 0
Remote.OnClientEvent:Connect(function(action,data)
	if action ~= "Victory" or type(data) ~= "table" or typeof(data.position) ~= "Vector3" or not colors[data.effect] then return end
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position-data.position).Magnitude > 140 or live >= 90 then return end
	local count = data.effect == "Fireworks" and 30 or (data.effect == "Bloom" and 16 or 20)
	for index=1,count do
		if live >= 90 then break end
		local part = Instance.new(data.effect == "Bloom" and "WedgePart" or "Part")
		part.Name,part.Anchored,part.CanCollide,part.CanQuery,part.CanTouch,part.CastShadow = "MasteryVictory",true,false,false,false,false
		part.Color,part.Material = colors[data.effect],Enum.Material.Neon
		part.Size = data.effect == "Bloom" and Vector3.new(.5,1.2,.5) or (data.effect == "Sparks" and Vector3.new(.16,1.1,.16) or Vector3.new(.3,.3,.3))
		local angle = index*math.pi*2/count
		local center = data.position+Vector3.new(0,2,0)
		if data.effect == "Fireworks" then center += Vector3.new(math.floor((index-1)/10)*4-4,6+index%3,0) end
		part.CFrame,part.Parent = CFrame.new(center),workspace
		local radius = data.effect == "Bloom" and 5 or 8
		local target = center+Vector3.new(math.cos(angle)*radius,rng:NextNumber(2,8),math.sin(angle)*radius)
		TweenService:Create(part,TweenInfo.new(1.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(target)*CFrame.Angles(angle,angle*.5,angle),Transparency=1}):Play()
		live += 1
		Debris:AddItem(part,1.3)
		task.delay(1.35,function() live=math.max(0,live-1) end)
	end
end)
