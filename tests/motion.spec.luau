local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Motion = luau.load(fs.readFile("src/shared/CreatureMotion.luau"), { environment = { CFrame = r.CFrame } })()
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
check(Motion.clipForSpeed(0) == "Walk" and Motion.clipForSpeed(25) == "Run" and Motion.clipForSpeed(36) == "Sprint", "locomotion clip transitions")
local folder = r.Instance.new("Folder")
folder.Name = "Rift Stalker Animation Clips"
for name, clip in pairs(Motion.Clips) do
	local first, last = Motion.sample(name, 0), Motion.sample(name, 1)
	local sequence = r.Instance.new("KeyframeSequence")
	sequence.Name, sequence.Loop, sequence.Priority, sequence.Parent = name, true, r.Enum.AnimationPriority.Movement, folder
	for i = 0, #Motion.Keys do
		local time = i / #Motion.Keys
		local poses = Motion.sample(name, time)
		local key = r.Instance.new("Keyframe")
		key.Name, key.Time, key.Parent = "Pose" .. i, time * clip.duration, sequence
		local function pose(name_, cf, parent)
			local obj = r.Instance.new("Pose")
			obj.Name, obj.CFrame, obj.Weight, obj.Parent = name_, cf, 1, parent
			return obj
		end
		local root = pose("HumanoidRootPart", r.CFrame.identity, key)
		root.Weight = 0
		local torso = pose("Torso", poses.CreatureSpine, root)
		pose("Head", poses.CreatureNeck, torso)
		pose("Left Arm", poses.CreatureLeftShoulder, torso)
		pose("Right Arm", poses.CreatureRightShoulder, torso)
		pose("Left Leg", poses.CreatureLeftHip, torso)
		pose("Right Leg", poses.CreatureRightHip, torso)
	end
	for joint, frame in pairs(first) do check(frame == last[joint], name .. " loop seam: " .. joint) end
	check(#sequence:GetChildren() == 9 and clip.duration > 0, "complete native clip: " .. name)
	check(Motion.sample(name, .2).CreatureLeftShoulder ~= Motion.sample(name, .4).CreatureLeftShoulder, "run poses advance: " .. name)
end
check(Motion.sample("Run", .00001).CreatureSpine.Position.Y < .001, "near-contact keyframe interpolation continuous")
check(Motion.airborne(true).CreatureLeftHip ~= r.CFrame.identity and Motion.idle(.5).CreatureSpine ~= r.CFrame.identity, "jump and idle poses")
local dash = r.Instance.new("KeyframeSequence")
dash.Name, dash.Loop, dash.Priority, dash.Parent = "Dash", false, r.Enum.AnimationPriority.Action, folder
for _, time in ipairs({ 0, .04, .12, .22, .38 }) do
	local poses = Motion.dash(time, .22)
	local key = r.Instance.new("Keyframe")
	key.Time, key.Parent = time, dash
	local function pose(name, cf, parent)
		local p = r.Instance.new("Pose") p.Name, p.CFrame, p.Weight, p.Parent = name, cf, 1, parent return p
	end
	local root = pose("HumanoidRootPart", r.CFrame.identity, key)
	root.Weight = 0
	local torso = pose("Torso", poses.CreatureSpine, root)
	for _, pair in ipairs({ { "Head", "CreatureNeck" }, { "Left Arm", "CreatureLeftShoulder" }, { "Right Arm", "CreatureRightShoulder" }, { "Left Leg", "CreatureLeftHip" }, { "Right Leg", "CreatureRightHip" } }) do pose(pair[1], poses[pair[2]], torso) end
end
check(#dash:GetChildren() == 5 and not dash.Loop, "native dash is a finite action clip")
check(Motion.dash(0, .22).CreatureSpine == r.CFrame.identity and Motion.dash(.38, .22).CreatureSpine == r.CFrame.identity, "dash starts and ends neutral")
fs.writeFile("dist/RiftStalker-Animations.rbxm", r.serializeModel({ folder }))
local reopened = r.deserializeModel(fs.readFile("dist/RiftStalker-Animations.rbxm"))[1]
check(#reopened:GetChildren() == 4 and reopened.Run.Loop and not reopened.Dash.Loop, "native animation asset roundtrip")
print("PASS: " .. passed .. " motion clip assertions; three looping clips and one dash action exported")
