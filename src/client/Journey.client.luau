local Players=game:GetService("Players")
local Rep=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Starter=game:GetService("StarterGui")
local player=Players.LocalPlayer
local Remote=Rep:WaitForChild("RiftAction")
local Rules=require(Rep:WaitForChild("RiftShared").Rules)
local gui=Instance.new("ScreenGui")
gui.Name,gui.ResetOnSpawn,gui.DisplayOrder="RiftJourney",false,20
gui.Parent=player:WaitForChild("PlayerGui")
local ink,mint,paper,violet=Color3.fromRGB(48,35,82),Color3.fromRGB(145,255,214),Color3.fromRGB(246,245,255),Color3.fromRGB(201,173,255)
local function rounded(obj,radius)
	local c=Instance.new("UICorner") c.CornerRadius,c.Parent=UDim.new(0,radius or 18),obj
end
local function text(parent,name,value,x,y,width,height,size,color)
	local t=Instance.new("TextLabel")
	t.Name,t.Text,t.Position,t.Size=name,value,UDim2.fromOffset(x,y),UDim2.fromOffset(width,height)
	t.BackgroundTransparency,t.TextColor3,t.Font,t.TextSize,t.TextWrapped=1,color or paper,Enum.Font.FredokaOne,size or 17,true
	t.Parent=parent return t
end
local function button(parent,name,value,x,y,width,height,color)
	local b=Instance.new("TextButton")
	b.Name,b.Text,b.Position,b.Size=name,value,UDim2.fromOffset(x,y),UDim2.fromOffset(width,height)
	b.BackgroundColor3,b.TextColor3,b.Font,b.TextSize,b.BorderSizePixel=color or mint,ink,Enum.Font.FredokaOne,16,0
	b.Parent=parent rounded(b) return b
end
local function panel(name,width,height)
	local f=Instance.new("Frame") f.Name,f.Size,f.AnchorPoint=name,UDim2.fromOffset(width,height),Vector2.new(.5,.5)
	f.Position,f.BackgroundColor3,f.BackgroundTransparency,f.BorderSizePixel=UDim2.fromScale(.5,.5),ink,.04,0
	f.Parent=gui rounded(f,24)
	local stroke=Instance.new("UIStroke") stroke.Color,stroke.Transparency,stroke.Thickness,stroke.Parent=violet,.25,2,f
	return f
end
local goals=panel("GoalsPanel",390,430) goals.Visible=false
text(goals,"Title","Rift Goals",20,14,280,36,26,mint).TextXAlignment=Enum.TextXAlignment.Left
local close=button(goals,"Close","×",334,14,40,34,violet)
close.Activated:Connect(function() player:SetAttribute("JourneyMenuOpen",false) end)
local rows={}
for index=1,3 do
	local y=62+(index-1)*79
	local label=text(goals,"Goal"..index,"",20,y,350,27,18) label.TextXAlignment=Enum.TextXAlignment.Left
	local reward=text(goals,"Reward"..index,"",20,y+29,270,19,13,violet) reward.TextXAlignment=Enum.TextXAlignment.Left
	local count=text(goals,"Count"..index,"",300,y+29,70,19,14,mint)
	local track=Instance.new("Frame") track.Name,track.Position,track.Size="GoalTrack",UDim2.fromOffset(20,y+55),UDim2.fromOffset(350,7)
	track.BackgroundColor3,track.BorderSizePixel,track.Parent=Color3.fromRGB(83,65,120),0,goals rounded(track,4)
	local fill=Instance.new("Frame") fill.Name,fill.Size,fill.BackgroundColor3,fill.BorderSizePixel,fill.Parent="Fill",UDim2.fromScale(0,1),mint,0,track rounded(fill,4)
	rows[index]={label=label,reward=reward,count=count,fill=fill}
end
local reset=text(goals,"Reset","",20,301,350,20,12,violet)
local learn=button(goals,"Learn","Learn to Run",20,330,350,36)
learn.Activated:Connect(function() player:SetAttribute("JourneyMenuOpen",false) Remote:FireServer("TutorialStart") end)
local ghostEnabled=true
local ghostToggle=button(goals,"GhostToggle","Parkour Ghost: On",20,378,350,34,violet)
ghostToggle.Activated:Connect(function() ghostEnabled=not ghostEnabled end)
local invite=panel("FirstRun",284,84)
invite.AnchorPoint,invite.Position=Vector2.new(.5,1),UDim2.new(.5,0,1,-106)
text(invite,"Title","Learn to Run?",12,6,260,25,20,mint)
button(invite,"Learn","Train",12,40,124,32).Activated:Connect(function() Remote:FireServer("TutorialStart") end)
button(invite,"Skip","Later",148,40,124,32,violet).Activated:Connect(function() Remote:FireServer("TutorialSkip") end)
local exit=button(gui,"ExitLesson","Skip Lesson",0,0,140,38,violet)
exit.AnchorPoint,exit.Position=Vector2.new(1,0),UDim2.new(1,-12,0,100)
exit.Activated:Connect(function() Remote:FireServer("TutorialSkip") end)
local replay,ghost,body,frameIndex=nil,nil,{},1
local function removeGhost()
	if ghost then ghost:Destroy() end
	ghost,body=nil,{}
