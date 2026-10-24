local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local host=require("./native-host")()
local callbacks={}
local heartbeat={Connect=function(_,fn) table.insert(callbacks,fn) end}
local p=host.wrap(r.Instance.new("Player"))
p:SetAttribute("Role","Spectator")
local light=host.wrap(host.model:GetService("Lighting"))
local env={workspace=host.workspace,CFrame=r.CFrame,Color3=r.Color3,
	game={GetService=function(_,name)
		if name=="Players" then return {LocalPlayer=p} end
		if name=="ReplicatedStorage" then return host.replicated end
		if name=="RunService" then return {Heartbeat=heartbeat} end
		return light
	end}}
local ribbon=host.workspace.RiftBackdrop:FindFirstChild("AuroraRibbon")
local frame=ribbon.CFrame
luau.load(fs.readFile("src/client/SkyAmbience.client.luau"),{environment=env})()
callbacks[1](.04)
assert(ribbon.CFrame==frame,"background updates are capped")
callbacks[1](.08)
assert(ribbon.CFrame~=frame and not ribbon.CanCollide,"aurora drifts without changing collision")
local lobbyColor=ribbon.Color
p:SetAttribute("Role","Runner") host.replicated:SetAttribute("Phase","Crossing") host.replicated:SetAttribute("MapId","SunsetRuins")
p:GetAttributeChangedSignal("Role"):Fire()
assert(ribbon.Color~=lobbyColor,"race sky follows its biome")
p:SetAttribute("Role","Escaped") p:GetAttributeChangedSignal("Role"):Fire()
assert(ribbon.Color==lobbyColor,"finishers return to lobby ambience")
print("PASS: actual sky animation, update budget, collision and personal biome ambience")
