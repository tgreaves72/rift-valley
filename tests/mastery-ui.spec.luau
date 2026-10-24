local fs,luau,r = require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local Config,Ids = require("../src/shared/Config"),require("../src/shared/PassIds")
local host=require("./native-host")()
local function signal()
	local s={callbacks={}}
	function s:Connect(fn) table.insert(self.callbacks,fn) return {Disconnect=function() end} end
	function s:Fire(...) for _,fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local function instance(class) return host.wrap(r.Instance.new(class)) end
local p,pg=instance("Player"),instance("PlayerGui")
pg.Name,pg.Parent="PlayerGui",p
rawset(p,"Character",nil)
local count=0
local function check(value,message) assert(value,message) count+=1 end
local nativeSet=p.SetAttribute
rawset(p,"SetAttribute",function(self,name,value)
	local previous=self:GetAttribute(name)
	nativeSet(self,name,value)
	if previous~=value then self:GetAttributeChangedSignal(name):Fire() end
end)
local function set(name,value) p:SetAttribute(name,value) end
local remote,requests,delayed=host.replicated.RiftAction,{},{}
rawset(remote,"FireServer",function(_,action,data) table.insert(requests,{action=action,data=data}) end)
local rendered,resized=signal(),signal()
local camera={ViewportSize=r.Vector2.new(1280,720),FieldOfView=72,GetPropertyChangedSignal=function() return resized end}
rawset(host.workspace,"CurrentCamera",camera)
rawset(host.workspace,"GetServerTimeNow",function() return 1000 end)
local debris={}
local chatEnabled=true
local services={Players={LocalPlayer=p,GetPlayers=function() return {p} end},ReplicatedStorage=host.replicated,
	StarterGui={GetCoreGuiEnabled=function() return chatEnabled end,SetCoreGuiEnabled=function(_,_,enabled) chatEnabled=enabled end},
	RunService={IsStudio=function() return true end,RenderStepped=rendered},ContextActionService={BindAction=function() end,SetTitle=function() end,SetPosition=function() end},
	UserInputService={TouchEnabled=false,GamepadEnabled=false,WindowFocusReleased=signal()},MarketplaceService={PromptGamePassPurchaseFinished=signal()},
	TweenService={Create=function(_,obj,_,props) return {Play=function() for key,value in pairs(props) do obj[key]=value end end} end},
	Debris={AddItem=function(_,obj) table.insert(debris,obj) end}}
local env={game={GameId=0,GetService=function(_,name) return services[name] end},workspace=host.workspace,Instance={new=instance},
	Vector2=r.Vector2,Vector3=r.Vector3,Color3=r.Color3,UDim=r.UDim,UDim2=r.UDim2,CFrame=r.CFrame,Enum=r.Enum,
	Random={new=function() return {NextNumber=function(_,a,b) return (a+b)/2 end} end},TweenInfo={new=function() return {} end},
	require=function(module) return module.Name=="Config" and Config or Ids end,
	task={delay=function(_,fn) table.insert(delayed,fn) end,spawn=function(fn,...) fn(...) end}}
