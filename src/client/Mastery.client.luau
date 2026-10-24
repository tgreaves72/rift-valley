local Players = game:GetService("Players")
local Replicated = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local Config = require(Replicated:WaitForChild("RiftShared").Config)
local Remote = Replicated:WaitForChild("RiftAction")
local ink, paper, mint = Color3.fromRGB(48,35,82), Color3.fromRGB(246,245,255), Color3.fromRGB(145,255,214)
local violet, muted = Color3.fromRGB(201,173,255), Color3.fromRGB(185,177,216)
local medalColors = { Color3.fromRGB(219,161,120), Color3.fromRGB(211,226,250), Color3.fromRGB(255,221,137) }
local medalNames = { "Bronze", "Silver", "Gold" }
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior, gui.Parent = "RiftMastery", false, Enum.ZIndexBehavior.Sibling, player:WaitForChild("PlayerGui")
gui.DisplayOrder = 3
local function round(parent,radius)
	local corner = Instance.new("UICorner") corner.CornerRadius,corner.Parent = UDim.new(0,radius or 20),parent
end
local function frame(name,w,h,parent)
	local item = Instance.new("Frame")
	item.Name,item.Size,item.BackgroundColor3,item.BorderSizePixel,item.Parent = name,UDim2.fromOffset(w,h),ink,0,parent or gui
	round(item)
	local edge=Instance.new("UIStroke")
	edge.Name,edge.Color,edge.Transparency,edge.Thickness,edge.Parent="Glow",violet,.55,1.5,item
	return item
end

local function sculpture(parent,name,x,y,w,h,trophy)
	local view=Instance.new("ViewportFrame")
	view.Name,view.Position,view.Size,view.BackgroundTransparency=name,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h),1
	view.Ambient,view.LightColor,view.LightDirection=Color3.fromRGB(60,52,82),Color3.fromRGB(180,165,140),Vector3.new(-1,-1,-1)
	view.Parent=parent
	local world=Instance.new("WorldModel") world.Parent=view
	local camera=Instance.new("Camera")
	camera.CFrame,camera.FieldOfView,camera.Parent=CFrame.lookAt(Vector3.new(2,1.2,6),Vector3.new(0,0,0)),30,view
	view.CurrentCamera=camera
	local colored={}
	local function piece(size,offset,color,shape,tilt)
		local p=Instance.new("Part")
		p.Size,p.CFrame,p.Color=size,CFrame.new(offset)*(tilt or CFrame.identity),color
		p.Anchored,p.CanCollide,p.Material=true,false,Enum.Material.SmoothPlastic
		if shape then p.Shape=shape end
		p.Parent=world
		table.insert(colored,p)
		return p
	end
	local gold=medalColors[3]
	if trophy then
		piece(Vector3.new(2.2,.35,1.4),Vector3.new(0,-1.3,0),violet)
		piece(Vector3.new(.35,.9,.35),Vector3.new(0,-.7,0),gold)
		piece(Vector3.new(1.8,1.3,1.1),Vector3.new(0,.25,0),gold)
		piece(Vector3.new(2,.18,1.3),Vector3.new(0,.95,0),mint)
		for side=-1,1,2 do
			for index=0,7 do
				local a=index*math.pi/4
				piece(Vector3.new(.35,.2,.3),Vector3.new(side*1+math.cos(a)*.5,.3+math.sin(a)*.6,0),gold,nil,CFrame.Angles(0,0,a))
			end
		end
	else
		piece(Vector3.new(.28,2.5,2.5),Vector3.zero,gold,Enum.PartType.Cylinder,CFrame.Angles(0,math.pi/2,0))
		piece(Vector3.new(.16,2.05,2.05),Vector3.new(0,0,.2),gold,Enum.PartType.Cylinder,CFrame.Angles(0,math.pi/2,0))
		local rune=piece(Vector3.new(.85,.85,.18),Vector3.new(0,0,.36),paper,nil,CFrame.Angles(0,0,math.pi/4))
		table.remove(colored,table.find(colored,rune))
	end
	return view,colored
end
local function text(parent,name,value,x,y,w,h,size,color)
	local label = Instance.new("TextLabel")
	label.Name,label.Text,label.Position,label.Size = name,value,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
	label.BackgroundTransparency,label.Font,label.TextSize = 1,Enum.Font.FredokaOne,size
	label.TextColor3,label.TextWrapped,label.TextXAlignment,label.Parent = color or paper,true,Enum.TextXAlignment.Left,parent
	return label
end
local function button(parent,name,value,x,y,w,h,color)
	local item = Instance.new("TextButton")
	item.Name,item.Text,item.Position,item.Size = name,value,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
	item.Font,item.TextSize,item.TextColor3,item.BackgroundColor3 = Enum.Font.FredokaOne,14,ink,color or mint
	item.BorderSizePixel,item.Parent = 0,parent
	round(item,14)
	return item
