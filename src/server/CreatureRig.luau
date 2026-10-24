-- Original Rift Stalker: primitive geometry, no external meshes or asset IDs.
-- A standard invisible R6 skeleton keeps the NPC's previous collision footprint.
local CollectionService = game:GetService("CollectionService")
local Creature = {}
local costumes = setmetatable({}, { __mode = "k" })
local fur = Color3.fromRGB(27, 31, 37)
local mane = Color3.fromRGB(45, 48, 54)
local bone = Color3.fromRGB(224, 217, 193)
local eyes = Color3.fromRGB(159, 255, 95)
local violet = Color3.fromRGB(183, 122, 255)

local function part(parent, name, size, frame, color, invisible, class)
	local obj = Instance.new(class or "Part")
	obj.Name, obj.Size, obj.CFrame = name, size, frame
	obj.Color, obj.Material = color, Enum.Material.SmoothPlastic
	obj.CanCollide, obj.CanTouch, obj.CanQuery, obj.Massless = false, false, false, true
	obj.CollisionGroup, obj.Transparency = "RiftCharacters", invisible and 1 or 0
	obj.TopSurface, obj.BottomSurface, obj.Parent = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth, parent
	return obj
end

local function detail(model, base, name, size, offset, color, class, neon)
	local obj = part(model, name, size, base.CFrame * offset, color, false, class)
	if neon then obj.Material = Enum.Material.Neon end
	local weld = Instance.new("WeldConstraint")
	weld.Name, weld.Part0, weld.Part1, weld.Parent = name .. "Weld", base, obj, obj
	return obj
end