luau.load(fs.readFile("src/client/Controller.client.luau"),{environment=env})()
luau.load(fs.readFile("src/client/Mastery.client.luau"),{environment=env})()
luau.load(fs.readFile("src/client/VictoryEffects.client.luau"),{environment=env})()
local hud,mastery=pg.RiftHUD,pg.RiftMastery
set("Role","Spectator") set("UnlockedCourse",2)
set("SaveStatus","Studio session")
host.replicated:SetAttribute("Phase","Intermission")
hud.Menu.MasteryButton.Activated:Fire() p:GetAttributeChangedSignal("MasteryMenuOpen"):Fire()
rendered:Fire(.016)
check(mastery.Menu.Visible and not hud.Shop.Visible and not hud.Help.Visible,"mastery opens from the lobby without overlapping other menus")
check(not chatEnabled,"Mastery temporarily clears the core chat overlay from its title")
check(mastery.Menu.Course2.Practice.Active and not mastery.Menu.Course3.Practice.Active,"course selector respects server-reported unlocks")
mastery.Menu.NeonHarbor.Activated:Fire() p:GetAttributeChangedSignal("MasterySelectedMap"):Fire()
mastery.Menu.Course2.Practice.Activated:Fire()
local request=requests[#requests]
check(request.action=="PracticeCourse" and request.data.stage==2 and request.data.mapId=="NeonHarbor","practice button sends course/theme request without granting progress")
set("Medal_NeonHarbor_2",3) set("Best_NeonHarbor_2",12.34) set("MedalPoints",3)
check(mastery.Menu.Course2.Medal:GetAttribute("MedalRank")==3 and mastery.Menu.Course2.Best.Text=="Best 12.34s" and mastery.Menu.Points.Text=="3 / 45","replicated 3D medal and personal best update the menu")
check(mastery.Menu.MasteryTrophy:IsA("ViewportFrame") and mastery.Menu.Course2.Medal:IsA("ViewportFrame"),"mastery renders actual 3D trophy and medals with dedicated cameras")
local export=require("./hud-preview")
export(mastery,1280,720,"assets/hud-mastery-desktop-layout.json")
camera.ViewportSize=r.Vector2.new(390,844) resized:Fire()
check(mastery.Menu:FindFirstChildOfClass("UIScale").Scale<1,"mastery scales to portrait phone")
export(mastery,390,844,"assets/hud-mastery-phone-layout.json")
set("CoursePractice",true) set("Role","Trainee") set("PracticeOffsetY",-1200) set("PracticeStartedAt",999)
rendered:Fire(.016)
check(not mastery.Menu.Visible and mastery.PracticeControls.Visible and hud.Match.Status.Text=="Practice Run!","practice acknowledgement closes selector and shows practice controls")
check(hud.Match.Timer.Text=="1.0" and hud.Movement.Visible and not hud.Menu.Visible,"practice HUD uses an independent clock and movement controls")
mastery.PracticeControls.Retry.Activated:Fire()
check(requests[#requests].action=="PracticeRetry","one-tap retry requests the current course")
remote.OnClientEvent:Fire("MasteryResult",{practice=true,medal=0,time=13.25,best=13.25,newBest=true,unlocks={}})
check(mastery.FinishCard.Visible and mastery.FinishCard.Heading.Text=="Practice Clear!" and mastery.FinishCard.Time.Text=="13.25s","practice card shows server-confirmed time")
rendered:Fire(.016)
local cardTop=844+mastery.FinishCard.Position.Y.Offset
check(mastery.PracticeControls.Position.Y.Offset+mastery.PracticeControls.Size.Y.Offset < cardTop and cardTop+mastery.FinishCard.Size.Y.Offset < 844-112,"phone badge clears practice controls and stamina HUD")
set("PracticeFinalTime",13.25) set("PracticeFinished",true) rendered:Fire(.016)
check(hud.Match.Timer.Text=="13.2","finished practice timer freezes")
set("PracticeStartedAt",1001)
check(not mastery.FinishCard.Visible,"retry clears the previous result card")
set("CoursePractice",false) set("Role","Runner")
host.replicated:SetAttribute("Phase","Crossing") set("CourseStage",3)
rendered:Fire(.016)
for stage=1,#Config.Courses-1 do
	remote.OnClientEvent:Fire("MasteryResult",{stage=stage,practice=false,medal=3,time=12.32,best=12.32,newBest=true,unlocks={"Grove shimmer"}})
	check(not mastery.FinishCard.Visible,"intermediate course records never interrupt the next run")
end
export(hud,390,844,"assets/hud-quiet-run-layout.json")
remote.OnClientEvent:Fire("MasteryResult",{stage=#Config.Courses,practice=false,medal=3,time=12.32,best=12.32,delta=.44,newBest=true,unlocks={"Grove shimmer"}})
check(mastery.FinishCard.Visible and mastery.FinishCard.Heading.Text=="Gold Finish!" and mastery.FinishCard.Improvement.Text=="New Best!" and not mastery.FinishCard:FindFirstChild("Unlock"),"final badge shows only medal, time and a short personal-best hint")
check(mastery.FinishCard.Size.X.Offset==248 and mastery.FinishCard.Size.Y.Offset==56,"result badge stays compact")
export(mastery,390,844,"assets/hud-mastery-finish-layout.json")
set("Role","Escaped") set("CourseStage",5) rendered:Fire(.016)
export(hud,390,844,"assets/hud-finish-context-layout.json")
check(844+mastery.FinishCard.Position.Y.Offset+56 < 844+hud.RetryButton.Position.Y.Offset,"finish badge clears the replay button when results open")
camera.ViewportSize=r.Vector2.new(1280,720) resized:Fire()
export(mastery,1280,720,"assets/hud-finish-desktop-layout.json")
export(hud,1280,720,"assets/hud-finish-desktop-context-layout.json")
camera.ViewportSize=r.Vector2.new(568,320) resized:Fire()
set("CoursePractice",true) set("Role","Trainee")
remote.OnClientEvent:Fire("MasteryResult",{stage=2,practice=true,medal=0,time=13.25,best=13.25,newBest=false,unlocks={}})
rendered:Fire(.016)
check(mastery.FinishCard.Position.Y.Offset+mastery.FinishCard.Size.Y.Offset < mastery.PracticeControls.Position.Y.Offset,"landscape badge clears practice buttons")
export(mastery,568,320,"assets/hud-finish-landscape-layout.json")
set("CoursePractice",false)
delayed[#delayed]()
check(not mastery.FinishCard.Visible,"finish badge dismisses without stale text")
set("Role","Spectator") set("MasteryMenuOpen",true)
mastery.Menu.Rewards.Activated:Fire() p:GetAttributeChangedSignal("MasteryRewardsOpen"):Fire()
check(hud.Shop.Visible and hud.Shop.Cosmetics.Visible,"rewards button opens the earned cosmetic collection")
set("MasteryMenuOpen",true) set("Role","Runner")
check(not mastery.Menu.Visible,"starting a race closes the mastery menu")
rendered:Fire(.016)
check(chatEnabled,"closing Mastery restores the previous chat visibility")
local character,root=instance("Model"),instance("Part")
root.Name,root.CFrame,root.Parent="HumanoidRootPart",r.CFrame.new(0,32,224),character
rawset(p,"Character",character)
local total=0
for _,effect in ipairs({"Bloom","Sparks","Fireworks","Confetti"}) do
	local old=#debris
	remote.OnClientEvent:Fire("Victory",{position=root.Position,effect=effect})
	check(#debris>old,"earned victory style emits native visual particles")
end
for _,part in ipairs(debris) do check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,"victory visuals cannot change gameplay collisions") end
check(#debris<=90,"simultaneous victory visuals obey a fixed local particle budget")
local old=#debris
remote.OnClientEvent:Fire("Victory",{position=root.Position+r.Vector3.new(500,0,0),effect="Bloom"})
remote.OnClientEvent:Fire("Victory",{position=root.Position,effect="Unknown"})
check(#debris==old,"distant and invalid victory effects are ignored")
print("PASS: "..count.." actual mastery UI, mobile layout, finish card, practice controls and victory effect assertions")
