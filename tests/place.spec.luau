local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile("dist/RiftValley.rbxlx"))
local workspace = game:GetService("Workspace")
local arena = workspace:FindFirstChild("RiftArena")
assert(arena and arena:IsA("Model"), "arena model missing")
assert(arena.ArenaFloor.Size == roblox.Vector3.new(156, 4, 244), "floor dimensions lost in XML")
assert(arena.ArenaFloor.Material == roblox.Enum.Material.Concrete, "material enum serialization")
assert(arena.ArenaFloor.Color.R > .2, "color serialization")
local floorCount, colliderCount = 0, 0
for _, instance in ipairs(workspace:GetDescendants()) do
	if instance:IsA("BasePart") then
		assert(instance.Anchored, "unanchored map object: " .. instance.Name)
		floorCount += 1
		if instance.CanCollide then colliderCount += 1 end
	end
end
assert(floorCount >= 300 and colliderCount > 90, "arena geometry absent")
local shared = game:GetService("ReplicatedStorage").RiftShared
assert(shared.Config.Source == fs.readFile("src/shared/Config.luau"), "config differs from source")
assert(shared.Rules.Source == fs.readFile("src/shared/Rules.luau"), "rules differ from source")
assert(shared.PassIds.Source == fs.readFile("src/shared/PassIds.luau"), "pass IDs differ from source")
assert(shared.CreatureMotion.Source == fs.readFile("src/shared/CreatureMotion.luau"), "animation clips differ from source")
assert(shared.MusicIds.Source == fs.readFile("src/shared/MusicIds.luau"), "music IDs differ from source")
local server = game:GetService("ServerScriptService")
assert(server.Game.Source == fs.readFile("src/server/Game.server.luau"), "server differs from source")
assert(server.ProfileStore.Source == fs.readFile("src/server/ProfileStore.luau"), "profiles differ from source")
assert(server.PassService.Source == fs.readFile("src/server/PassService.luau"), "pass service differs from source")
assert(server.WorldService.Source == fs.readFile("src/server/WorldService.luau"), "world service differs from source")
assert(server.CreatureRig.Source == fs.readFile("src/server/CreatureRig.luau"), "creature rig differs from source")
assert(server.CaptureService.Source == fs.readFile("src/server/CaptureService.luau"), "capture service differs from source")
assert(server.StyleService.Source == fs.readFile("src/server/StyleService.luau"), "cosmetic service differs from source")
for _, name in ipairs({ "CourseService", "PlaytestService", "CatcherNavigation", "MasteryService", "PracticeService", "VIPGearService", "LaunchService" }) do assert(server:FindFirstChild(name).Source == fs.readFile("src/server/" .. name .. ".luau"), "new server module embedded: " .. name) end
local client = game:GetService("StarterPlayer").StarterPlayerScripts.Controller
assert(client.Source == fs.readFile("src/client/Controller.client.luau"), "client differs from source")
assert(game:GetService("StarterPlayer").StarterPlayerScripts.CreatureAnimation.Source == fs.readFile("src/client/CreatureAnimation.client.luau"), "creature animation differs from source")
for _, name in ipairs({ "CaptureEffects", "HoverIcons", "BuffEffects", "Music", "DashEffects", "ThreatEffects", "Mastery", "VictoryEffects", "VIPGear", "Journey" }) do
	assert(game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild(name).Source == fs.readFile("src/client/" .. name .. ".client.luau"), "embedded client script: " .. name)
