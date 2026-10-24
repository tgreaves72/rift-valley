local Run=game:GetService("RunService")
assert(Run:IsStudio())
local Rep=game:GetService("ReplicatedStorage")
local p=game:GetService("Players").LocalPlayer
local Remote=Rep:WaitForChild("RiftAction")
local lastMode=""
local retrySent=false
Run.Heartbeat:Connect(function()
	local mode=Rep:GetAttribute("ActivityProbeMode")
	if mode~=lastMode then
		lastMode=mode
		if mode=="Mastery" then p:SetAttribute("MasteryMenuOpen",true)
		elseif mode=="Parkour" then
			p:SetAttribute("MasteryMenuOpen",false)
			-- Keep this fixture out of automatic race enrollment while testing.
			Remote:FireServer("MasteryMenu",true)
		elseif mode=="Lounge" then Remote:FireServer("VisitVIP")
		elseif mode=="Fire" then
			local char=p.Character
			local bag=p:FindFirstChildOfClass("Backpack")
			local tool=(char and char:FindFirstChild("Rift Blaster")) or (bag and bag:FindFirstChild("Rift Blaster"))
			if tool then char:FindFirstChildOfClass("Humanoid"):EquipTool(tool) end
		end
	end
	if mode=="Mastery" then
		local gui=p.PlayerGui:FindFirstChild("RiftMastery")
		if gui and gui.Menu.Visible then
			local count=0
			for _,v in ipairs(gui.Menu:GetDescendants()) do
				if v:IsA("ViewportFrame") and v.CurrentCamera and v:FindFirstChildOfClass("WorldModel") then count+=1 end
			end
			if count==6 then p:SetAttribute("StudioMastery3DReady",true) end
		end
	elseif mode=="Parkour" and p:GetAttribute("ParkourRetryAvailable") and not retrySent then
		retrySent=true
		Remote:FireServer("ParkourRetry")
	elseif mode=="Fire" then
		local tool=p.Character and p.Character:FindFirstChild("Rift Blaster")
		local trigger=Rep:GetAttribute("ActivityProbeTrigger")
		if tool and tool.Enabled and trigger and p:GetAttribute("StudioLastTrigger")~=trigger then
			p:SetAttribute("StudioLastTrigger",trigger)
			tool:Activate()
		end
	end
end)
-- Client-only UI evidence is reported separately from server damage checks.
task.spawn(function()
	while not p:GetAttribute("StudioMastery3DReady") do task.wait(.1) end
	print("[RiftActivityUI] "..game:GetService("HttpService"):JSONEncode({version="0.14.0",viewportModels=6,masteryVisible=true,passed=true}))
end)
