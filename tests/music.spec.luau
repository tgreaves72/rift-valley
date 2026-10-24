local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local host = require("./native-host")()
local p, pg = host.wrap(r.Instance.new("Player")), host.wrap(r.Instance.new("PlayerGui"))
pg.Name, pg.Parent = "PlayerGui", p
local sounds = host.wrap(r.Instance.new("SoundService"))
local ids, plays, delayed = { Lobby = 101, CrystalGrove = 102, SunsetRuins = 103, NeonHarbor = 104 }, {}, {}
local env = {
	game = { GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = p } end
		if name == "ReplicatedStorage" then return host.replicated end
		if name == "SoundService" then return sounds end
		return { Create = function(_, obj, _, props) return { Play = function() for key, value in pairs(props) do obj[key] = value end end } end }
	end },
	Instance = { new = function(class)
		local obj = host.wrap(r.Instance.new(class))
		if class == "Sound" then rawset(obj, "Play", function() table.insert(plays, obj) end) rawset(obj, "IsLoaded", true) end
		return obj
	end },
	require = function() return ids end, UDim2 = r.UDim2, UDim = r.UDim, Enum = r.Enum, Color3 = r.Color3,
	TweenInfo = { new = function() return {} end }, task = { delay = function(_, fn) table.insert(delayed, fn) end },
}
p:SetAttribute("Role", "Spectator")
host.replicated:SetAttribute("Phase", "Intermission")
host.replicated:SetAttribute("MapId", "CrystalGrove")
luau.load(fs.readFile("src/client/Music.client.luau"), { environment = env })()
assert(#plays == 1 and plays[1].SoundId == "rbxassetid://101" and plays[1].Looped, "spectators get chill loop")
p:SetAttribute("Role", "Runner")
host.replicated:SetAttribute("Phase", "Crossing")
p:GetAttributeChangedSignal("Role"):Fire()
assert(#plays == 2 and plays[2].SoundId == "rbxassetid://102" and plays[1].Volume == 0, "map score replaces lobby with crossfade")
host.replicated:SetAttribute("MapId", "NeonHarbor")
host.replicated:GetAttributeChangedSignal("MapId"):Fire()
assert(#plays == 3 and plays[3].SoundId == "rbxassetid://104", "map identity switches track")
local button
for _, item in ipairs(pg.RiftMusic:GetChildren()) do if item:IsA("TextButton") then button = item end end
button.Activated:Fire()
assert(plays[3].Volume == 0 and button.Text == "♫ OFF", "local mute works")
button.Activated:Fire()
assert(plays[3].Volume > 0, "unmute restores volume")
p:SetAttribute("CoursePractice",true)
p:SetAttribute("PracticeMapId","SunsetRuins")
host.replicated:SetAttribute("Phase","Intermission")
p:GetAttributeChangedSignal("CoursePractice"):Fire()
assert(#plays==4 and plays[4].SoundId=="rbxassetid://103","practice follows its own theme independently of main lobby phase")
print("PASS: actual music player, lobby/map selection, looping, crossfade and local mute with simulated IDs")