end
local menu = frame("Menu",460,548)
menu.AnchorPoint,menu.Position,menu.Visible = Vector2.new(.5,.5),UDim2.fromScale(.5,.5),false
local chatBefore,chatHidden=nil,false
local function syncChat()
	if menu.Visible and not chatHidden then
		local ok,value=pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat) end)
		if ok then
			chatBefore=value
			chatHidden=pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,false) end)
		end
	elseif not menu.Visible and chatHidden then
		if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,chatBefore) end) then chatHidden=false end
	end
end
local outline = menu.Glow outline.Color,outline.Thickness,outline.Transparency = violet,2,.2
sculpture(menu,"MasteryTrophy",8,2,66,58,true)
text(menu,"Title","Rift Mastery",78,12,195,38,25,mint)
local points = text(menu,"Points","0 / 45",279,16,92,30,20,medalColors[3])
button(menu,"Close","X",394,15,48,32,violet).Activated:Connect(function() player:SetAttribute("MasteryMenuOpen",false) end)
local selected = Config.Maps[1].id
local themes, rows = {}, {}
for index,map in ipairs(Config.Maps) do
	local item = button(menu,map.id,map.name,12+(index-1)*147,60,142,36,Color3.fromRGB(unpack(map.rgb)))
	item.TextSize = 13
	themes[map.id] = item
	item.Activated:Connect(function() selected=map.id player:SetAttribute("MasterySelectedMap",selected) end)
end
for stage,course in ipairs(Config.Courses) do
	local row = frame("Course"..stage,436,73,menu)
	row.Position,row.BackgroundColor3 = UDim2.fromOffset(12,105+(stage-1)*76),Color3.fromRGB(64,50,99)
	local badge,medalParts = sculpture(row,"Medal",5,10,48,48,false)
	text(row,"Name",course.name,58,5,256,24,17,paper)
	local best = text(row,"Best","No chase time yet",58,29,252,19,12,muted)
	local target = text(row,"Targets","",58,50,252,18,11,medalColors[3])
	local play = button(row,"Practice","Practice",321,15,104,42)
	play.Activated:Connect(function()
		if not play.Active then return end
		Remote:FireServer("PracticeCourse",{mapId=selected,stage=stage})
	end)
	rows[stage] = {badge=badge,medalParts=medalParts,best=best,target=target,play=play}
end
local footer = text(menu,"Hint","Medals come from chase runs.",18,490,280,22,13,muted)
local rewards = button(menu,"Rewards","Rewards",322,490,120,40,violet)
rewards.Activated:Connect(function()
	player:SetAttribute("MasteryMenuOpen",false)
	player:SetAttribute("MasteryRewardsOpen",true)
end)
text(menu,"SaveStatus","",18,517,290,18,11,muted)
local function allowed()
	local role = player:GetAttribute("Role")
	return role == "Spectator" or role == "Escaped" or player:GetAttribute("CoursePractice") == true
end
local function refresh()
	menu.Visible = player:GetAttribute("MasteryMenuOpen") == true and allowed()
	points.Text = tostring(player:GetAttribute("MedalPoints") or 0) .. " / 45"
	menu.SaveStatus.Text = player:GetAttribute("SaveStatus") or "Loading progress..."
	for _,map in ipairs(Config.Maps) do
		themes[map.id].BackgroundTransparency = map.id == selected and 0 or .55
	end
	for stage,row in ipairs(rows) do
		local key = selected .. "_" .. stage
		local medal, best = player:GetAttribute("Medal_" .. key) or 0, player:GetAttribute("Best_" .. key)
		row.badge:SetAttribute("MedalRank",medal)
		for _,part in ipairs(row.medalParts) do part.Color=medalColors[medal] or muted end
		local practiceBest = player:GetAttribute("PracticeBest_" .. key)
		row.best.Text = best and string.format("Best %.2fs",best) or (practiceBest and string.format("Practice %.2fs",practiceBest) or "No chase time yet")
		local scale = Config.Mastery.ThemeScale[selected]
		row.target.Text = string.format("Gold %.1fs / Silver %.1fs",Config.Mastery.GoldSeconds[stage]*scale,Config.Mastery.SilverSeconds[stage]*scale)
		local reached = stage <= (player:GetAttribute("UnlockedCourse") or 1)
		row.play.Active = reached and (player:GetAttribute("Role") ~= "Escaped")
		row.play.Selectable,row.play.AutoButtonColor = row.play.Active,row.play.Active
		row.play.BackgroundColor3 = row.play.Active and mint or muted
		row.play.Text = not reached and "Reach course "..stage or (row.play.Active and "Practice" or "After Run")
	end
	footer.Text = player:GetAttribute("CoursePractice") and "Practice times stay separate." or "Medals come from chase runs."
end

