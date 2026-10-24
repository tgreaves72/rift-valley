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
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local now, events, profiles, players = 1000, {}, {}, {}
local heartbeat = signal()
local remote = host.replicated.RiftAction
rawset(remote, "FireClient", function(_, player, action, data) table.insert(events, { player = player, action = action, data = data }) end)
rawset(remote, "FireAllClients", function(_, action, data) table.insert(events, { action = action, data = data }) end)
rawset(host.workspace, "GetServerTimeNow", function() return now end)
rawset(host.workspace, "Raycast", function() return nil end)
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
	rawset(hum, "Move", function() end)
	rawset(hum, "MoveTo", function() end)
	rawset(hum, "FloorMaterial", r.Enum.Material.Concrete)
	rawset(hum, "MoveDirection", r.Vector3.zero)
	rawset(hum, "Died", signal())
	return model, root, hum
end
for index = 1, 3 do
	local player = instance("Player")
	player.Name, player.Parent = "Player" .. index, host.wrap(host.model:GetService("Players"))
	rawset(player, "UserId", index)
	rawset(player, "LoadCharacterAsync", function()
		local char = actor(player.Name, r.Vector3.new(0, 32, 224))
		rawset(player, "Character", char)
		player.CharacterAdded:Fire(char)
	end)
	table.insert(players, player)
	profiles[player] = { Coins = 0, XP = 0, Wins = 0, Tags = 0, Crossings = 0, Owned = { None = true }, Equipped = "None" }