end
assert(game:GetService("ReplicatedStorage").RiftAction.ClassName == "RemoteEvent", "action remote missing")
assert(not server.LoadStringEnabled, "loadstring enabled")
local lobby = workspace.RiftLobby
assert(#arena.ChaseCourses:GetChildren() == 4, "four onward obstacle sections")
local Config = require("../src/shared/Config")
for stage = 2, 5 do
	local course = arena.ChaseCourses:FindFirstChild("Course_" .. stage)
	local definition = Config.Courses[stage]
	assert(course and course.CourseFinish.CFrame.Position.Z == definition.z + Config.ArenaHalfLength, "course finish aligns with server")
	local floors, walls, hurdles, pads, steps, edges = 0, 0, 0, 0, 0, 0
	local segments = {}
	for _, part in ipairs(course:GetChildren()) do
		if not part:IsA("BasePart") then continue end
		if part.Name == "CourseFloor" then
			floors += 1
			table.insert(segments, { start = part.CFrame.Position.Z - part.Size.Z/2, finish = part.CFrame.Position.Z + part.Size.Z/2 })
			assert(part.CanCollide and part.Size.X >= 18 and part.Size.Y == 4, "course floor supports characters")
		end
		if part.Name == "SlalomWall" then walls += 1 assert(part.Size.X < definition.halfWidth*2 - 12, "slalom wall leaves a reachable passage") end
		if part.Name == "SlalomWall" and stage == 3 then assert(part.Size.Y >= 5.5, "slalom gates require an actual route choice") end
		if part.Name == "JumpHurdle" then hurdles += 1 assert(part.Size.Y <= 3.21, "hurdle within normal jump height") end
		if part.Name == "CourseStep" then steps += 1 assert(part.CanCollide and part.Size.Y <= 3.41, "intro step supports an ordinary jump") end
		if part.Name == "JumpEdge" then edges += 1 assert(not part.CanCollide and part.Material == roblox.Enum.Material.Neon, "jump markers are visible and nonblocking") end
		if string.sub(part.Name, 1, 8) == "Recharge" then
			pads += 1
			assert(part.HoverIcon and not part.CanCollide and part.HoverIcon.Kind, "typed hover pickup on course")
			assert(math.abs(part.CFrame.Position.Z-definition.z) < Config.ArenaHalfLength, "pickup lies inside the race before the finish")
			local supported = false
			for _, floor in ipairs(course:GetChildren()) do
				if floor:IsA("BasePart") and floor.CanCollide and (floor.Name == "CourseFloor" or floor.Name == "CourseBypassLane") then
					if math.abs(part.CFrame.Position.X-floor.CFrame.Position.X) < floor.Size.X/2 and math.abs(part.CFrame.Position.Z-floor.CFrame.Position.Z) < floor.Size.Z/2 then supported = true end
				end
			end
			assert(supported, "resource pickup has permanent ground")
		end
	end
	table.sort(segments, function(a, b) return a.start < b.start end)
	for i = 2, #segments do
		local gap = segments[i].start - segments[i-1].finish
		assert(gap >= 5.9 and gap <= 7.1, "real jumping gap remains within normal jump reach")
	end
	assert(pads == 2 and (stage ~= 3 or walls == 2) and (stage ~= 5 or hurdles == 2), "distinct section obstacles")
	assert((stage == 2 or stage == 3) and floors == 1 or (stage >= 4 and floors > 1), "intro has continuous ground; later gaps remain genuine")
	if stage == 2 then
		assert(steps == 3, "first onward course has three raised jump obstacles")
		-- Regress the reported fall after walking into the next course. The whole
		-- usable width must have floor beneath it, including all former gap cuts.
		for x = definition.x - 27, definition.x + 27 do
			for z = definition.z - Config.StartZ, definition.z + Config.StartZ do
				local supported = false
				for _, ground in ipairs(course:GetChildren()) do
					if ground:IsA("BasePart") and ground.CanCollide and (ground.Name == "CourseFloor" or ground.Name == "CourseDeck") then
						local pos = ground.CFrame.Position
						if math.abs(x-pos.X) <= ground.Size.X/2 and math.abs(z-pos.Z) <= ground.Size.Z/2 and pos.Y+ground.Size.Y/2 == 0 then supported = true break end
					end
				end
				assert(supported, "unsupported intro course ground at " .. x .. "," .. z)
			end
		end
	elseif stage >= 4 then assert(edges >= (stage == 4 and 6 or 4), "both sides of later gaps have warning edges") end
	if stage >= 4 then
		local bypass = 0
		for _, part in ipairs(course:GetChildren()) do if part.Name == "CourseBypass" then bypass += 1 assert(part.CanCollide and part.Size.X >= 12, "continuous side detours are usable") end end
		assert(bypass == (stage == 4 and 3 or 2), "each real gap has a deliberately placed alternating detour")
		assert(not course:FindFirstChild("CourseBypassLane"), "no straight perimeter lane bypasses the course")
	end
end
assert(math.abs(lobby.LobbyFloor.CFrame.Position.Y + lobby.LobbyFloor.Size.Y / 2 - 28) < 0.01, "lobby must overlook the arena wall")
assert(lobby.LobbySpawn.CFrame.Position.Y > 28, "spawn must stay on the raised lobby")
local light = game:GetService("Lighting")
assert(light.Ambient.R > 0.6 and light.EnvironmentDiffuseScale > 0.6 and light.ExposureCompensation > 0.2, "scene lighting too dark")
assert(light.ValleyMist.Density < 0.2, "mist obscures the arena")
local lampCount, gardenLights, seats, trees, vipLights, vipSeats, voteLights, destinationLights = 0, 0, 0, 0, 0, 0, 0, 0
for _, instance in ipairs(lobby:GetDescendants()) do
	if instance:IsA("PointLight") then
		if instance.Name == "LobbyFill" then lampCount += 1 assert(instance.Range >= 50, "lobby fill lamp range too short")
		elseif instance.Name == "VIPGlow" then vipLights += 1 assert(instance.Range >= 16 and not instance.Shadows, "VIP ambient lighting")
		elseif instance.Name == "VoteGlow" then voteLights += 1 assert(instance.Range == 14 and not instance.Shadows, "map-vote glow stays local")
		elseif instance.Name == "DestinationGlow" then destinationLights += 1 assert(instance.Range == 18 and not instance.Shadows, "destination glow stays local")
		elseif instance.Name == "ActivityGlow" then assert(instance.Range == 14 and not instance.Shadows, "activity glow stays local")
		else gardenLights += 1 assert(instance.Range >= 24 and not instance.Shadows, "readable, bounded decorative lighting") end
	end
	if instance:IsA("Seat") then
		if instance:IsDescendantOf(lobby.VIPInterior) then vipSeats += 1 else seats += 1 end
		assert(instance.Anchored and not instance.Disabled, "seat must be usable and anchored")
	end
	if instance.Name == "PlazaTreeTrunk" then trees += 1 end
end
assert(lampCount == 2 and gardenLights == 9 and seats == 12 and trees == 8, "expanded garden lighting, seating and flowering trees")
assert(voteLights == 3, "three map emblems have bounded neon glow")
assert(destinationLights == 2, "shop and VIP each have one bounded light")
for _, anchor in ipairs({lobby.PassVendor, lobby.VIPPortal}) do
	local model, tag = anchor.DestinationVisual, anchor.DestinationName
	assert(model.PrimaryPart == model.DestinationCore and tag.Adornee == model.PrimaryPart, "name follows the native destination core")
	assert(tag.Title.BackgroundTransparency == 1 and tag.Title.TextSize == 16 and string.find(tag.Title.FontFace.Family, "FredokaOne", 1, true), "destination tag matches the small map-name style")
	assert(tag.StudsOffset.Y > 5 and tag.Size.Y.Offset == 26 and not tag.AlwaysOnTop, "destination names stay above sculptures without screen obstruction")
	local parts = 0
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			parts += 1
			assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery and not part.CastShadow, "destination decoration never blocks or intercepts movement")
		end
	end
	assert(parts >= 40 and parts <= 60, "bounded solid 3D destination geometry")
