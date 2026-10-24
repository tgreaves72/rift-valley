-- Native floor extents, controlled pathfinding and time. Not engine physics.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config, host = require("../src/shared/Config"), require("./native-host")()
local now, computations, moves = 1000, 0, {}
local blockBody, unstable, deferred, failPath = false, false, false, false
local queue, latestPath = {}, nil
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) local active = true table.insert(self.callbacks, function(...) if active then fn(...) end end) return { Disconnect = function() active = false end } end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local function instance(class) return host.wrap(r.Instance.new(class)) end
local model, root, hum = instance("Model"), instance("Part"), instance("Humanoid")
model.Parent, root.Parent, hum.Parent = host.workspace, model, model
root.CFrame, model.PrimaryPart = r.CFrame.new(230,4,-100), root
rawset(hum,"FloorMaterial",r.Enum.Material.Concrete)
rawset(hum,"Move",function(_,dir) moves.direction=dir end)
rawset(hum,"MoveTo",function(_,point) moves.goal=point end)
local bot = { model=model,root=root,humanoid=hum,spawnPoint=r.Vector3.new(210,4,-156),stage=2 }
local floors, names = {}, { ArenaFloor=true,SafeDeck=true,CourseFloor=true,CourseDeck=true,CourseBypass=true,CourseBypassLane=true,CourseJunction=true }
for _, part in ipairs(host.workspace.RiftArena:GetDescendants()) do if part:IsA("BasePart") and names[part.Name] then table.insert(floors,part) end end
local crumble = host.wrap(host.model:GetService("ServerStorage")).RiftMechanics.SunsetRuins:FindFirstChild("4"):FindFirstChild("CrumbleTile")
rawset(host.workspace,"GetServerTimeNow",function() return now end)
rawset(host.workspace,"Raycast",function(_,origin,direction)
	if direction.Y == 0 then return blockBody and origin.Y < 3 and { Instance=root } or nil end
	local hit
	for _,floor in ipairs(floors) do
		local p,s = floor.Position,floor.Size
		local top = p.Y+s.Y/2
		if math.abs(origin.X-p.X)<=s.X/2 and math.abs(origin.Z-p.Z)<=s.Z/2 and top<=origin.Y and top>=origin.Y+direction.Y then
			if not hit or hit.Position.Y<top then hit={ Instance=unstable and crumble or floor,Position=r.Vector3.new(origin.X,top,origin.Z),Normal=r.Vector3.new(0,1,0) } end
		end
	end
	return hit
end)
local points = {
	{ Position=r.Vector3.new(230,0,-110),Action=r.Enum.PathWaypointAction.Walk },
	{ Position=r.Vector3.new(230,0,-100),Action=r.Enum.PathWaypointAction.Walk },
	{ Position=r.Vector3.new(230,0,-88),Action=r.Enum.PathWaypointAction.Jump },
}
local env = { workspace=host.workspace,Vector3=r.Vector3,CFrame=r.CFrame,Enum=r.Enum,RaycastParams={new=function() return {} end},require=function() return Config end,
	task={spawn=function(fn) if deferred then table.insert(queue,fn) else fn() end end},
	game={GetService=function(_,name)
		if name~="PathfindingService" then return host.replicated end
		return {CreatePath=function(_,options)
			assert(options.Costs.Unstable==math.huge and options.AgentHeight==6)
			latestPath={Blocked=signal(),Status=failPath and r.Enum.PathStatus.NoPath or r.Enum.PathStatus.Success,
				ComputeAsync=function() computations+=1 end,GetWaypoints=function() return points end}
			return latestPath
		end}
	end}}
local N=luau.load(fs.readFile("src/server/CatcherNavigation.luau"),{environment=env})()
local passed=0
local function check(v,message) assert(v,message) passed+=1 end
check(N.safeSegment(r.Vector3.new(21,4,-506),r.Vector3.new(21,4,-486)),"native gap detour supports a short charge corridor")
check(not N.safeSegment(r.Vector3.new(0,4,-506),r.Vector3.new(0,4,-486)),"native central gap blocks a charge")
blockBody=true
check(not N.safeSegment(root.Position,root.Position+r.Vector3.new(0,0,12)),"low hurdle blocks a charge")
blockBody,unstable=false,true
check(not N.safeSegment(root.Position,root.Position+r.Vector3.new(0,0,8)),"unstable ground blocks a charge")
unstable,blockBody=false,true
N.reset(bot,now)
local target={Position=r.Vector3.new(230,4,-60)}
N.prime(bot,target,now)
check(computations==1 and #bot.navigation.waypoints==3 and not moves.goal and not moves.direction,"Ready prepares a path without moving or jumping")
N.prime(bot,target,now+.1)
check(computations==1 and bot.navigation.progressAt==now+.1,"Ready reuses the prepared path and refreshes stuck timing")
N.follow(bot,target,now)
check(computations==1,"first chase update uses its prepared route immediately")
check(moves.goal==points[3].Position,"root four studs above floor advances to the next waypoint")
check(hum.Jump,"jump waypoint triggers once")
hum.Jump=false now+=.1 N.follow(bot,target,now)
check(not hum.Jump,"same waypoint does not repeatedly trigger jumps")
latestPath.Blocked:Fire(1) check(not bot.navigation.dirty,"blockage behind is ignored")
latestPath.Blocked:Fire(3) check(bot.navigation.dirty,"blockage ahead invalidates route")
now+=.1 N.follow(bot,target,now)
check(computations==2 and not bot.navigation.dirty,"blocked route is recomputed")
N.reset(bot,now) deferred=true N.follow(bot,target,now)
check(bot.navigation.computing and #queue==1,"path work can yield")
local stale=table.remove(queue,1) N.reset(bot,now+.1) stale()
check(#bot.navigation.waypoints==0 and not bot.navigation.computing,"late path cannot overwrite reset")
deferred,failPath=false,true now+=.2 N.follow(bot,target,now)
check(bot.navigation.failed and not bot.navigation.computing,"NoPath releases computation lock")
failPath=false now+=1.1 N.follow(bot,target,now)
check(not bot.navigation.failed and #bot.navigation.waypoints==3,"failed route retries")
N.reset(bot,now) bot.navigation.lastSafe=r.Vector3.new(230,4,-120) bot.chargeAt=now
now+=3.6 N.follow(bot,target,now)
check((root.Position-r.Vector3.new(230,4,-120)).Magnitude<.001,"stuck catcher returns to stable ground")
check(not bot.chargeAt and model:GetAttribute("NavigationRecoverUntil")>now,"recovery cancels charge and delays attacks")
check(root.AssemblyLinearVelocity==r.Vector3.zero and #bot.navigation.waypoints==0,"recovery clears velocity and route")
N.remove(bot) check(bot.navigation.removed,"despawn invalidates navigation")
-- Direct pursuit must not reuse old waypoints behind a shortcut/bend.
blockBody=false
root.CFrame=r.CFrame.new(230,4,-118)
N.reset(bot,now)
bot.navigation.waypoints=points bot.navigation.index=2
N.follow(bot,{Position=r.Vector3.new(230,4,-110)},now)
check(bot.navigation.direct and #bot.navigation.waypoints==0,"direct pursuit discards the old path")
blockBody=true now+=.2
N.follow(bot,target,now)
check(not bot.navigation.direct and bot.navigation.goal==target.Position,"leaving a direct corridor requests a fresh route at the bend")
print("PASS: "..passed.." native-floor navigation, waypoint, jump, blockage, async and recovery assertions")
