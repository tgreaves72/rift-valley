local Players=game:GetService("Players")
local Rep=game:GetService("ReplicatedStorage")
local Input=game:GetService("UserInputService")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local Remote=Rep:WaitForChild("RiftAction")
local gui=Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn,gui.Parent="RiftVIPGear",false,player:WaitForChild("PlayerGui")
local cross=Instance.new("TextLabel")
cross.Name,cross.Size,cross.Position,cross.AnchorPoint="Crosshair",UDim2.fromOffset(28,28),UDim2.fromScale(.5,.5),Vector2.new(.5,.5)
cross.BackgroundTransparency,cross.Text,cross.TextSize,cross.TextColor3,cross.Parent=1,"+",26,Color3.fromRGB(145,255,214),gui
local hint=Instance.new("TextLabel")
hint.Name,hint.Size,hint.Position,hint.AnchorPoint="Hint",UDim2.fromOffset(210,28),UDim2.new(.5,0,1,-124),Vector2.new(.5,0)
hint.BackgroundTransparency,hint.Font,hint.TextSize,hint.TextColor3,hint.Parent=1,Enum.Font.FredokaOne,15,Color3.fromRGB(255,221,137),gui
local connected=setmetatable({}, {__mode="k"})
local function watch(tool)
	if not tool:IsA("Tool") or not tool:GetAttribute("RiftVIPGear") or connected[tool] then return end
	connected[tool]=true
	tool.Activated:Connect(function()
		if tool:GetAttribute("RiftVIPGear")~="Blaster" or not player:GetAttribute("VIPGearActive") then return end
		local camera=workspace.CurrentCamera
		if not camera then return end
		local aim
		if Input.TouchEnabled or Input.GamepadEnabled then aim=camera.CFrame.Position+camera.CFrame.LookVector*180
		else aim=player:GetMouse().Hit.Position end
		Remote:FireServer("VIPFire",aim)
	end)
end
local function characterAdded(character)
	for _,tool in ipairs(character:GetChildren()) do watch(tool) end
	character.ChildAdded:Connect(watch)
end
if player.Character then characterAdded(player.Character) end
player.CharacterAdded:Connect(characterAdded)
Run.RenderStepped:Connect(function()
	local equipped=player.Character and player.Character:FindFirstChildOfClass("Tool")
	local kind=equipped and equipped:GetAttribute("RiftVIPGear")
	local active=player:GetAttribute("VIPGearActive")==true
	cross.Visible=kind=="Blaster" and active and (Input.TouchEnabled or Input.GamepadEnabled)
	hint.Visible=kind~=nil
	hint.Text=active and (kind=="Blaster" and "Tap / Click to Fire" or (kind=="Speed" and "Speed Coil" or "Jump Coil")) or "VIP Arena only"
end)
Remote.OnClientEvent:Connect(function(action,data)
	if action~="VIPShot" or type(data)~="table" or typeof(data.from)~="Vector3" or typeof(data.to)~="Vector3" then return end
	local camera=workspace.CurrentCamera
	if not camera or (camera.CFrame.Position-data.from).Magnitude>180 then return end
	local length=(data.to-data.from).Magnitude
	if length<.01 then return end
	local beam=Instance.new("Part")
	beam.Name,beam.Size,beam.CFrame="VIPPulse",Vector3.new(.12,.12,length),CFrame.lookAt((data.from+data.to)/2,data.to)
	beam.Anchored,beam.CanCollide,beam.CanTouch,beam.CanQuery=true,false,false,false
	beam.Material,beam.Color,beam.Parent=Enum.Material.Neon,Color3.fromRGB(68,174,215),workspace
	Debris:AddItem(beam,.1)
end)