end
assert(lobby.PassVendor.DestinationName.Title.Text == "Shop" and lobby.VIPPortal.DestinationName.Title.Text == "VIP Lounge", "short destination names")
for _, container in ipairs({workspace.RiftArena, game:GetService("ServerStorage").RiftMaps, game:GetService("ServerStorage").RiftMechanics}) do
	for _, obj in ipairs(container:GetDescendants()) do
		if obj:IsA("TextLabel") then assert(obj.Text == "FINISH!", "stray map words or movement signs remain: " .. obj.Text) end
	end
end
assert(vipLights == 6 and vipSeats == 7 and lobby.VIPInterior.StyleMirror and lobby.VIPInterior.ChandelierHeart, "styled lounge, seating, chandelier and wardrobe")
assert(lobby.VIPInterior.LoungeTable.CFrame.Position.Z + lobby.VIPInterior.LoungeTable.Size.Z/2 < 222, "VIP arrival stays clear of the coffee table")
assert(lobby.PlazaFloor.Size == roblox.Vector3.new(144, 5, 96), "expanded public plaza dimensions")
local oldArea = lobby.LobbyFloor.Size.X*lobby.LobbyFloor.Size.Z
local publicArea = oldArea + lobby.PlazaFloor.Size.X*lobby.PlazaFloor.Size.Z + 104*4
assert(publicArea == 22560 and publicArea/oldArea > 2.7, "public floor area expands by at least 2.7x")
assert(lobby.PlazaConnector.CFrame.Position.Z - lobby.PlazaConnector.Size.Z/2 <= 272 and lobby.PlazaConnector.CFrame.Position.Z + lobby.PlazaConnector.Size.Z/2 >= 276, "connector joins both floors")
assert(lobby.RiftGardens.RiftFountain.RiftHeart and lobby.LobbyBack.CFrame.Position.Z > 370, "fountain present and old back wall opens into plaza")
local fountainWater, lanterns, islands = 0, 0, 0
for _, part in ipairs(lobby.RiftGardens:GetDescendants()) do
	if part.Name == "RiftWater" then fountainWater += 1 assert(not part.CanCollide, "fountain water must remain decorative") end
	if part.Name == "HangingLantern" then lanterns += 1 assert(part.CFrame.Position.Y > 40, "lanterns leave walking/jumping clearance") end
	if part.Name == "FloatingGardenRock" then islands += 1 assert(not part.CanCollide, "outer islands remain decorative") end
