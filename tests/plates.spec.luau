local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local Config,Rules=require("../src/shared/Config"),require("../src/shared/Rules")
local host=require("./native-host")()
local time=1000
rawset(host.workspace,"GetServerTimeNow",function() return time end)
local env={workspace=host.workspace,Vector3=r.Vector3,Color3=r.Color3,Enum=r.Enum,
	require=function(name) return name.Name=="Config" and Config or Rules end,
	game={GetService=function(_,name) if name=="Players" then return {GetPlayers=function() return {} end} end return host.wrap(host.model:GetService(name)) end}}
local World=luau.load(fs.readFile("src/server/WorldService.luau"),{environment=env})()
local function player()
	local root={Position=r.Vector3.new(0,32,224)}
	local hum={Health=100,FloorMaterial=r.Enum.Material.Concrete}
	local p={lobby=true,attrs={},SetAttribute=function(self,key,value) self.attrs[key]=value end,
		Character={FindFirstChild=function() return root end,FindFirstChildOfClass=function() return hum end}}
	return p,root,hum
end
World.init({inLobby=function(p) return p.lobby end,isVIP=function() return false end,notice=function() end,
	returnLobby=function() end,moveLobby=function() end,celebrate=function() end})
local a,ar,ah=player()
local b,br,bh=player()
local passed=0
local function check(v,m) assert(v,m) passed+=1 end
local function stand(p,root,hum,plate)
	root.Position=plate.Position+r.Vector3.new(0,plate.Size.Y/2+3,0)
	World.stepLobby(p,root,hum)
end
World.startVoting()
check(not World.voteOnPlate(a,"CrystalGrove"),"remote cannot vote from across the lobby")
stand(a,ar,ah,host.workspace.RiftLobby.Vote_CrystalGrove)
stand(b,br,bh,host.workspace.RiftLobby.Vote_NeonHarbor)
check(a.attrs.MapVote=="CrystalGrove" and b.attrs.MapVote=="NeonHarbor","different players independently vote by standing")
check(host.replicated:GetAttribute("Votes_CrystalGrove")==1 and host.replicated:GetAttribute("Votes_NeonHarbor")==1,"shared multiplayer tally")
stand(a,ar,ah,host.workspace.RiftLobby.Vote_CrystalGrove)
check(host.replicated:GetAttribute("Votes_CrystalGrove")==1,"holding a plate cannot stack votes")
ah.FloorMaterial=r.Enum.Material.Air
stand(a,ar,ah,host.workspace.RiftLobby.Vote_SunsetRuins)
check(a.attrs.MapVote=="CrystalGrove" and not World.voteOnPlate(a,"SunsetRuins"),"airborne overlap cannot press a plate")
ah.FloorMaterial=r.Enum.Material.Concrete
stand(a,ar,ah,host.workspace.RiftLobby.Vote_SunsetRuins)
check(a.attrs.MapVote=="SunsetRuins" and host.replicated:GetAttribute("Votes_CrystalGrove")==0,"another plate changes the existing vote")
a.lobby=false
stand(a,ar,ah,host.workspace.RiftLobby.Vote_NeonHarbor)
check(a.attrs.MapVote=="SunsetRuins","active racers cannot press lobby plates")
a.lobby=true
local start=host.workspace.RiftLobby.Parkour.ParkourStart
stand(a,ar,ah,start)
local began=a.attrs.ParkourStartedAt
check(a.attrs.ParkourActive and began==time,"parkour plate starts the timer automatically")
time+=2 stand(a,ar,ah,start)
check(a.attrs.ParkourStartedAt==began and not World.beginParkour(a),"standing on entry cannot restart the clock")
World.startVoting()
stand(b,br,bh,host.workspace.RiftLobby.Vote_NeonHarbor)
check(b.attrs.MapVote=="NeonHarbor" and host.replicated:GetAttribute("Votes_NeonHarbor")==1,"new queue recognizes a player already on a voting plate")
World.remove(b)
check(host.replicated:GetAttribute("Votes_NeonHarbor")==0,"departing player releases their vote")
print("PASS: "..passed.." physical plate, shared voting, timer debounce and authority assertions")
