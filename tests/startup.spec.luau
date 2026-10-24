-- Run the actual server's initialization in an unpublished Studio-like environment.
-- Engine physics and replication still require Studio testing.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local r = require("@lune/roblox")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")
local Ids = require("../src/shared/PassIds")
local host = require("./native-host")()
local function signal()
	return { Connect = function() return { Disconnect = function() end } end }
end
local virtualTime = 1000
local attributes = {}
local datastoreCalls = 0
local spawned = {}
local shared = { Config = "config", Rules = "rules", PassIds = "ids" }
local services = {
	Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end },
	ReplicatedStorage = { WaitForChild = function(_, name) if name == "RiftShared" then return shared end return { OnServerEvent = signal() } end,
		SetAttribute = function(_, key, value) attributes[key] = value end, GetAttribute = function(_, key) return attributes[key] end },
	RunService = { IsStudio = function() return true end, Heartbeat = signal() },
	PhysicsService = { RegisterCollisionGroup = function() end, CollisionGroupSetCollidable = function() end },
	PathfindingService = {},
	DataStoreService = { GetDataStore = function() datastoreCalls += 1 error("You must publish this place to the web to access DataStore.") end },
	HttpService = { GenerateGUID = function() return "test-token" end },
	ServerStorage = host.wrap(host.model:GetService("ServerStorage")),
	Lighting = host.wrap(host.model:GetService("Lighting")),
	MarketplaceService = { PromptGamePassPurchaseFinished = signal(), UserOwnsGamePassAsync = function() error("must not check passes") end },
	CollectionService = {},
}
local environment = {
	game = { GameId = 0, GetService = function(_, name) assert(services[name], name) return services[name] end, BindToClose = function() end },
	workspace = { WaitForChild = function(_, name) return host.workspace:WaitForChild(name) end, GetServerTimeNow = function() return virtualTime end },
	script = { Parent = { ProfileStore = "profiles", PassService = "passes", WorldService = "world", CreatureRig = "creature", CaptureService = "captures", StyleService = "styles", CourseService = "courses", PlaytestService = "metrics", CatcherNavigation = "navigation", MasteryService = "mastery", PracticeService = "practice", VIPGearService = "gear" } },
	Vector3 = r.Vector3, Color3 = r.Color3, Enum = r.Enum,
	Random = { new = function() return {} end }, RaycastParams = { new = function() return {} end },
	task = {
		wait = function(seconds) return coroutine.yield(seconds) end,
		spawn = function(fn, ...)
			local thread = coroutine.create(fn)
			local ok, errorMessage = coroutine.resume(thread, ...)
			assert(ok, errorMessage)
			table.insert(spawned, thread)
		end,
	},
	os = setmetatable({ clock = function() return virtualTime end }, { __index = os }),
}
local Profiles, Passes, World, Creature, Captures, Styles, Courses, Metrics, Navigation, Mastery, Practice, Gear, Launch
environment.require = function(name)
	if name == "config" then return Config end
	if name == "rules" then return Rules end
	if name == "profiles" then return Profiles end
	if name == "ids" then return Ids end
	if name == "passes" then return Passes end
	if name == "world" then return World end
	if name == "creature" then return Creature end
	if name == "captures" then return Captures end
	if name == "styles" then return Styles end
	if name == "courses" then return Courses end
	if name == "metrics" then return Metrics end
	if name == "navigation" then return Navigation end
	if name == "mastery" then return Mastery end
	if name == "practice" then return Practice end
	if name == "gear" then return Gear end
	if name == "launch" then return Launch end
	error("Unexpected module: " .. tostring(name))
end
Profiles = luau.load(fs.readFile("src/server/ProfileStore.luau"), { environment = environment })()
Passes = luau.load(fs.readFile("src/server/PassService.luau"), { environment = environment })()
World = luau.load(fs.readFile("src/server/WorldService.luau"), { environment = environment })()
Creature = luau.load(fs.readFile("src/server/CreatureRig.luau"), { environment = environment })()
Captures = luau.load(fs.readFile("src/server/CaptureService.luau"), { environment = environment })()
Styles = luau.load(fs.readFile("src/server/StyleService.luau"), { environment = environment })()
Courses = luau.load(fs.readFile("src/server/CourseService.luau"), { environment = environment })()
Metrics = luau.load(fs.readFile("src/server/PlaytestService.luau"), { environment = environment })()
Navigation = luau.load(fs.readFile("src/server/CatcherNavigation.luau"), { environment = environment })()
Mastery = luau.load(fs.readFile("src/server/MasteryService.luau"), { environment = environment })()
Practice = luau.load(fs.readFile("src/server/PracticeService.luau"), { environment = environment })()
Gear = luau.load(fs.readFile("src/server/VIPGearService.luau"), { environment = environment })()
environment.script.Parent.LaunchService="launch"
services.AnalyticsService={}
Launch = luau.load(fs.readFile("src/server/LaunchService.luau"), { environment = environment })()
local server = coroutine.create(luau.load(fs.readFile("src/server/Game.server.luau"), { environment = environment }))
local ok, waitSeconds = coroutine.resume(server)
assert(ok, waitSeconds)
assert(datastoreCalls == 0, "Server startup created a DataStore in an unpublished place")
assert(attributes.Phase == "Intermission", "Server did not start the match loop")
assert(attributes.Deadline == 1000 + Config.Intermission, "NEXT MATCH deadline never started")
assert(attributes.Practice == false and attributes.Round == 0, "Initial round state")
assert(attributes.MapName == "Crystal Grove" and attributes.VotingOpen == true, "decorative map and voting initialize")
assert(#World.getInteractions() == 12, "world indexes pickups and recharge pads")
assert(waitSeconds == 0.2 and coroutine.status(server) == "suspended", "Match loop must yield normally")
virtualTime += 5
ok, waitSeconds = coroutine.resume(server)
assert(ok and attributes.Deadline - virtualTime == Config.Intermission - 5, "Countdown progresses without startup crash")
print("PASS: actual server startup and countdown in simulated unpublished Studio, zero DataStore calls")