end
local function makeGhost()
	ghost=Instance.new("Model") ghost.Name,ghost.Parent="RiftParkourGhost",workspace
	for _,definition in ipairs({{"Head",Vector3.new(1.7,1.7,1.7)},{"Body",Vector3.new(2,2,1)},
		{"LeftArm",Vector3.new(.8,2,.8)},{"RightArm",Vector3.new(.8,2,.8)},
		{"LeftLeg",Vector3.new(.8,2,.8)},{"RightLeg",Vector3.new(.8,2,.8)}}) do
		local part=Instance.new("Part")
		part.Name,part.Size,part.Color,part.Material,part.Transparency=definition[1],definition[2],mint,Enum.Material.SmoothPlastic,.64
		part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery,part.CastShadow=true,false,false,false,false
		part.Parent=ghost body[definition[1]]=part
	end
	local tag=Instance.new("BillboardGui") tag.Name,tag.Adornee,tag.Size,tag.StudsOffset,tag.MaxDistance="GhostName",body.Head,UDim2.fromOffset(100,22),Vector3.new(0,2,0),50
	local label=text(tag,"Name","Your Best",0,0,100,22,13,mint) label.TextStrokeTransparency=.35 tag.Parent=ghost
end
local function frame(value) return CFrame.new(value[2]/10,value[3]/10,value[4]/10)*CFrame.Angles(0,value[5]/1000,0) end
Remote.OnClientEvent:Connect(function(action,data)
	if action=="ParkourGhost" then replay=Rules.sanitizeGhost(data) frameIndex=1 removeGhost() end
end)
local chatWasEnabled
Run.RenderStepped:Connect(function()
	local camera=workspace.CurrentCamera
	if not camera then return end
	local width,height=camera.ViewportSize.X,camera.ViewportSize.Y
	local scale=goals:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale,scale.Parent=math.min(1,(width-24)/390,(height-24)/430),goals
	local role=player:GetAttribute("Role")
	local lobby=(role=="Spectator" or role=="Escaped") and not player:GetAttribute("CoursePractice")
	local tutorial=player:GetAttribute("TutorialActive")==true
	local open=lobby and not tutorial and player:GetAttribute("JourneyMenuOpen")==true
	goals.Visible=open exit.Visible=tutorial
	if open and chatWasEnabled==nil then
		local ok,enabled=pcall(function() return Starter:GetCoreGuiEnabled(Enum.CoreGuiType.Chat) end)
		if ok then chatWasEnabled=enabled Starter:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,false) end
	elseif not open and chatWasEnabled~=nil then
		pcall(function() Starter:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,chatWasEnabled) end) chatWasEnabled=nil
	end
	local hud=player.PlayerGui:FindFirstChild("RiftHUD")
	local other=player:GetAttribute("MasteryMenuOpen") or (hud and ((hud:FindFirstChild("Shop") and hud.Shop.Visible) or (hud:FindFirstChild("Help") and hud.Help.Visible) or (hud:FindFirstChild("Vote") and hud.Vote.Visible)))
	invite.Visible=lobby and not tutorial and not open and not other and not player:GetAttribute("ParkourActive")
		and player:GetAttribute("TutorialSeen")==false and player:GetAttribute("GoalText1")~=nil
	if not lobby then player:SetAttribute("JourneyMenuOpen",false) end
	for index,row in ipairs(rows) do
		local progress,target=player:GetAttribute("GoalProgress"..index) or 0,player:GetAttribute("GoalTarget"..index) or 1
		row.label.Text=player:GetAttribute("GoalText"..index) or "Loading..."
		row.reward.Text=player:GetAttribute("GoalDone"..index) and "Reward earned!" or tostring(player:GetAttribute("GoalReward"..index) or 0).." Coins"
		row.count.Text=string.format("%d / %d",progress,target)
		row.fill.Size=UDim2.fromScale(math.clamp(progress/target,0,1),1)
	end
	local seconds=math.max(0,(player:GetAttribute("ChallengesResetAt") or os.time())-os.time())
	reset.Text=string.format("New goals in %dh %dm",math.floor(seconds/3600),math.floor(seconds%3600/60))
	learn.Text=player:GetAttribute("TutorialCompleted") and "Replay Training" or "Learn to Run"
	ghostToggle.Text="Parkour Ghost: "..(ghostEnabled and "On" or "Off")..(player:GetAttribute("HasParkourGhost") and "" or " / Set a Best!")
	local elapsed=workspace:GetServerTimeNow()-(player:GetAttribute("ParkourStartedAt") or 0)
	if not ghostEnabled or not replay or not player:GetAttribute("ParkourActive") or elapsed<0 or elapsed*1000>replay.durationMs then removeGhost() return end
	if not ghost then makeGhost() frameIndex=1 end
	local frames=replay.frames
	if elapsed*1000<frames[frameIndex][1] then frameIndex=1 end
	while frameIndex<#frames-1 and elapsed*1000>frames[frameIndex+1][1] do frameIndex+=1 end
	local a,b=frames[frameIndex],frames[frameIndex+1]
	local pose=frame(a):Lerp(frame(b),math.clamp((elapsed*1000-a[1])/(b[1]-a[1]),0,1))
	local swing=math.sin(elapsed*12)*.65
	body.Body.CFrame=pose body.Head.CFrame=pose*CFrame.new(0,1.6,0)
	body.LeftArm.CFrame=pose*CFrame.new(-1.45,0,0)*CFrame.Angles(swing,0,0)
	body.RightArm.CFrame=pose*CFrame.new(1.45,0,0)*CFrame.Angles(-swing,0,0)
	body.LeftLeg.CFrame=pose*CFrame.new(-.5,-2,0)*CFrame.Angles(-swing,0,0)
	body.RightLeg.CFrame=pose*CFrame.new(.5,-2,0)*CFrame.Angles(swing,0,0)
end)
Remote:FireServer("JourneyReady")
