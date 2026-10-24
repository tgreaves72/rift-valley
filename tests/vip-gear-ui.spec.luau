local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local host=require("./native-host")()
local function instance(cls) return host.wrap(r.Instance.new(cls)) end
local p,pg,char,tool=instance("Player"),instance("PlayerGui"),instance("Model"),instance("Tool")
pg.Name,pg.Parent="PlayerGui",p
tool:SetAttribute("RiftVIPGear","Blaster") tool.Parent=char
rawset(p,"Character",char)
rawset(p,"GetMouse",function() return {Hit=r.CFrame.new(190,33,224)} end)
local request
rawset(host.replicated.RiftAction,"FireServer",function(_,action,aim) request={action=action,aim=aim} end)
local render={}
function render:Connect(fn) self.fn=fn end
local input={TouchEnabled=true,GamepadEnabled=false}
local camera={CFrame=r.CFrame.new(180,35,224)}
rawset(host.workspace,"CurrentCamera",camera)
local effects={}
local env={workspace=host.workspace,Instance={new=instance},Vector2=r.Vector2,Vector3=r.Vector3,UDim2=r.UDim2,Color3=r.Color3,Enum=r.Enum,CFrame=r.CFrame,
	game={GetService=function(_,name)
		return ({Players={LocalPlayer=p},ReplicatedStorage=host.replicated,UserInputService=input,RunService={RenderStepped=render},Debris={AddItem=function(_,obj,seconds) table.insert(effects,{obj=obj,seconds=seconds}) end}})[name]
	end}}
luau.load(fs.readFile("src/client/VIPGear.client.luau"),{environment=env})()
local gui=pg.RiftVIPGear
local count=0
local function check(v,message) assert(v,message) count+=1 end
render.fn()
check(not gui.Crosshair.Visible and gui.Hint.Text=="VIP Arena only","equipped gun explains the allowed area without enabling fire")
tool.Activated:Fire()
check(request==nil,"inactive client gun never sends fire requests")
p:SetAttribute("VIPGearActive",true) render.fn() tool.Activated:Fire()
check(gui.Crosshair.Visible and request.action=="VIPFire" and request.aim==camera.CFrame.Position+camera.CFrame.LookVector*180,"touch and controller fire aim through the center crosshair")
input.TouchEnabled=false tool.Activated:Fire()
check(request.aim==r.Vector3.new(190,33,224),"desktop fire follows the mouse target")
host.replicated.RiftAction.OnClientEvent:Fire("VIPShot",{from=r.Vector3.new(180,33,224),to=r.Vector3.new(190,33,224)})
check(#effects==1 and effects[1].seconds==.1 and not effects[1].obj.CanCollide and not effects[1].obj.CanQuery,"shot effects have a short lifetime and cannot affect hit tests")
host.replicated.RiftAction.OnClientEvent:Fire("VIPShot",{from=r.Vector3.new(-500,33,224),to=r.Vector3.new(-490,33,224)})
check(#effects==1,"distant gun effects are culled")
print("PASS: "..count.." actual VIP gear client activation, touch aim, desktop aim and effect-budget assertions")
