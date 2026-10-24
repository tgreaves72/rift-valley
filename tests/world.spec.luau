local fs, luau, roblox = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local host = require("./native-host")()
local World
local env = {
	workspace = host.workspace, Vector3 = roblox.Vector3, Color3 = roblox.Color3, Enum = roblox.Enum,
	require = function(name) if name.Name == "Config" then return Config end return Rules end,
	game = { GetService = function(_, name)
		if name == "Players" then return { GetPlayers = function() return {} end } end
		return host.wrap(host.model:GetService(name))
	end },
}
World = luau.load(fs.readFile("src/server/WorldService.luau"), { environment = env })()
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local p = { lobby = true, attrs = {}, SetAttribute = function(self, key, val) self.attrs[key] = val end }
local shop, lounge, celebrations, styles = 0, 0, 0, 0
World.init({ inLobby = function(who) return who.lobby end, openShop = function() shop += 1 end, lounge = function() lounge += 1 end, returnLobby = function() end, celebrate = function() celebrations += 1 end,
	isVIP = function(who) return who.vip == true end, openStyles = function() styles += 1 end })
check(#host.workspace.RiftArena:GetChildren() > 0 and host.replicated:GetAttribute("MapName") == "Crystal Grove", "first map initializes")
check(#World.getInteractions() == 12, "four pads and eight crystals")
for stage = 1, 5 do
	local counts = { Stamina = 0, Dash = 0, Crystal = 0 }
	for _, pickup in ipairs(World.getInteractions(stage)) do counts[pickup.kind] += 1 end
	check(counts.Stamina == (stage == 1 and 2 or 1) and counts.Dash == (stage == 1 and 2 or 1), "each course supplies distinct stamina and dash pickups")
end
check(not World.vote(p, "CrystalGrove"), "no voting before intermission")
World.startVoting()
check(World.vote(p, "NeonHarbor") and p.attrs.MapVote == "NeonHarbor", "valid lobby vote")
check(not World.vote(p, "Invalid") and host.replicated:GetAttribute("Votes_NeonHarbor") == 1, "invalid vote cannot corrupt tally")
check(World.vote(p, "SunsetRuins") and host.replicated:GetAttribute("Votes_NeonHarbor") == 0, "changing vote removes prior tally")
p.lobby = false
check(not World.vote(p, "CrystalGrove"), "active players cannot vote")
p.lobby = true
local previous = host.workspace.RiftArena.ActiveMap
check(World.choose(1) == "SunsetRuins" and host.replicated:GetAttribute("MapName") == "Sunset Ruins", "majority loads actual template")
check(previous.Parent == nil and #World.getInteractions() == 12, "old map removed and interactions refreshed")
check(not World.vote(p, "NeonHarbor") and not host.replicated:GetAttribute("VotingOpen"), "voting closes before play")
World.startVoting()
World.vote(p, "NeonHarbor")
World.remove(p)
check(host.replicated:GetAttribute("Votes_NeonHarbor") == 0, "departing player vote removed")
check(World.choose(1) ~= "SunsetRuins", "empty vote rotates away from last map")
-- Prompt authority: an exploited remote prompt cannot operate from a distant root.
local root = { Position = roblox.Vector3.new(0, 32, 224) }
p.Character = { FindFirstChild = function() return root end, FindFirstChildOfClass = function() return { Health = 100 } end }
local vendor = host.workspace.RiftLobby.PassVendor
vendor:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p)
check(shop == 0, "distant vendor prompt rejected")
root.Position = vendor.Position + roblox.Vector3.new(0, 3, 0)
vendor:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p)
check(shop == 1, "nearby vendor opens shop")
p.lobby = false
vendor:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p)
check(shop == 1, "in-match player cannot open vendor")
p.lobby = true
check(not host.workspace.RiftLobby:FindFirstChild("CelebrationBell") and celebrations == 0, "spawn has no confetti interaction")
local mirror = host.workspace.RiftLobby.VIPInterior.StyleMirror
root.Position = mirror.Position
mirror:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p)
check(styles == 0 and shop == 2, "non-owner wardrobe trigger redirects to passes")
p.vip = true
mirror:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p)
check(styles == 1, "verified VIP wardrobe opens cosmetic collection")
p.lobby = false
mirror:FindFirstChildOfClass("ProximityPrompt").Triggered:Fire(p)
check(styles == 1, "active match cannot use wardrobe")
print("PASS: " .. passed .. " actual world module assertions with native map cloning")