end
assert(fountainWater == 11 and lanterns == 34 and islands == 4, "fountain, overhead lights and floating islands")
for _, part in ipairs(lobby:GetDescendants()) do
	if part:IsA("BasePart") and part.CanCollide then
		local pos, size = part.CFrame.Position, part.Size
		for z = 272, 300, 2 do
			local blocksEntry = math.abs(pos.X) < size.X/2 + 1 and math.abs(pos.Z-z) < size.Z/2 + 1
				and pos.Y + size.Y/2 > 30 and pos.Y - size.Y/2 < 34
			assert(not blocksEntry, "old wall or decoration blocks garden entry: " .. part.Name)
		end
	end
end
local templates = game:GetService("ServerStorage").RiftMaps
assert(#templates:GetChildren() == 3, "three map templates required")
for _, map in ipairs(templates:GetChildren()) do
	local crystals, pads, covers = 0, 0, 0
	for _, part in ipairs(map:GetDescendants()) do
		if part:IsA("BasePart") then
			assert(part.Anchored, "map template contains loose parts")
			local pos = part.CFrame.Position
			assert(math.abs(pos.X) + part.Size.X/2 <= 78, "map objects cross arena boundary")
			if string.sub(part.Name, 1, 8) == "Crystal_" then crystals += 1 assert(not part.CanCollide, "pickups block runners") end
			if string.sub(part.Name, 1, 9) == "Recharge_" then pads += 1 end
			if part.Name == "RouteCover" then covers += 1 end
			if part.CanCollide then assert(math.abs(pos.X) - part.Size.X/2 >= 20, "center route blocked") end
		end
	end
	assert(crystals == 8 and pads == 4 and covers == 8, "map interactions or cover missing: " .. map.Name)
end
local prompts = 0
for _, obj in ipairs(lobby:GetDescendants()) do if obj:IsA("ProximityPrompt") then prompts += 1 assert(obj.MaxActivationDistance <= 12, "prompt range") end end
assert(prompts == 5 and lobby.LoungeFloor and not lobby:FindFirstChild("CelebrationBell"), "parkour return prompts removed; four floor plates remain")
assert(not lobby.Parkour:FindFirstChild("ParkourExit") and not lobby.Parkour:FindFirstChild("ParkourFinishExit"),"parkour has no return-to-lobby icons")
assert(lobby.Parkour.ParkourStart.ActivityVisual and lobby.RiftGardens.MasteryGateway.MasteryPortal.ActivityVisual,"parkour stopwatch and mastery trophy are native 3D")
for _,obj in ipairs(lobby.Parkour:GetDescendants()) do if obj:IsA("TextLabel") then assert(not string.find(obj.Text,"24 JUMPS",1,true),"old parkour board remains") end end
for _,plate in ipairs({lobby.Vote_CrystalGrove,lobby.Vote_SunsetRuins,lobby.Vote_NeonHarbor,lobby.Parkour.ParkourStart}) do
	assert(plate.CanCollide and plate.Transparency==0 and plate.PressurePlate and not plate:FindFirstChildOfClass("ProximityPrompt") and not plate:FindFirstChild("HoverIcon"),"pressure plate must activate by stepping")
end
for _, obj in ipairs(lobby:GetDescendants()) do
	if obj:IsA("ProximityPrompt") then
		assert(obj.HoldDuration == 0 and obj.Style == roblox.Enum.ProximityPromptStyle.Custom, "interaction should be tap/click hover icon")
		assert(obj.Parent.Transparency == 1 and not obj.Parent.CanCollide and obj.Parent.HoverIcon, "interactive anchor still looks like a plate")
	end
end
local barriers = lobby.SpawnBarriers:GetChildren()
assert(#barriers == 29, "complete public lobby, lounge and activity barriers; parkour remains open")
for _, part in ipairs(barriers) do assert(part.Transparency == 1 and part.CanCollide and part.Anchored and not part.CastShadow, "barrier must be invisible, solid and anchored") end
assert(lobby.Parkour.ParkourBridge.Size.Z == 16 and lobby.Parkour.ParkourStart, "parkour bridge entry")
assert(not lobby.Parkour:FindFirstChild("ParkourFloor") and not lobby.Parkour:FindFirstChild("StepPillar"), "safety floor/pillars defeat real falls")
local previous = lobby.Parkour.ParkourDock
for i = 1, Config.ParkourSteps do
	local part = lobby.Parkour:FindFirstChild("ParkourStep_" .. i)
	assert(part and part.CanCollide, "missing solid stepping stone")
	local delta = part.CFrame.Position - previous.CFrame.Position
	local horizontal = roblox.Vector3.new(delta.X, 0, delta.Z).Magnitude
	local gapX = math.max(0, math.abs(delta.X) - (part.Size.X + previous.Size.X)/2)
	local gapZ = math.max(0, math.abs(delta.Z) - (part.Size.Z + previous.Size.Z)/2)
local rise = part.CFrame.Position.Y + part.Size.Y/2 - previous.CFrame.Position.Y - previous.Size.Y/2
assert(rise <= 2.1 and math.sqrt(gapX*gapX + gapZ*gapZ) < 8, "parkour gap exceeds normal jump allowance")
	previous = part
end
local harbor = templates.NeonHarbor
for _, part in ipairs(harbor:GetChildren()) do
	if part:IsA("BasePart") and part.Name == "Sign" and part:FindFirstChild("Lettering") and part.Lettering.Text.Text == "RIFT\nPORT" then
		for _, post in ipairs(harbor:GetChildren()) do
			if post:IsA("BasePart") and post.Name == "HarborPost" and math.abs(post.CFrame.Position.X - part.CFrame.Position.X) < .01 and math.abs(post.CFrame.Position.Z - part.CFrame.Position.Z) < 3 then
				assert(part.CFrame.Position.Z + part.Size.Z/2 < post.CFrame.Position.Z - post.Size.Z/2, "pole intersects port sign")
			end
		end
	end
end
local backdrop = workspace.RiftBackdrop
assert(backdrop.SkyCanopy and backdrop.RiftMoon and light.RiftNight and light.ClockTime < 6, "themed night backdrop missing")
for _, part in ipairs(backdrop:GetChildren()) do assert(not part.CanCollide, "background blocks gameplay") end
for _, part in ipairs(workspace:GetDescendants()) do if part:IsA("BasePart") then assert(part.Size.X <= 2048 and part.Size.Y <= 2048 and part.Size.Z <= 2048, "part exceeds Roblox size limit") end end
for _, part in ipairs(workspace.ValleyScenery:GetDescendants()) do
	if part:IsA("BasePart") and part.CanCollide then
		local pos = part.CFrame.Position
		local overlaps = pos.Z + part.Size.Z/2 >= 190 and pos.Z - part.Size.Z/2 <= 274 and pos.X + part.Size.X/2 >= -145 and pos.X - part.Size.X/2 <= 126 and pos.Y + part.Size.Y/2 > 28
		assert(not overlaps, "scenery intersects the lobby/parkour: " .. part.Name)
		local frame = part.CFrame
		local hx = math.abs(frame.RightVector.X)*part.Size.X/2 + math.abs(frame.LookVector.X)*part.Size.Z/2
		local hz = math.abs(frame.RightVector.Z)*part.Size.X/2 + math.abs(frame.LookVector.Z)*part.Size.Z/2
		for _, definition in ipairs(Config.Courses) do
			local intersects = pos.X + hx > definition.x - definition.halfWidth and pos.X - hx < definition.x + definition.halfWidth
				and pos.Z + hz > definition.z - Config.StartZ - 12 and pos.Z - hz < definition.z + Config.StartZ + 12
			assert(not intersects, "scenery intersects chase course: " .. part.Name)
		end
	end
end
local binary = roblox.serializePlace(game)
fs.writeFile("dist/RiftValley.rbxl", binary)
local reopened = roblox.deserializePlace(binary)
assert(reopened:GetService("ServerScriptService").Game.Source == server.Game.Source, "binary roundtrip lost scripts")
assert(reopened:GetService("Lighting").Ambient.R > 0.6, "binary roundtrip lost ambient lighting")
print("PASS: native place deserialize, " .. floorCount .. " map parts, exact embedded scripts, binary roundtrip")
