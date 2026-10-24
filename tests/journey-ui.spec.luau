local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local Rules=require("../src/shared/Rules")
local host=require("./native-host")()
local function instance(cls) return host.wrap(r.Instance.new(cls)) end
local p,pg=instance("Player"),instance("PlayerGui") pg.Name,pg.Parent="PlayerGui",p
local clock,chat=1000,true
rawset(host.workspace,"GetServerTimeNow",function() return clock end)
local camera={ViewportSize=r.Vector2.new(1280,720)} rawset(host.workspace,"CurrentCamera",camera)
local render={}
function render:Connect(fn) self.fn=fn end
local actions={}
rawset(host.replicated.RiftAction,"FireServer",function(_,action) table.insert(actions,action) end)
local env={workspace=host.workspace,Instance={new=instance},Vector2=r.Vector2,Vector3=r.Vector3,UDim=r.UDim,UDim2=r.UDim2,Color3=r.Color3,Enum=r.Enum,CFrame=r.CFrame,
	require=function() return Rules end,game={GetService=function(_,name)
		return ({Players={LocalPlayer=p},ReplicatedStorage=host.replicated,RunService={RenderStepped=render},StarterGui={GetCoreGuiEnabled=function() return chat end,SetCoreGuiEnabled=function(_,_,enabled) chat=enabled end}})[name]
	end}}
luau.load(fs.readFile("src/client/Journey.client.luau"),{environment=env})()
local count=0
local function check(v,message) assert(v,message) count+=1 end
local gui=pg.RiftJourney
p:SetAttribute("Role","Spectator") p:SetAttribute("TutorialSeen",false) p:SetAttribute("GoalText1","Finish 3 courses")
render.fn()
check(gui.FirstRun.Visible and not gui.GoalsPanel.Visible,"new players see one small optional invitation")
gui.FirstRun.Skip.Activated:Fire()
check(actions[#actions]=="TutorialSkip","skip requests persisted dismissal from the server")
p:SetAttribute("TutorialSeen",true) p:SetAttribute("JourneyMenuOpen",true) p:SetAttribute("GoalProgress1",2) p:SetAttribute("GoalTarget1",3)
render.fn()
check(gui.GoalsPanel.Visible and not gui.FirstRun.Visible and not chat,"goals panel replaces the invitation without chat overlap")
check(gui.GoalsPanel.Count1.Text=="2 / 3","goal progress uses server-confirmed attributes")
for _,size in ipairs({r.Vector2.new(320,568),r.Vector2.new(568,320),r.Vector2.new(1920,1080)}) do
	camera.ViewportSize=size render.fn()
	local scale=gui.GoalsPanel:FindFirstChildOfClass("UIScale").Scale
	check(scale*390<=size.X-23 and scale*430<=size.Y-23,"goal controls remain inside portrait and landscape screens")
end
gui.GoalsPanel.Learn.Activated:Fire()
check(actions[#actions]=="TutorialStart" and not p:GetAttribute("JourneyMenuOpen"),"training starts through the server")
p:SetAttribute("TutorialActive",true) render.fn()
check(gui.ExitLesson.Visible and not gui.FirstRun.Visible,"active lesson has a compact skip action")
p:SetAttribute("TutorialActive",false) p:SetAttribute("ParkourActive",true) p:SetAttribute("ParkourStartedAt",1000)
host.replicated.RiftAction.OnClientEvent:Fire("ParkourGhost",{revision=1,durationMs=20000,frames={{0,-730,320,2280,3142},{20000,-1040,790,2600,0}}})
clock=1010 render.fn()
local ghost=host.workspace.RiftParkourGhost
check(ghost and #ghost:GetChildren()==7,"a personal best renders a six-part translucent runner and name")
for _,part in ipairs(ghost:GetChildren()) do
	if part:IsA("BasePart") then check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,"ghost is purely local decoration") end
end
check(ghost.Body.Position.X < -80 and ghost.Body.Position.X > -100,"replay interpolates the recorded path")
gui.GoalsPanel.GhostToggle.Activated:Fire() render.fn()
check(not ghost.Parent,"ghost can be hidden immediately")
p:SetAttribute("Role","Runner") p:SetAttribute("JourneyMenuOpen",true) render.fn()
check(not gui.GoalsPanel.Visible and not gui.FirstRun.Visible and chat,"race entry closes optional UI and restores chat")
print("PASS: "..count.." actual onboarding, goals, responsive layout and local ghost playback assertions")