local card = frame("FinishCard",248,56)
card.AnchorPoint,card.Position,card.Visible = Vector2.new(.5,0),UDim2.new(.5,0,1,-212),false
local cardOutline = Instance.new("UIStroke")
cardOutline.Color,cardOutline.Thickness,cardOutline.Transparency,cardOutline.Parent = violet,1,.65,card
local medallion = text(card,"Medallion","G",10,12,32,32,18,ink)
medallion.BackgroundTransparency,medallion.TextXAlignment = 0,Enum.TextXAlignment.Center round(medallion,16)
local heading = text(card,"Heading","Gold Finish!",52,7,184,22,17,mint)
local resultTime = text(card,"Time","",52,30,90,17,13,paper)
local improvement = text(card,"Improvement","",146,30,90,17,11,muted)
local cardToken = 0
local function cardPosition(view)
	local compact = view and view.ViewportSize.X < 820
	if compact and view.ViewportSize.Y < 480 then return UDim2.new(.5,0,0,94) end
	return UDim2.new(.5,0,1,-212)
end
local controls = frame("PracticeControls",264,44)
controls.Position,controls.Visible = UDim2.fromOffset(14,88),false
button(controls,"Retry","Retry",6,5,80,34).Activated:Connect(function() Remote:FireServer("PracticeRetry") end)
button(controls,"Courses","Courses",92,5,80,34,violet).Activated:Connect(function() player:SetAttribute("MasteryMenuOpen",true) end)
button(controls,"Lobby","Lobby",178,5,80,34,muted).Activated:Connect(function() Remote:FireServer("PracticeLeave") end)
local function hideCard() cardToken += 1 card.Visible = false end
Remote.OnClientEvent:Connect(function(action,data)
	if action == "OpenMastery" then player:SetAttribute("MasteryMenuOpen",true)
	elseif action == "MasteryResult" and type(data) == "table" then
		-- Intermediate medals and bests update Mastery silently during the chase.
		if not data.practice and data.stage ~= #Config.Courses then return end
		cardToken += 1
		local token = cardToken
		local medal = data.medal or 0
		local tint = medalColors[medal] or mint
		medallion.Text,medallion.BackgroundColor3 = medal > 0 and string.sub(medalNames[medal],1,1) or "P",tint
		heading.Text,heading.TextColor3 = data.practice and "Practice Clear!" or (medalNames[medal] or "Rift") .. " Finish!",tint
		resultTime.Text = string.format("%.2fs",data.time)
		improvement.Text = data.newBest and "New Best!" or ""
		local view = workspace.CurrentCamera
		local position = cardPosition(view)
		card.Position,card.BackgroundTransparency,card.Visible = position+UDim2.fromOffset(0,6),.35,true
		TweenService:Create(card,TweenInfo.new(.2),{Position=position,BackgroundTransparency=.08}):Play()
		task.delay(data.practice and 3 or 2.5,function() if token == cardToken then card.Visible=false end end)
	end
end)
player:GetAttributeChangedSignal("MasterySelectedMap"):Connect(function()
	local value = player:GetAttribute("MasterySelectedMap")
	for _,map in ipairs(Config.Maps) do if map.id == value then selected=value end end
	refresh()
end)
for _,name in ipairs({"MasteryMenuOpen","Role","UnlockedCourse","MedalPoints","SaveStatus","CoursePractice"}) do player:GetAttributeChangedSignal(name):Connect(refresh) end
player:GetAttributeChangedSignal("PracticeStartedAt"):Connect(function() hideCard() player:SetAttribute("MasteryMenuOpen",false) end)
local function browsing()
	Remote:FireServer("MasteryMenu",player:GetAttribute("MasteryMenuOpen") == true and allowed())
end
player:GetAttributeChangedSignal("MasteryMenuOpen"):Connect(browsing)
player:GetAttributeChangedSignal("Role"):Connect(function()
	if not allowed() then player:SetAttribute("MasteryMenuOpen",false) end
	browsing()
end)
for _,map in ipairs(Config.Maps) do
	for stage=1,#Config.Courses do
		for _,prefix in ipairs({"Best_","Medal_","PracticeBest_"}) do player:GetAttributeChangedSignal(prefix..map.id.."_"..stage):Connect(refresh) end
	end
end
local camera, connection
local function layout()
	local view = workspace.CurrentCamera
	if not view then return end
	local scale = menu:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale,scale.Parent = math.min(1,(view.ViewportSize.X-20)/460,(view.ViewportSize.Y-32)/548),menu
	local cardScale = card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	cardScale.Scale,cardScale.Parent = math.min(1,(view.ViewportSize.X-24)/248),card
	card.Position = cardPosition(view)
	controls.Position = UDim2.fromOffset(view.ViewportSize.X < 820 and 10 or 14,view.ViewportSize.X < 820 and 158 or 88)
end
RunService.RenderStepped:Connect(function()
	syncChat()
	controls.Visible = player:GetAttribute("CoursePractice") == true and not menu.Visible
	local view = workspace.CurrentCamera
	if view then controls.Position = UDim2.fromOffset(view.ViewportSize.X < 820 and 10 or 14,view.ViewportSize.X < 820 and 158 or 88) end
	if view ~= camera then
		if connection then connection:Disconnect() end
		camera=view
		if view then connection=view:GetPropertyChangedSignal("ViewportSize"):Connect(layout) end
		layout()
	end
end)
refresh() layout()