function Creature.create(name, cosmetic)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("RiftStalker", true)
	local root = part(model, cosmetic and "CreatureRoot" or "HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), fur, true)
	root.Massless = cosmetic == true
	local torso = part(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), fur, true)
	torso.CanCollide, torso.CanQuery = not cosmetic, not cosmetic
	local head = part(model, "Head", Vector3.new(2, 1, 1), CFrame.new(0, 4.5, 0), fur, true)
	local limbs = {
		part(model, "Left Arm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), fur, true),
		part(model, "Right Arm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), fur, true),
		part(model, "Left Leg", Vector3.new(1, 2, 1), CFrame.new(-.5, 1, 0), fur, true),
		part(model, "Right Leg", Vector3.new(1, 2, 1), CFrame.new(.5, 1, 0), fur, true),
	}
	local function joint(name_, a, b, c0, c1)
		local motor = Instance.new("Motor6D")
		motor.Name, motor.Part0, motor.Part1 = name_, a, b
		motor.C0, motor.C1 = c0, c1
		motor:SetAttribute("RestPose", c0)
		motor.Parent = a
		return motor
	end
	-- Names stay distinct from a human avatar's normal animation joints.
	joint("CreatureSpine", root, torso, CFrame.new(0, -.1, 0) * CFrame.Angles(math.rad(-18), 0, 0), CFrame.identity)
	joint("CreatureNeck", torso, head, CFrame.new(0, 1.25, -.65) * CFrame.Angles(math.rad(12), 0, 0), CFrame.new(0, -.45, 0))
	joint("CreatureLeftShoulder", torso, limbs[1], CFrame.new(-2.1, .85, -.1) * CFrame.Angles(.16, 0, -.12), CFrame.new(0, .85, 0))
	joint("CreatureRightShoulder", torso, limbs[2], CFrame.new(2.1, .85, -.1) * CFrame.Angles(.16, 0, .12), CFrame.new(0, .85, 0))
	joint("CreatureLeftHip", torso, limbs[3], CFrame.new(-.65, -1, 0), CFrame.new(0, 1, 0))
	joint("CreatureRightHip", torso, limbs[4], CFrame.new(.65, -1, 0), CFrame.new(0, 1, 0))

	detail(model, torso, "HulkingChest", Vector3.new(3.7, 2.65, 2), CFrame.new(0, .1, 0), fur)
	detail(model, torso, "ShoulderHump", Vector3.new(4.2, 1.35, 2.1), CFrame.new(0, 1.05, .4), mane)
	detail(model, torso, "ChestPlate", Vector3.new(2.6, 1.8, .3), CFrame.new(0, 0, -1.05), Color3.fromRGB(56, 58, 63))
	for _, side in ipairs({ -1, 1 }) do
		for index = 1, 3 do
			detail(model, torso, "ManeTuft", Vector3.new(.8, 1.7, 1.3), CFrame.new(side * (1.3 + .27 * index), .65 - .35 * index, .45) * CFrame.Angles(0, 0, side * math.rad(30)), mane, "WedgePart")
		end
		detail(model, head, "Ear", Vector3.new(.55, .8, .65), CFrame.new(side * 1.2, .25, .05) * CFrame.Angles(0, 0, side * .25), fur)
		detail(model, head, "Horn", Vector3.new(.5, 1.15, .6), CFrame.new(side * .83, 1.05, .15) * CFrame.Angles(-.15, 0, -side * .25), mane, "WedgePart")
		detail(model, head, "EyeSocket", Vector3.new(.85, .58, .25), CFrame.new(side * .52, .2, -.95), fur)
		detail(model, head, "GlowingEye", Vector3.new(.48, .25, .15), CFrame.new(side * .52, .19, -1.12) * CFrame.Angles(0, 0, -side * .18), eyes, nil, true)
		detail(model, head, "Brow", Vector3.new(.9, .32, .42), CFrame.new(side * .52, .53, -1.02) * CFrame.Angles(0, 0, side * -.22), bone)
		detail(model, head, "Cheek", Vector3.new(.5, .9, .4), CFrame.new(side * .83, -.3, -.85) * CFrame.Angles(0, 0, -side * .16), bone)
		detail(model, head, "Fang", Vector3.new(.22, .6, .22), CFrame.new(side * .62, -.73, -1.14) * CFrame.Angles(math.pi, 0, 0), bone, "WedgePart")
	end
	detail(model, head, "HeadMane", Vector3.new(2.65, 2.05, 1.6), CFrame.new(0, .15, .15), mane)
	detail(model, head, "PaleMask", Vector3.new(2.1, 1.7, .7), CFrame.new(0, -.02, -.65), bone)
	-- Eyes and mouth sit forward of the face, keeping features readable in motion.
	detail(model, head, "Nose", Vector3.new(.48, .45, .4), CFrame.new(0, -.16, -1.06), fur)
	detail(model, head, "Mouth", Vector3.new(1.35, .5, .2), CFrame.new(0, -.56, -1.1), Color3.fromRGB(31, 19, 31))
	detail(model, head, "LowerJaw", Vector3.new(1.35, .3, .6), CFrame.new(0, -.88, -.78), bone)
	detail(model, head, "Tongue", Vector3.new(.42, .65, .19), CFrame.new(0, -.93, -1.16) * CFrame.Angles(.25, 0, 0), Color3.fromRGB(154, 97, 160))
	for index, limb in ipairs(limbs) do
		if index <= 2 then
			detail(model, limb, "LongForearm", Vector3.new(1.3, 3.25, 1.35), CFrame.new(0, -.6, 0), fur)
			detail(model, limb, "KnuckleHand", Vector3.new(1.6, 1.05, 1.7), CFrame.new(0, -2, -.28), mane)
			for finger = -1, 1 do detail(model, limb, "Claw", Vector3.new(.22, .3, .65), CFrame.new(finger * .45, -2.25, -1.24) * CFrame.Angles(.15, 0, 0), bone, "WedgePart") end
		else
			detail(model, limb, "Haunch", Vector3.new(1.25, 1.65, 1.4), CFrame.new(0, .12, 0), fur)
			detail(model, limb, "BroadFoot", Vector3.new(1.3, .65, 1.9), CFrame.new(0, -.72, -.38), mane)
		end
	end
	model.PrimaryPart = root
	if not cosmetic then
		local humanoid = Instance.new("Humanoid")
		humanoid.DisplayName = "RIFT STALKER"
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower = 29, 0, true
		humanoid.RequiresNeck = false
		humanoid.NameDisplayDistance = 40
		humanoid.Parent = model
		local outline = Instance.new("Highlight")
		outline.FillColor, outline.FillTransparency, outline.OutlineColor = violet, .96, violet
		outline.OutlineTransparency, outline.DepthMode, outline.Parent = .45, Enum.HighlightDepthMode.Occluded, model
	end
	return model
end

function Creature.track(model) CollectionService:AddTag(model, "RiftCreature") end

function Creature.variant(model, kind)
	model:SetAttribute("Archetype", kind)
	local tint = kind == "Bruiser" and Color3.fromRGB(255, 194, 102) or Color3.fromRGB(107, 226, 255)
	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name == "GlowingEye" or obj.Name == "ChestPlate") then obj.Color = tint end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayName = kind == "Bruiser" and "RIFT BRUISER" or "CHARGE STALKER" end
end

-- Recolor only existing decorative parts. Skeleton, hitbox, eyes and movement
-- remain identical so mastery cosmetics never hide the archetype warning color.
function Creature.skin(model, key)
	local palettes = {
		Grove = { body = {35,73,61}, mane = {63,113,78}, mask = {210,245,197}, accent = {123,255,176} },
		Ruins = { body = {76,47,40}, mane = {118,73,52}, mask = {255,220,160}, accent = {255,187,125} },
		Harbor = { body = {35,44,82}, mane = {70,74,132}, mask = {202,229,255}, accent = {140,209,255} },
	}
	local palette = palettes[key]
	for _, part in ipairs(model:GetDescendants()) do
		if not part:IsA("BasePart") or part.Transparency >= 1 then continue end
		local name = part.Name
		if name == "GlowingEye" or name == "ChestPlate" then continue end
		local original = part:GetAttribute("SkinBaseColor")
		if not original then original = part.Color part:SetAttribute("SkinBaseColor",original) end
		if not palette then part.Color = original continue end
		local color = palette.body
		if name == "PaleMask" or name == "Brow" or name == "Cheek" or name == "Fang" or name == "Claw" or name == "LowerJaw" then color = palette.mask
		elseif name == "Horn" then color = palette.accent
		elseif name == "HeadMane" or name == "ManeTuft" or name == "ShoulderHump" or name == "KnuckleHand" then color = palette.mane
		elseif name == "EyeSocket" or name == "Mouth" or name == "Tongue" then continue end
		part.Color = Color3.fromRGB(unpack(color))
	end
	model:SetAttribute("MasterySkin", key)
end

function Creature.apply(character, enabled)
	local current = costumes[character]
	if enabled and current and current.model.Parent then return current.model end
	if current then
		current.connection:Disconnect()
		for obj, transparency in pairs(current.hidden) do if obj.Parent then obj.Transparency = transparency end end
		CollectionService:RemoveTag(current.model, "RiftCreature")
		current.model:Destroy()
		costumes[character] = nil
	end
	if not enabled then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local model = Creature.create("RiftCatcherCreature", true)
	local state = { model = model, hidden = {} }
	local function hide(obj)
		if obj:IsDescendantOf(model) or obj:FindFirstAncestor("RiftCosmetics") then return end
		if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
			if state.hidden[obj] == nil then state.hidden[obj] = obj.Transparency end
			obj.Transparency = 1
		end
	end
	for _, obj in ipairs(character:GetDescendants()) do hide(obj) end
	state.connection = character.DescendantAdded:Connect(hide)
	model:PivotTo(root.CFrame)
	local weld = Instance.new("WeldConstraint")
	weld.Name, weld.Part0, weld.Part1, weld.Parent = "AvatarCreatureMount", root, model.PrimaryPart, model.PrimaryPart
	model.Parent = character
	costumes[character] = state
	Creature.track(model)
	return model
end

return Creature
