local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Ids = require(Replicated:WaitForChild("RiftShared").MusicIds)
local player = Players.LocalPlayer
local muted = false
local current, key, generation = nil, nil, 0
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.Parent = "RiftMusic", false, player:WaitForChild("PlayerGui")
local button = Instance.new("TextButton")
button.Size, button.Position = UDim2.fromOffset(90, 29), UDim2.new(1, -105, 1, -42)
button.Text, button.Font, button.TextSize = "♫ ON", Enum.Font.FredokaOne, 13
button.BackgroundColor3, button.TextColor3 = Color3.fromRGB(48, 35, 82), Color3.fromRGB(201, 173, 255)
button.BorderSizePixel, button.Parent = 0, gui
local corner = Instance.new("UICorner")
corner.CornerRadius, corner.Parent = UDim.new(0, 15), button

local function update()
	local phase, role = Replicated:GetAttribute("Phase"), player:GetAttribute("Role")
	local training = player:GetAttribute("CoursePractice") == true
	local racing = training or ((role == "Runner" or role == "Catcher" or role == "Captured") and (phase == "Ready" or phase == "Crossing"))
	local nextKey = training and player:GetAttribute("PracticeMapId") or (racing and Replicated:GetAttribute("MapId") or "Lobby")
	if not Ids[nextKey] then button.Text = "♫ OFF" return end
	button.Text = muted and "♫ OFF" or "♫ ON"
	if nextKey == key then
		if current then TweenService:Create(current, TweenInfo.new(.35), { Volume = muted and 0 or (racing and .3 or .22) }):Play() end
		return
	end
	key, generation = nextKey, generation + 1
	local token, old = generation, current
	local sound = Instance.new("Sound")
	sound.Name, sound.SoundId, sound.Looped, sound.Volume = "RiftScore_" .. nextKey, "rbxassetid://" .. Ids[nextKey], true, 0
	sound.Parent = SoundService
	current = sound
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(1.5), { Volume = muted and 0 or (racing and .3 or .22) }):Play()
	if old then
		TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
		task.delay(1.6, function() if old ~= current then old:Destroy() end end)
	end
	task.delay(12, function()
		if token == generation and sound.Parent and not sound.IsLoaded then button.Text = "♫ OFF" end
	end)
end
button.Activated:Connect(function() muted = not muted update() end)
for _, name in ipairs({ "Phase", "MapId" }) do Replicated:GetAttributeChangedSignal(name):Connect(update) end
player:GetAttributeChangedSignal("Role"):Connect(update)
player:GetAttributeChangedSignal("CoursePractice"):Connect(update)
player:GetAttributeChangedSignal("PracticeMapId"):Connect(update)
update()
