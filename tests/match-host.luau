return function(count,options)
options=options or {}
-- Actual server and world modules, controlled players/clock/pathfinding.
-- This checks authority and lifecycle; Studio must verify jumping and NPC physics.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local host = require("./native-host")()
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) table.insert(self.callbacks, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local now, events, profiles, players, delayed = 1000, {}, {}, {}, {}
local heartbeat = signal()
local remote = host.replicated.RiftAction
rawset(remote, "FireClient", function(_, player, action, data, kind) table.insert(events, { player = player, action = action, data = data, kind = kind }) end)
rawset(remote, "FireAllClients", function(_, action, data) table.insert(events, { action = action, data = data }) end)
rawset(host.workspace, "GetServerTimeNow", function() return now end)
rawset(host.workspace, "Raycast", function(_, origin, direction)
    if direction.Y < -1 and math.abs(direction.X) < .001 and math.abs(direction.Z) < .001 then
        return { Position = r.Vector3.new(origin.X, 0, origin.Z), Normal = r.Vector3.new(0,1,0), Instance = host.workspace.RiftArena.ArenaFloor }
    end
    return nil
end) -- Flat-ground mock; real floor/gap geometry is tested separately.
local function instance(class) return host.wrap(r.Instance.new(class)) end
local function actor(name, position)
	local model, root, hum = instance("Model"), instance("Part"), instance("Humanoid")
	model.Name, model.Parent = name, host.workspace
	root.Name, root.CFrame, root.Parent = "HumanoidRootPart", r.CFrame.new(position), model
	model.PrimaryPart = root
	hum.Parent = model
	hum.Sit = false
	rawset(hum, "Health", 100)
	rawset(root, "SetNetworkOwner", function() end)
	rawset(hum, "Move", function(_, direction) rawset(hum, "LastMove", direction) end)
	rawset(hum, "MoveTo", function(_, point) rawset(hum, "LastMoveTo", point) end)
	rawset(hum, "FloorMaterial", r.Enum.Material.Concrete)
	rawset(hum, "MoveDirection", r.Vector3.zero)
	rawset(hum, "Died", signal())
	return model, root, hum
end
for index = 1, count do
	local player = instance("Player")
	player.Name, player.Parent = "Player" .. index, host.wrap(host.model:GetService("Players"))
	rawset(player, "UserId", index)
	rawset(player, "LoadCharacterAsync", function()
		local char = actor(player.Name, r.Vector3.new(0, 32, 224))
		rawset(player, "Character", char)
		player.CharacterAdded:Fire(char)
		if options.spawnPlacementAfterEvent then char.PrimaryPart.CFrame=r.CFrame.new(0,32,224) end
		remote.OnServerEvent:Fire(player,"CharacterReady",char)
	end)
	table.insert(players, player)
	profiles[player] = { Coins = 0, XP = 0, Wins = 0, Tags = 0, Crossings = 0, Owned = { None = true }, Equipped = "None" }
end
local Profiles = { load = function() end, get = function(p) return profiles[p] end, save = function() end }
local vipOwners={}
local Passes = { init = function() end, load = function() end, owns = function(p,key) return key=="VIP" and vipOwners[p]==true end, entitlements = function() return {} end }
local Creature = {
	variant = function(model, kind) model:SetAttribute("Archetype", kind) end,
	apply = function() end, track = function() end,
	create = function(name) return actor(name, r.Vector3.zero) end,
}
local services = {
	Players = { GetPlayers = function() return players end, PlayerAdded = signal(), PlayerRemoving = signal() },
	ReplicatedStorage = host.replicated, ServerStorage = host.wrap(host.model:GetService("ServerStorage")), Lighting = host.wrap(host.model:GetService("Lighting")),
	RunService = { Heartbeat = heartbeat, IsStudio=function() return true end },
	PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end },
	PathfindingService = { CreatePath = function()
		return { Status = r.Enum.PathStatus.Success, ComputeAsync = function() end, GetWaypoints = function() return {} end }
	end },
}
local World, Captures, Styles, Courses, Metrics, Navigation, Mastery, Practice, Gear, Launch
local env = {
	game = { GetService = function(_, name) return services[name] end, BindToClose = function() end },
	workspace = host.workspace, Instance = { new = instance }, Vector3 = r.Vector3, Color3 = r.Color3, CFrame = r.CFrame, Enum = r.Enum, UDim2 = r.UDim2,
	script = { Parent = { ProfileStore = "Profiles", PassService = "Passes", WorldService = "World", CreatureRig = "Creature", CaptureService = "Captures", StyleService = "Styles", CourseService = "Courses", PlaytestService = "Metrics", CatcherNavigation = "Navigation", MasteryService = "Mastery", PracticeService = "Practice", VIPGearService = "Gear", LaunchService = "Launch" } },
	RaycastParams = { new = function() return {} end },
	Random = { new = function() return { NextNumber = function(_, low, high) return (low+high)/2 end, NextInteger = function(_, low) return low end } end },
	os = setmetatable({ clock = function() return now end }, { __index = os }),
	task = { wait = function(seconds) return coroutine.yield(seconds) end, delay = function(_,fn) table.insert(delayed,fn) end, spawn = function(fn, ...)
		local ok, errorMessage = coroutine.resume(coroutine.create(fn), ...) assert(ok, errorMessage)
	end },
}
env.require = function(key)
	if type(key) ~= "string" then key = key.Name end
	return ({ Config = Config, Rules = Rules, Profiles = Profiles, Passes = Passes, World = World, Creature = Creature, Captures = Captures, Styles = Styles, Courses = Courses, Metrics = Metrics, Navigation = Navigation, Mastery = Mastery, Practice = Practice, Gear = Gear, Launch = Launch })[key]
end
World = luau.load(fs.readFile("src/server/WorldService.luau"), { environment = env })()
Captures = luau.load(fs.readFile("src/server/CaptureService.luau"), { environment = env })()
Styles = luau.load(fs.readFile("src/server/StyleService.luau"), { environment = env })()
Courses = luau.load(fs.readFile("src/server/CourseService.luau"), { environment = env })()
Metrics = luau.load(fs.readFile("src/server/PlaytestService.luau"), { environment = env })()
Navigation = luau.load(fs.readFile("src/server/CatcherNavigation.luau"), { environment = env })()
Mastery = luau.load(fs.readFile("src/server/MasteryService.luau"), { environment = env })()
Practice = luau.load(fs.readFile("src/server/PracticeService.luau"), { environment = env })()
Gear = luau.load(fs.readFile("src/server/VIPGearService.luau"), { environment = env })()
Launch = luau.load(fs.readFile("src/server/LaunchService.luau"), { environment = env })()
local main = coroutine.create(luau.load(fs.readFile("src/server/Game.server.luau"), { environment = env }))
local function resume()
	local ok, errorMessage = coroutine.resume(main) assert(ok, errorMessage)
end
resume()
for _,player in ipairs(players) do remote.OnServerEvent:Fire(player,"CharacterReady",player.Character) end
return {
    players = players, profiles = profiles, remote = remote, host = host, events = events, game=env.game,
    vipOwners = vipOwners,
    metrics = Metrics, captures = Captures, courses = Courses, services = services, mastery = Mastery, practice = Practice, world = World, launch = Launch,
    now = function() return now end,
    resume = resume,
    runDelayed = function() local pending=delayed delayed={} for _,fn in ipairs(pending) do fn() end end,
    tick = function(dt, advanceMain)
        now += dt
        heartbeat:Fire(dt)
        if advanceMain then resume() end
    end,
}
end