end
local Profiles = { load = function() end, get = function(p) return profiles[p] end, save = function() end }
local vipOwners = {}
local Passes = { init = function() end, load = function() end, owns = function(player, id) return id == "VIP" and vipOwners[player] == true end, entitlements = function() return {} end }
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
	task = { wait = function(seconds) return coroutine.yield(seconds) end, delay = function() end, spawn = function(fn, ...)
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
local initialPosition = players[2].Character.HumanoidRootPart.Position
remote.OnServerEvent:Fire(players[2], "VisitVIP")
check(players[2].Character.HumanoidRootPart.Position == initialPosition and events[#events].action == "OpenPasses", "non-owner VIP sidebar opens passes without teleporting")
vipOwners[players[2]] = true
remote.OnServerEvent:Fire(players[2], "VisitVIP")
check(players[2].Character.HumanoidRootPart.Position == initialPosition, "VIP requests have a server cooldown")
now += 1
remote.OnServerEvent:Fire(players[2], "VisitVIP")
check(players[2].Character.HumanoidRootPart.Position.X == 101, "verified VIP enters the lounge from the sidebar")
vipOwners[players[2]] = false
profiles[players[2]].Coins = 120
remote.OnServerEvent:Fire(players[2], "Cosmetic", "RiftSparks")
check(profiles[players[2]].Coins == 0 and profiles[players[2]].AuraEquipped == "RiftSparks" and players[2].Character.RiftCosmetics, "real server cosmetic action spends once and equips native aura")
local seatedHumanoid = players[2].Character:FindFirstChildOfClass("Humanoid")
local gardenSeat
for _, child in ipairs(host.workspace.RiftLobby.RiftGardens:GetChildren()) do if child:IsA("Seat") then gardenSeat = child break end end
local seatPosition = gardenSeat.Position
local seatWeld = instance("Weld")
seatWeld.Name, seatWeld.Part0, seatWeld.Part1, seatWeld.Parent = "SeatWeld", gardenSeat, players[2].Character.HumanoidRootPart, gardenSeat
players[2].Character.HumanoidRootPart.CFrame = gardenSeat.CFrame + r.Vector3.new(0, 2, 0)
seatedHumanoid.Sit = true
rawset(seatedHumanoid, "SeatPart", gardenSeat)
for _ = 1, 200 do
	if host.replicated:GetAttribute("Phase") == "Crossing" then break end
	now += .2
	heartbeat:Fire(.2)
	resume()
end
check(host.replicated:GetAttribute("Phase") == "Crossing", "full server starts a multiplayer chase")
local cosmeticBefore = profiles[players[2]].AuraEquipped
now += 1
remote.OnServerEvent:Fire(players[2], "Cosmetic", "NoAura")
check(profiles[players[2]].AuraEquipped == cosmeticBefore, "in-match cosmetic changes cannot bypass server phase gate")
check(not seatedHumanoid.Sit and not seatWeld.Parent and gardenSeat.Position == seatPosition, "match entry releases seated avatar and leaves anchored chair in place")
local runners, catcher = {}, nil
for _, player in ipairs(players) do
	if player:GetAttribute("Role") == "Runner" then table.insert(runners, player) else catcher = player end
end
check(#runners == 2 and catcher:GetAttribute("Role") == "Catcher", "fair human catcher plus two runners")
local a, b = runners[1], runners[2]
local function root(p) return p.Character.HumanoidRootPart end
local activePosition = root(a).Position
vipOwners[a] = true
now += 1
remote.OnServerEvent:Fire(a, "VisitVIP")
check(root(a).Position == activePosition and a:GetAttribute("Role") == "Runner", "even VIP owners cannot leave an active chase through the sidebar")
vipOwners[a] = false
local deadline = host.replicated:GetAttribute("Deadline")
check(deadline > now and host.replicated:GetAttribute("Chasers_1") == 2, "two first-section stalkers and shared run clock")

-- Confirmed ability authorizes both movement and observer visuals.
remote.OnServerEvent:Fire(a, "Dash", r.Vector3.new(0, 0, 1))
check(a:GetAttribute("DashStartedAt") == now and a.Character:GetAttribute("DashStartedAt") == now, "dash authorizes avatar and costume poses")
local dashEvents = 0
for _, event in ipairs(events) do if event.action == "DashFX" then dashEvents += 1 end end
check(dashEvents == 1 and root(a).AssemblyLinearVelocity.Z == Config.DashSpeed, "approved dash broadcasts once")
remote.OnServerEvent:Fire(a, "Dash", r.Vector3.new(0, 0, 1))
local after = 0
for _, event in ipairs(events) do if event.action == "DashFX" then after += 1 end end
check(after == dashEvents, "cooldown rejects repeat dash without visual")

-- An unconfirmed grab cancelled by a dodge must never convert the runner.
local npc = host.workspace:FindFirstChild("Rift Stalker 1/1")
local npcRoot = npc.HumanoidRootPart
npcRoot.CFrame = r.CFrame.lookAt(root(b).Position + r.Vector3.new(0, 0, -3), root(b).Position)
check(not Captures.tryGrab(b, npc, npcRoot, nil), "fresh arrivals reject grabs during post-Ready protection")
now = math.max(now, b:GetAttribute("SafeUntil") + .1)
check(Captures.tryGrab(b, npc, npcRoot, nil), "real capture service begins legal reach")
root(b).CFrame += r.Vector3.new(12, 0, 0)
now += Config.GrabWindup+.01
Captures.step(now)
check(b:GetAttribute("Role") == "Runner" and not Captures.hasActive(), "dodged reach leaves real server runner intact")
root(b).CFrame -= r.Vector3.new(12, 0, 0)
npcRoot.CFrame = r.CFrame.new(-24, 4, 0)

local function finish(p)
	local stage = p:GetAttribute("CourseStage")
	while p:GetAttribute("CourseStage") == stage and p:GetAttribute("Role") == "Runner" do
		root(p).CFrame += r.Vector3.new(0, 0, 2)
		now += .1
		heartbeat:Fire(.1)
		if p:GetAttribute("Role") == "Escaped" then break end
	end
end
finish(a)
check(a:GetAttribute("CourseStage") == 2 and a:GetAttribute("Role") == "Runner", "finish immediately advances one runner without waiting")
check(b:GetAttribute("CourseStage") == 1 and b:GetAttribute("Role") == "Runner", "slower runner keeps own course")
check((root(a).Position - r.Vector3.new(230, 4, -144)).Magnitude < .001, "new course entry teleports correctly")
check(a:GetAttribute("Stamina") == 100 and a:GetAttribute("DashReadyAt") == 0 and a:GetAttribute("DashStartedAt") == 0, "gate recharges and cancels old dash")
local crystals = 0
for _, event in ipairs(events) do if event.player == a and event.action == "Crystal" then crystals += 1 end end
check(profiles[a].Crossings == 1 and profiles[a].Coins == Config.CrossingCoins + crystals*Config.CrystalCoins, "first finish pays exactly one crossing reward plus collected crystals")
now += 1.1 heartbeat:Fire(1.1)
check(host.replicated:GetAttribute("Chasers_2") == 3, "second course adds three chasers")
check(host.replicated:GetAttribute("Deadline") == deadline, "individual finish does not reset global deadline")
local delta = root(a).Position
root(a).CFrame = r.CFrame.new(0, 4, 124)
now += .1 heartbeat:Fire(.1)
check(a:GetAttribute("CourseStage") == 2 and (root(a).Position - delta).Magnitude < .001, "wrong-course finish exploit rolls back")
finish(b)
now += 1.1 heartbeat:Fire(1.1)
check(catcher:GetAttribute("CourseStage") == 2 and Rules.inCourse(root(catcher).Position.X,root(catcher).Position.Z,Config.Courses[2],Config.StartZ,0) and root(catcher).Position.Z>-84, "human catcher follows into a forward interception station when the original course empties")
check(not host.workspace:FindFirstChild("Rift Stalker 1/1") and host.replicated:GetAttribute("Chasers_1") == 0, "cleared course retires its idle bots")
for stage = 2, 5 do
	finish(a)
	check(profiles[a].Crossings == stage, "one reward per completed section " .. stage)
	if stage < 5 then check(a:GetAttribute("CourseStage") == stage + 1 and a:GetAttribute("Role") == "Runner", "continuous onward section " .. stage) end
end
check(a:GetAttribute("Role") == "Escaped" and a:GetAttribute("CourseStage") == 5, "only final gate grants escape")
check(profiles[a].Wins == 0, "no win before round resolves")
-- A real course fall changes the runner role and uses the safe entry deck.
root(b).CFrame = r.CFrame.new(root(b).Position.X, -11, root(b).Position.Z)
now += .1 heartbeat:Fire(.1)
check(b:GetAttribute("Role") == "Catcher" and root(b).Position.Y == Config.FloorY, "void fall joins catchers and recovers")
resume()
check(host.replicated:GetAttribute("Phase") == "Results" and profiles[a].Wins == 1, "finished runner wins at resolution")
check(a:GetAttribute("Role") == "Spectator" and a:GetAttribute("CourseStage") == 0, "results restore lobby role and course HUD")
check(profiles[b].Wins == 0 and profiles[catcher].Wins == 0, "catchers do not win when a runner escaped")
print("PASS: " .. passed .. " actual server dash, independent course progression, capture dodge, rewards and results assertions")
