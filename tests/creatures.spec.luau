local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local serde = require("@lune/serde")
local host = require("./native-host")()
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) table.insert(self.callbacks, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local added, removed, simulation = signal(), signal(), signal()
local tags = {}
local collection = {
	AddTag = function(_, model) tags[model] = true added:Fire(model) end,
	RemoveTag = function(_, model) tags[model] = nil removed:Fire(model) end,
	GetTagged = function() local out = {} for model in pairs(tags) do table.insert(out, model) end return out end,
	GetInstanceAddedSignal = function() return added end,
	GetInstanceRemovedSignal = function() return removed end,
}
local env = {
	game = { GetService = function(_, name)
		if name == "CollectionService" then return collection end
		if name == "ReplicatedStorage" then return { WaitForChild = function() return { CreatureMotion = "motion", Config = "config" } end } end
		return { PreSimulation = simulation }
	end },
	Instance = { new = function(class) return host.wrap(r.Instance.new(class)) end },
	Vector3 = r.Vector3, Color3 = r.Color3, CFrame = r.CFrame, Enum = r.Enum,
	workspace = { CurrentCamera = { CFrame = r.CFrame.new(0, 10, 25) }, GetServerTimeNow = function() return 1000 end },
}
local Motion = luau.load(fs.readFile("src/shared/CreatureMotion.luau"), { environment = env })()
env.require = function(name) return name == "config" and require("../src/shared/Config") or Motion end
local Creature = luau.load(fs.readFile("src/server/CreatureRig.luau"), { environment = env })()
local npc = Creature.create("Rift Stalker Test", false)
npc.Parent = host.workspace
local root, humanoid = npc.PrimaryPart, npc:FindFirstChildOfClass("Humanoid")
check(root.Name == "HumanoidRootPart" and root.Size == r.Vector3.new(2, 2, 1), "NPC root footprint preserved")
check(humanoid.WalkSpeed == 29 and humanoid.JumpPower == 0 and not humanoid.RequiresNeck, "same chase speed and safe custom neck rig")
check(npc.Torso.CanCollide and npc.Torso.Size == r.Vector3.new(2, 2, 1), "standard collider preserved")
local parts, joints, eyes, claws, externalAssets = 0, 0, 0, 0, 0
for _, obj in ipairs(npc:GetDescendants()) do
	if obj:IsA("BasePart") then
		parts += 1
		check(not obj.Anchored and (obj.Name == "Torso" or not obj.CanCollide), "nonblocking attached visual geometry: " .. obj.Name)
		if obj.Name ~= "HumanoidRootPart" then check(obj.Massless, "cosmetic detail adds no assembly mass") end
		if obj.Name == "GlowingEye" then eyes += 1 check(obj.Material == r.Enum.Material.Neon, "eye glow readable") end
		if obj.Name == "Claw" then claws += 1 end
	elseif obj:IsA("Motor6D") then joints += 1 check(obj.Part0 and obj.Part1 and obj:GetAttribute("RestPose"), "valid pose joint")
	elseif obj:IsA("MeshPart") or obj:IsA("SpecialMesh") or obj:IsA("Decal") then externalAssets += 1 end
end
check(parts < 70 and parts > 40 and joints == 6 and eyes == 2 and claws == 6, "bounded part count and complete monster silhouette")
check(externalAssets == 0 and npc:FindFirstChild("PaleMask") and npc:FindFirstChild("KnuckleHand"), "original modeled features with no mesh dependencies")
Creature.track(npc)
rawset(root, "AssemblyLinearVelocity", r.Vector3.new(0, 0, -29))
rawset(humanoid, "FloorMaterial", r.Enum.Material.Concrete)
luau.load(fs.readFile("src/client/CreatureAnimation.client.luau"), { environment = env })()
local shoulder = npc.Torso:FindFirstChild("CreatureLeftShoulder")
local base = shoulder.C0
simulation:Fire(.016)
check(shoulder.Transform ~= r.CFrame.identity and shoulder.C0 == base, "client animates movement without accumulating rest-pose drift")
local first = shoulder.Transform
simulation:Fire(.016)
check(shoulder.Transform ~= first, "running pose advances")
collection:RemoveTag(npc)
first = shoulder.Transform
simulation:Fire(.016)
check(shoulder.Transform == first, "removed rig stops animation")
local dash = Motion.dash(.08, .22)
check(dash.CreatureSpine ~= r.CFrame.identity and dash.CreatureLeftShoulder ~= r.CFrame.identity, "catcher dash leans and sweeps arms back")
check(Motion.dash(.5, .22).CreatureSpine == r.CFrame.identity, "catcher dash recovers to neutral")

-- Player overlay changes only appearance and restores exact transparency values.
local avatar = host.wrap(r.Instance.new("Model"))
avatar.Name, avatar.Parent = "PlayerAvatar", host.workspace
local function avatarPart(name, transparency, class)
	local obj = host.wrap(r.Instance.new(class or "Part"))
	obj.Name, obj.Transparency, obj.Parent = name, transparency, avatar
	return obj
end
local playerRoot = avatarPart("HumanoidRootPart", 1)
playerRoot.CFrame, playerRoot.Size, playerRoot.CanCollide = r.CFrame.new(10, 4, 20), r.Vector3.new(2, 2, 1), false
local body, face = avatarPart("UpperTorso", .2), avatarPart("Face", .1, "Decal")
local cosmetics = host.wrap(r.Instance.new("Model"))
cosmetics.Name, cosmetics.Parent = "RiftCosmetics", avatar
local cosmeticPart = host.wrap(r.Instance.new("Part"))
cosmeticPart.Name, cosmeticPart.Transparency, cosmeticPart.Parent = "EarnedAura", .15, cosmetics
local cosmeticTransparency = cosmeticPart.Transparency
local bodyTransparency, faceTransparency = body.Transparency, face.Transparency
local playerHumanoid = host.wrap(r.Instance.new("Humanoid"))
playerHumanoid.WalkSpeed, playerHumanoid.Parent = 22, avatar
local skin = Creature.apply(avatar, true)
check(skin and skin.PrimaryPart.CFrame == playerRoot.CFrame and not skin:FindFirstChildOfClass("Humanoid"), "skin fits actual avatar root without a second humanoid")
rawset(skin.PrimaryPart, "AssemblyLinearVelocity", r.Vector3.zero)
rawset(playerHumanoid, "FloorMaterial", r.Enum.Material.Concrete)
avatar:SetAttribute("DashStartedAt", 999.92)
simulation:Fire(.06)
check(skin.PrimaryPart.CreatureSpine.Transform ~= r.CFrame.identity, "replicated character dash poses catcher costume")
avatar:SetAttribute("DashStartedAt", 0)
simulation:Fire(.06)
check(skin.Torso.CreatureLeftShoulder.Transform == r.CFrame.identity, "cancelled creature dash resumes idle")
check(body.Transparency == 1 and face.Transparency == 1 and playerHumanoid.WalkSpeed == 22, "hides avatar but does not modify movement")
check(cosmeticPart.Transparency == cosmeticTransparency, "creature outfit preserves earned aura visibility")
for _, obj in ipairs(skin:GetDescendants()) do if obj:IsA("BasePart") then check(not obj.CanCollide and obj.Massless, "player skin cannot change hitbox or mass") end end
check(Creature.apply(avatar, true) == skin, "appearance refresh reuses skin")
local hat = avatarPart("LateAccessoryHandle", .35)
local hatTransparency = hat.Transparency
avatar.DescendantAdded:Fire(hat)
check(hat.Transparency == 1, "late-loaded accessories hide")
local partCount = #avatar:GetDescendants()
Creature.apply(avatar, false)
check(body.Transparency == bodyTransparency and face.Transparency == faceTransparency and hat.Transparency == hatTransparency and playerRoot.Transparency == 1, "exact avatar appearance restored")
check(not avatar:FindFirstChild("RiftCatcherCreature") and #avatar:GetDescendants() < partCount, "costume removed between rounds")
Creature.apply(avatar, false)
check(playerHumanoid.WalkSpeed == 22 and playerRoot.Size == r.Vector3.new(2, 2, 1), "repeated cleanup preserves controls and collider")

-- Export a posed, anchored design model and a matching render description.
local originalParts = {}
for _, obj in ipairs(npc:GetDescendants()) do if obj:IsA("BasePart") then originalParts[obj] = obj.CFrame end end
local solved = { [root] = true }
for _ = 1, 3 do
	for _, motor in ipairs(npc:GetDescendants()) do
		if motor:IsA("Motor6D") and solved[motor.Part0] then
			motor.Part1.CFrame = motor.Part0.CFrame * motor.C0 * motor.C1:Inverse()
			solved[motor.Part1] = true
		end
	end
end
for _, weld in ipairs(npc:GetDescendants()) do
	if weld:IsA("WeldConstraint") then weld.Part1.CFrame = weld.Part0.CFrame * originalParts[weld.Part0]:Inverse() * originalParts[weld.Part1] end
end
Creature.variant(npc,"Stalker")
local mask, originalMask = npc:FindFirstChild("PaleMask",true), nil
originalMask = mask.Color
local eye = npc:FindFirstChild("GlowingEye",true)
local warningColor, rootSize = eye.Color,root.Size
for _,skin in ipairs({"Grove","Ruins","Harbor"}) do
	Creature.skin(npc,skin)
	check(mask.Color~=originalMask and eye.Color==warningColor and root.Size==rootSize,"earned skin changes visuals while preserving archetype warning and hitbox")
	local skinParts=0
	for _,part in ipairs(npc:GetDescendants()) do if part:IsA("BasePart") then skinParts+=1 end end
	check(skinParts==parts,"earned skin adds no geometry or physics cost")
end
Creature.skin(npc,"Default")
check(mask.Color==originalMask,"default skin restores the original model palette")
Creature.variant(npc,"Bruiser")
local geometry = {}
local function captureGeometry()
	local result = {}
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < .5 then
			local vertices = {}
			for _, z in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, x in ipairs({ -1, 1 }) do
				local v = part.CFrame:PointToWorldSpace(r.Vector3.new(x * part.Size.X/2, y * part.Size.Y/2, z * part.Size.Z/2))
				table.insert(vertices, { v.X, v.Y, v.Z })
			end end end
			table.insert(result, { name = part.Name, vertices = vertices, rgb = { math.floor(part.Color.R*255), math.floor(part.Color.G*255), math.floor(part.Color.B*255) }, wedge = part:IsA("WedgePart") })
		end
	end
	return result
end
for _, part in ipairs(npc:GetDescendants()) do
	if part:IsA("BasePart") then
		if part.Transparency < .5 then
			local vertices = {}
			for _, z in ipairs({ -1, 1 }) do for _, y in ipairs({ -1, 1 }) do for _, x in ipairs({ -1, 1 }) do
				local v = part.CFrame:PointToWorldSpace(r.Vector3.new(x * part.Size.X/2, y * part.Size.Y/2, z * part.Size.Z/2))
				table.insert(vertices, { v.X, v.Y, v.Z })
			end end end
			table.insert(geometry, { name = part.Name, vertices = vertices, rgb = { math.floor(part.Color.R * 255), math.floor(part.Color.G * 255), math.floor(part.Color.B * 255) }, wedge = part:IsA("WedgePart") })
		end
		part.Anchored = true
	end
end
fs.writeFile("assets/catcher-geometry.json", serde.encode("json", geometry, true))
local design = npc.native:Clone()
design.Name = "Rift Stalker Design Preview"
fs.writeFile("dist/RiftStalker-Design.rbxm", r.serializeModel({ design }))
local frames = {}
for index = 0, 11 do
	local poses = Motion.sample("Run", index/12)
	local resolved = { [root] = true }
	for _ = 1, 3 do
		for _, motor in ipairs(npc:GetDescendants()) do
			if motor:IsA("Motor6D") and resolved[motor.Part0] then
				motor.Part1.CFrame = motor.Part0.CFrame * motor.C0 * poses[motor.Name] * motor.C1:Inverse()
				resolved[motor.Part1] = true
			end
		end
	end
	for _, weld in ipairs(npc:GetDescendants()) do
		if weld:IsA("WeldConstraint") then weld.Part1.CFrame = weld.Part0.CFrame * originalParts[weld.Part0]:Inverse() * originalParts[weld.Part1] end
	end
	table.insert(frames, captureGeometry())
end
fs.writeFile("assets/catcher-run-frames.json", serde.encode("json", frames))
print("PASS: " .. passed .. " actual creature rig/animation/avatar restoration assertions; " .. parts .. " parts per stalker")
