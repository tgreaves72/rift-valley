local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local host = require("./native-host")()
local env = { workspace = host.workspace, Vector3 = r.Vector3, Color3 = r.Color3,
	game = { GetService = function(_, name) return host.wrap(host.model:GetService(name)) end },
	require = function(module) return module.Name == "Config" and Config or Rules end }
local Courses = luau.load(fs.readFile("src/server/CourseService.luau"), { environment = env })()
local count = 0
local function check(value, message) assert(value, message) count += 1 end
local previews = {}
local function export(name)
	local parts = {}
	for _, group in ipairs(host.workspace.RiftArena.ActiveMechanics:GetChildren()) do
		for _, part in ipairs(group:GetChildren()) do
			if part:IsA("BasePart") then
				local p, s, c = part.Position, part.Size, part.Color
				local forward = part.CFrame.LookVector
				table.insert(parts, { stage = tonumber(group.Name), name = part.Name, pos = { p.X,p.Y,p.Z }, size = { s.X,s.Y,s.Z }, color = { c.R*255,c.G*255,c.B*255 }, yaw = math.atan2(-forward.X,-forward.Z) })
			end
		end
	end
	previews[name] = parts
end
Courses.activate("CrystalGrove")
export("CrystalGrove")
local grove = host.workspace.RiftArena.ActiveMechanics
local bridge = grove:FindFirstChild("2"):FindFirstChild("GroveBridge")
local point = bridge.Position+r.Vector3.new(0, bridge.Size.Y/2+4, 0)
check(Courses.contact(point, 2, true, 1000), "grounded bridge grants a route boost")
check(not Courses.contact(point, 2, false, 1000), "airborne proximity does not grant boost")
check(not Courses.contact(point, 1, true, 1000), "wrong course cannot grant boost")
for stage = 1, 5 do check(#Courses.interactions(stage) == 2, "two optional shortcut crystals per course") end
Courses.activate("SunsetRuins")
export("SunsetRuins")
check(not grove.Parent, "map switch removes inactive mechanic geometry")
local ruins = host.workspace.RiftArena.ActiveMechanics
local crackingSign=false
for _,part in ipairs(ruins:GetDescendants()) do
	if part:IsA("TextLabel") and part.Text=="CRACKING STONES" then crackingSign=true end
end
check(not crackingSign,"Sunset Ruins has no unwanted cracking-stones sign")
local tile = ruins:FindFirstChild("4"):FindFirstChild("CrumbleTile")
local protectedTiles = 0
for _, part in ipairs(ruins:GetDescendants()) do
	if part:IsA("BasePart") and part.Name == "CrumbleTile" then
		local modifier = part:FindFirstChildOfClass("PathfindingModifier")
		assert(modifier and modifier.Label == "Unstable", "all crumbling shortcuts exclude NPC paths")
		protectedTiles += 1
	end
end
check(protectedTiles == 41, "all forty-one native crumble tiles carry the navigation cost label")
point = tile.Position+r.Vector3.new(0, tile.Size.Y/2+4, 0)
Courses.contact(point, 4, false, 1000)
Courses.step(1002, true)
check(tile.CanCollide, "nearby airborne player cannot trigger collapse")
Courses.contact(point, 4, true, 1002)
Courses.step(1002.9, true)
check(tile.CanCollide and tile.Color.R > .9, "warning precedes collision removal")
Courses.step(1003.11, true)
check(not tile.CanCollide and tile.Transparency > .8, "warned stone actually opens the shortcut gap")
Courses.step(1006.2, true)
check(tile.CanCollide and tile.Transparency == 0, "stone restores for following runners")
Courses.contact(point, 4, true, 1007)
Courses.step(1008.2, true)
Courses.step(1008.3, false)
check(tile.CanCollide and tile.Transparency == 0, "round end resets unstable tiles")
Courses.activate("NeonHarbor")
export("NeonHarbor")
check(not ruins.Parent, "second switch retires previous map mechanics")
local gate = host.workspace.RiftArena.ActiveMechanics:FindFirstChild("2"):FindFirstChild("CargoGate")
local home = gate.Position
Courses.step(1000, true)
local first = gate.Position
Courses.step(1001, true)
check((gate.Position-first).Magnitude > .1 and math.abs(gate.Position.X-home.X) <= 5.01, "cargo moves within bounded route clearance")
Courses.step(1001, false)
check((gate.Position-home).Magnitude < .001 and gate.CanCollide, "cargo stops and resets during intermission")
fs.writeFile("assets/map-mechanics-geometry.json", require("@lune/serde").encode("json", previews))
print("PASS: " .. count .. " actual map-mechanic activation, boost, crumble, reset and cargo assertions")
