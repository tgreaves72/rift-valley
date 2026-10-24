local Players=game:GetService("Players")
local Replicated=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Lighting=game:GetService("Lighting")
local player=Players.LocalPlayer
local backdrop=workspace:WaitForChild("RiftBackdrop")
local ribbons,shards,stars={},{},{}
for _,part in ipairs(backdrop:GetChildren()) do
	local list=part.Name=="AuroraRibbon" and ribbons or (part.Name=="FloatingShard" and shards or (part.Name=="RiftStar" and stars))
	if list then table.insert(list,{part=part,frame=part.CFrame,seed=#list*.71}) end
end
local themes={Lobby=Color3.fromRGB(151,128,225),CrystalGrove=Color3.fromRGB(107,228,192),SunsetRuins=Color3.fromRGB(240,168,125),NeonHarbor=Color3.fromRGB(133,157,244)}
local tint=themes.Lobby
local function theme()
	local role,phase=player:GetAttribute("Role"),Replicated:GetAttribute("Phase")
	local racing=(role=="Runner" or role=="Catcher" or role=="Captured") and (phase=="Ready" or phase=="Crossing")
	local id=player:GetAttribute("CoursePractice") and player:GetAttribute("PracticeMapId") or (racing and Replicated:GetAttribute("MapId") or "Lobby")
	tint=themes[id] or themes.Lobby
	for _,item in ipairs(ribbons) do item.part.Color=tint end
	local mist=Lighting:FindFirstChild("ValleyMist")
	if mist then mist.Color=Color3.fromRGB(175,165,198):Lerp(tint,.17) end
end
for _,name in ipairs({"Phase","MapId"}) do Replicated:GetAttributeChangedSignal(name):Connect(theme) end
for _,name in ipairs({"Role","CoursePractice","PracticeMapId"}) do player:GetAttributeChangedSignal(name):Connect(theme) end
theme()
local elapsed,accumulated,cursor=0,0,0
Run.Heartbeat:Connect(function(dt)
	elapsed+=dt accumulated+=dt
	if accumulated<.1 then return end accumulated=0
	for _,item in ipairs(ribbons) do
		item.part.CFrame=item.frame*CFrame.new(math.sin(elapsed*.07+item.seed)*6,math.sin(elapsed*.19+item.seed)*3,0)
		item.part.Transparency=.4+math.sin(elapsed*.3+item.seed)*.16
	end
	for _,item in ipairs(shards) do item.part.CFrame=item.frame*CFrame.new(0,math.sin(elapsed*.23+item.seed)*2.2,0) end
	-- Rotate through four stars per update rather than updating every star each frame.
	for _=1,math.min(4,#stars) do
		cursor=cursor%#stars+1
		local item=stars[cursor]
		item.part.Transparency=.12+(math.sin(elapsed*.6+item.seed)+1)*.24
	end
end)
