local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local player = Players.LocalPlayer
local icons = {}
local function track(anchor)
	if not anchor or not anchor:IsA("BasePart") or icons[anchor] then return end
	local marker = anchor:FindFirstChild("HoverIcon")
	if not marker or not marker:FindFirstChild("Glyph") or not marker:FindFirstChild("Title") or not marker:FindFirstChild("Tint") then return end
	if marker:FindFirstChild("Kind") or marker:FindFirstChild("NativeVisual") then return end
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee, gui.Size, gui.MaxDistance = "RiftHoverIcon", anchor, UDim2.fromOffset(176, 94), 24
	gui.AlwaysOnTop, gui.Active = true, true
	local button = Instance.new("TextButton")
	button.Size, button.Position = UDim2.fromOffset(50, 50), UDim2.fromOffset(63, 0)
	button.Text, button.Font, button.TextSize = marker.Glyph.Value, Enum.Font.FredokaOne, 32
	button.BackgroundColor3, button.TextColor3 = marker.Tint.Value, Color3.fromRGB(48, 35, 82)
	button.BorderSizePixel, button.Parent = 0, gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius, corner.Parent = UDim.new(.5, 0), button
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Thickness, stroke.Parent = marker.Tint.Value, 2, button
	local title = Instance.new("TextLabel")
	title.Size, title.Position, title.BackgroundTransparency = UDim2.fromOffset(176, 23), UDim2.fromOffset(0, 53), 1
	local names = { ["RECHARGE / AUTO"] = "Dash", ["VALLEY OUTFITTERS"] = "Shop", ["VIP SKY LOUNGE"] = "VIP", ["STYLE STUDIO"] = "Styles", ["RIFT PARKOUR"] = "Parkour", ["RETURN TO OVERLOOK"] = "Lobby", ["RETURN TO LOBBY"] = "Lobby" }
	title.Text, title.Font, title.TextSize = names[marker.Title.Value] or marker.Title.Value, Enum.Font.FredokaOne, 14
	title.TextColor3, title.TextStrokeTransparency, title.Parent = Color3.fromRGB(240, 240, 228), .35, gui
	local hint = Instance.new("TextLabel")
	hint.Size, hint.Position, hint.BackgroundTransparency = UDim2.fromOffset(176, 18), UDim2.fromOffset(0, 75), 1
	hint.Text, hint.Font, hint.TextSize = "", Enum.Font.GothamBold, 10
	hint.TextColor3, hint.Parent = marker.Tint.Value, gui
	local prompt = anchor:FindFirstChildOfClass("ProximityPrompt")
	button.Activated:Connect(function()
		if prompt and button.Active then prompt:InputHoldBegin() prompt:InputHoldEnd() end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")
	icons[anchor] = { gui = gui, button = button, prompt = prompt, hint = hint, seed = math.random()*6 }
end
for _, item in ipairs(workspace:GetDescendants()) do track(item) end
workspace.DescendantAdded:Connect(function(item)
	if item:IsA("BasePart") then task.defer(track, item)
	elseif item.Name == "HoverIcon" then task.defer(track, item.Parent) end
	if item.Parent and item.Parent.Name == "HoverIcon" then task.defer(track, item.Parent.Parent) end
end)
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for anchor, icon in pairs(icons) do
		if not anchor.Parent then icon.gui:Destroy() icons[anchor] = nil continue end
		local distance = root and (root.Position - anchor.Position).Magnitude or math.huge
		local role = player:GetAttribute("Role")
		local canUse = icon.prompt and distance <= icon.prompt.MaxActivationDistance and (role == "Spectator" or role == "Escaped")
		icon.gui.Enabled = distance < 24
		icon.button.Active, icon.button.Selectable = canUse == true, canUse == true
		icon.gui.StudsOffset = Vector3.new(0, math.sin(os.clock()*2 + icon.seed)*.2, 0)
		icon.hint.Text = canUse and (Input.TouchEnabled and "Tap" or (Input.GamepadEnabled and "X" or "E")) or ""
	end
end)
