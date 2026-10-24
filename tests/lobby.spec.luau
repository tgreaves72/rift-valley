local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local host = require("./native-host")()
local time, teleports, notices, celebrations = 1000, 0, {}, 0
rawset(host.workspace, "GetServerTimeNow", function() return time end)
local env = {
	workspace = host.workspace, Vector3 = r.Vector3, Color3 = r.Color3, Enum = r.Enum,
	require = function(name) return name.Name == "Config" and Config or Rules end,
	game = { GetService = function(_, name)
		if name == "Players" then return { GetPlayers = function() return {} end } end
		return host.wrap(host.model:GetService(name))
	end },
}
local World = luau.load(fs.readFile("src/server/WorldService.luau"), { environment = env })()
local root = { Position = r.Vector3.new(-73, 32, 228) }
local humanoid = { Health = 100, FloorMaterial = r.Enum.Material.Concrete }
local p = { lobby = true, vip = false, attrs = {}, SetAttribute = function(self, key, value) self.attrs[key] = value end,
	Character = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return humanoid end } }
World.init({ inLobby = function(who) return who.lobby end, isVIP = function(who) return who.vip end,
	moveLobby = function(_, pos) root.Position = pos teleports += 1 end,
	returnLobby = function() root.Position = r.Vector3.new(0, 32, 224) teleports += 1 end,
	notice = function(_, text) table.insert(notices, text) end, celebrate = function() celebrations += 1 end,
	openShop = function() end, lounge = function() end,
})
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
check(World.beginParkour(p) and p.attrs.ParkourActive and p.attrs.ParkourCheckpoint == 0, "free course starts with server timestamp")
local course = host.workspace.RiftLobby.Parkour
local function stand(index)
	local part = course:FindFirstChild("ParkourStep_" .. index)
	root.Position = part.Position + r.Vector3.new(0, part.Size.Y/2 + 3, 0)
	time += 1
	World.stepLobby(p, root, humanoid)
end
stand(3)
check(p.attrs.ParkourCheckpoint == 0, "later checkpoints cannot skip the sequence")
humanoid.FloorMaterial = r.Enum.Material.Air
stand(1)
check(p.attrs.ParkourCheckpoint == 0, "airborne crossing cannot claim a checkpoint")
humanoid.FloorMaterial = r.Enum.Material.Concrete
stand(1)
check(p.attrs.ParkourCheckpoint == 1, "grounded landing saves checkpoint")
root.Position = r.Vector3.new(-90, 20, 228)
World.stepLobby(p, root, humanoid)
check(teleports == 0 and p.attrs.ParkourCheckpoint == 1, "missed jump produces a genuine fall")
root.Position = r.Vector3.new(-90, 5, 228)
World.stepLobby(p, root, humanoid)
check(teleports == 1 and root.Position.X == 0 and p.attrs.ParkourRetryAvailable and not p.attrs.ParkourActive, "fall recovers safely and offers a deliberate retry")
local beforeRetry = root.Position
check(World.retryParkour(p) and root.Position.X == -73 and not p.attrs.ParkourRetryAvailable, "clicking retry returns to the entry plate")
check(not p.attrs.ParkourActive, "teleport alone never starts a timer in midair")
World.stepLobby(p, root, humanoid)
local restarted = p.attrs.ParkourStartedAt
check(p.attrs.ParkourActive and restarted == time, "standing on the plate starts a fresh server timer")
for index = 1, 7 do stand(index) end
check(World.failParkour(p) and World.canRetryParkour(p) and not p.attrs.ParkourActive, "actual death clears active progress and retains a retry offer")
humanoid.Health = 0
check(not World.retryParkour(p), "dead avatars cannot teleport before respawn")
humanoid.Health = 100
check(World.retryParkour(p), "respawned player can retry at the plate")
World.stepLobby(p, root, humanoid)
local finishBegan = time
for index = 1, Config.ParkourSteps do stand(index) end
check(not p.attrs.ParkourActive and p.attrs.ParkourBest == time-finishBegan and celebrations == 1 and p.attrs.ParkourRetryAvailable, "all platforms finish once with server timing and an optional replay")
local best = p.attrs.ParkourBest
World.stepLobby(p, root, humanoid)
check(celebrations == 1 and p.attrs.ParkourBest == best, "standing on finish cannot repeat completion")
root.Position = r.Vector3.new(0, 32, 300)
World.stepLobby(p, root, humanoid)
check(root.Position.Z == 300 and teleports == 3, "expanded public garden stays accessible")
root.Position = r.Vector3.new(68, 32, 366)
World.stepLobby(p, root, humanoid)
check(root.Position.X == 68 and teleports == 3, "outer garden terrace stays accessible")
root.Position = r.Vector3.new(0, 32, 400)
World.stepLobby(p, root, humanoid)
check(root.Position.Z == 224 and teleports == 4, "escaped spawn position returns to lobby")
root.Position = r.Vector3.new(101, 32, 224)
World.stepLobby(p, root, humanoid)
check(root.Position.X == 0 and teleports == 5, "non-owner cannot bypass lounge portal")
p.vip = true
root.Position = r.Vector3.new(101, 32, 224)
World.stepLobby(p, root, humanoid)
check(root.Position.X == 101 and teleports == 5, "VIP lounge preserved")
p.lobby = false
check(not World.beginParkour(p), "in-match players cannot enter course")
root.Position = r.Vector3.new(0, 4, 0)
World.stepLobby(p, root, humanoid)
check(teleports == 5, "lobby containment never affects active arena players")
p.lobby = true
root.Position = r.Vector3.new(-73, 32, 228)
World.beginParkour(p)
World.resetParkour(p)
check(not p.attrs.ParkourActive and p.attrs.ParkourCheckpoint == 0, "match entry clears course state")
check(Rules.lobbyZone(-57, 32, 228) == "Bridge" and not Rules.lobbyZone(-57, 32, 210), "bridge opening matches invisible wall cutouts")
check(not Rules.lobbyZone(0, 100, 224) and not Rules.lobbyZone(0, 20, 224), "roof/fall boundaries")
check(Rules.lobbyZone(0, 32, 274) == "Main" and Rules.lobbyZone(0, 32, 278) ~= nil, "connector has no recovery gap")
check(Rules.lobbyZone(-72, 32, 372) == "Plaza" and not Rules.lobbyZone(-73, 32, 372), "expanded garden west edge")
check(Rules.lobbyZone(72, 32, 372) == "Plaza" and not Rules.lobbyZone(0, 32, 373), "expanded garden east and rear edges")
check(not Rules.lobbyZone(70, 32, 270), "plaza does not cover the unsupported front shoulder")
print("PASS: " .. passed .. " actual lobby/parkour assertions with native course geometry")
