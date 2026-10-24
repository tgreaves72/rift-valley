-- Authored contact, passing and flight poses. All clips loop to the first key.
local Motion = {}
Motion.Keys = {
	{ 0, -4, -48, 52, 26, -28 },
	{ .12, -8, -22, 38, 12, -20 },
	{ .22, -10, 8, 12, -6, -8 },
	{ .07, -5, 40, -20, -24, 12 },
	{ 0, -4, 52, -48, -28, 26 },
	{ .12, -8, 38, -22, -20, 12 },
	{ .22, -10, 12, 8, -8, -6 },
	{ .07, -5, -20, 40, 12, -24 },
}
Motion.Clips = {
	Walk = { duration = 1.05, strength = .52, lean = 0 },
	Run = { duration = .68, strength = 1, lean = 0 },
	Sprint = { duration = .54, strength = 1.25, lean = -7 },
}
function Motion.clipForSpeed(speed)
	return speed > 31 and "Sprint" or (speed > 15 and "Run" or "Walk")
end
function Motion.frame(key, strength, lean)
	local rad = math.rad
	return {
		CreatureSpine = CFrame.new(0, key[1] * strength, -.04 * strength) * CFrame.Angles(rad(key[2] * strength + lean), 0, rad((key[3] - key[4]) * .035 * strength)),
		CreatureNeck = CFrame.Angles(rad(-key[2] * .4 * strength), 0, 0),
		CreatureLeftShoulder = CFrame.Angles(rad(key[3] * strength), 0, rad(-4 * strength)),
		CreatureRightShoulder = CFrame.Angles(rad(key[4] * strength), 0, rad(4 * strength)),
		CreatureLeftHip = CFrame.Angles(rad(key[5] * strength), 0, 0),
		CreatureRightHip = CFrame.Angles(rad(key[6] * strength), 0, 0),
	}
end
function Motion.sample(clipName, phase)
	local clip = Motion.Clips[clipName]
	local position = (phase % 1) * #Motion.Keys
	local index = math.floor(position) + 1
	local a = Motion.frame(Motion.Keys[index], clip.strength, clip.lean)
	local b = Motion.frame(Motion.Keys[index % #Motion.Keys + 1], clip.strength, clip.lean)
	for name, frame in pairs(a) do a[name] = frame:Lerp(b[name], position % 1) end
	return a
end
function Motion.idle(time)
	return {
		CreatureSpine = CFrame.new(0, math.sin(time * 2.3) * .035, 0),
		CreatureNeck = CFrame.Angles(0, math.sin(time * .8) * .055, 0),
	}
end
function Motion.airborne(rising)
	return {
		CreatureSpine = CFrame.Angles(math.rad(-9), 0, 0),
		CreatureNeck = CFrame.Angles(math.rad(8), 0, 0),
		CreatureLeftShoulder = CFrame.Angles(math.rad(rising and -26 or 22), 0, -.2),
		CreatureRightShoulder = CFrame.Angles(math.rad(rising and -26 or 22), 0, .2),
		CreatureLeftHip = CFrame.Angles(math.rad(-32), 0, -.05),
		CreatureRightHip = CFrame.Angles(math.rad(-32), 0, .05),
	}
end
function Motion.grab(elapsed, stage)
	local lift = stage == "Reach" and 0 or math.clamp(elapsed / 1.1, 0, 1)
	return {
		CreatureSpine = CFrame.Angles(math.rad(-10 + lift*9), 0, 0),
		CreatureNeck = CFrame.Angles(math.rad(-8 - lift*12), 0, 0),
		CreatureLeftShoulder = CFrame.Angles(math.rad(80 + lift*45), .18 + lift*.25, -.18),
		CreatureRightShoulder = CFrame.Angles(math.rad(80 + lift*45), -.18 - lift*.25, .18),
		CreatureLeftHip = CFrame.Angles(math.rad(-8), 0, 0),
		CreatureRightHip = CFrame.Angles(math.rad(-8), 0, 0),
	}
end
function Motion.dash(elapsed, duration)
	local strength = math.clamp(elapsed/.04, 0, 1) * math.clamp((duration + .16 - elapsed)/.16, 0, 1)
	return {
		CreatureSpine = CFrame.new(0, -.18*strength, 0) * CFrame.Angles(math.rad(-25)*strength, 0, 0),
		CreatureNeck = CFrame.Angles(math.rad(18)*strength, 0, 0),
		CreatureLeftShoulder = CFrame.Angles(math.rad(-65)*strength, 0, -.2*strength),
		CreatureRightShoulder = CFrame.Angles(math.rad(-65)*strength, 0, .2*strength),
		CreatureLeftHip = CFrame.Angles(math.rad(-28)*strength, 0, 0),
		CreatureRightHip = CFrame.Angles(math.rad(16)*strength, 0, 0),
	}
end
function Motion.charge(warning)
	return {
		CreatureSpine = CFrame.Angles(math.rad(warning and -35 or -23), 0, 0),
		CreatureNeck = CFrame.Angles(math.rad(20), 0, 0),
		CreatureLeftShoulder = CFrame.Angles(math.rad(warning and 35 or -45), 0, -.3),
		CreatureRightShoulder = CFrame.Angles(math.rad(warning and 35 or -45), 0, .3),
	}
end
return table.freeze(Motion)
