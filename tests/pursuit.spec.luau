-- Actual server lifecycle with controlled avatars and flat-ground raycasts.
-- Geometry/path failures have a separate native-floor navigation suite.
local r = require("@lune/roblox")
local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local h = require("./match-host")(1)
local p, passed = h.players[1], 0
local function check(value, message) assert(value, message) passed += 1 end
local function root() return p.Character.HumanoidRootPart end
local function walkTo(point)
	for _ = 1, 200 do
		local delta = point-root().Position
		if delta.Magnitude < .01 then return end
		root().CFrame += delta.Unit*math.min(2, delta.Magnitude)
		h.tick(.1, false)
	end
	error("walk did not reach target")
end
local function finish()
	local stage = p:GetAttribute("CourseStage")
	for _ = 1, 160 do
		if p:GetAttribute("CourseStage") ~= stage or p:GetAttribute("Role") ~= "Runner" then return end
		root().CFrame += r.Vector3.new(0, 0, 2)
		h.tick(.1, false)
	end
	error("finish did not advance")
end
for _ = 1, 220 do if h.host.replicated:GetAttribute("Phase") == "Crossing" then break end h.tick(.2, true) end
h.tick(.1,false)
local initial=h.host.workspace:FindFirstChild("Rift Stalker 1/1")
check(initial and initial.Humanoid.LastMove.Magnitude>.5 and p:GetAttribute("SafeUntil")>h.now(),"first-map catchers pursue on the first crossing tick while contact protection remains")
finish()
check(h.host.workspace:FindFirstChild("Rift Stalker 2/1")~=nil,"next-course pack exists in the finish heartbeat without the periodic roster delay")
for stage = 2, 5 do
	for _ = 1, 12 do
		if h.host.workspace:FindFirstChild("Rift Stalker " .. stage .. "/1") then break end
		h.tick(.1, false)
	end
	h.tick(.1, false)
	check(p:GetAttribute("SafeUntil") > h.now() and p:GetAttribute("CourseStage") == stage, "new course is protected")
	local positions = {}
	for index = 1, Config.Courses[stage].bots do
		local bot = h.host.workspace:FindFirstChild("Rift Stalker " .. stage .. "/" .. index)
		check(bot and bot.Humanoid.WalkSpeed == Rules.botSpeed(bot:GetAttribute("Archetype"), stage), "course " .. stage .. " bot " .. index .. " starts at intended pursuit speed")
		local position, move = bot.HumanoidRootPart.Position, bot.Humanoid.LastMove
		local direction = root().Position-position
		check(move and move.Magnitude>.5 and move:Dot(direction.Unit)>.5 and position.Z-root().Position.Z>45, "bot pursues immediately from its forward station during landing protection")
		local station=tostring(position.X)..":"..tostring(position.Z)
		check(not positions[station] and not bot:GetAttribute("ChargeStage"), "spawns spread out without attacking the protected runner")
		positions[station] = true
	end
	local first = h.host.workspace:FindFirstChild("Rift Stalker " .. stage .. "/1")
	first.HumanoidRootPart.CFrame = r.CFrame.new(root().Position-r.Vector3.new(0,0,2))
	h.tick(.1, false)
	check(p:GetAttribute("Role") == "Runner" and not h.captures.busy(first.HumanoidRootPart), "nearby catcher cannot grab during protection")
	first.HumanoidRootPart.CFrame = r.CFrame.new(root().Position.X, -12, root().Position.Z)
	first:SetAttribute("ChargeStage", "Warning")
	h.tick(.1, false)
	check(first.HumanoidRootPart.Position.Y >= 4 and first:GetAttribute("ChargeStage") == nil, "fall recovery runs even during protection and clears charge")
	check(first:GetAttribute("NavigationRecoverUntil") > h.now(), "recovered catcher cannot immediately attack")
	if stage == 2 then
		local section = h.host.workspace.RiftArena.ChaseCourses.Course_2
		local function collect(index, kind)
			local pickup = section:FindFirstChild("Recharge_Course2_" .. index)
			walkTo(pickup.Position+r.Vector3.new(0,1,-7))
			h.remote.OnServerEvent:Fire(p, "Dash", r.Vector3.new(0,0,1))
			local ready = p:GetAttribute("DashReadyAt")
			check(ready > h.now(), "dash starts before pickup")
			root().CFrame += r.Vector3.new(0,0,3)
			h.tick(.1, false) h.tick(.1, false)
			local found = false
			for _, event in ipairs(h.events) do if event.action == "Recharge" and event.kind == kind then found = true end end
			check(found, "server emits correct resource type")
			if kind == "Stamina" then
				check(p:GetAttribute("Stamina") == 100 and p:GetAttribute("DashReadyAt") == ready, "battery restores stamina without resetting dash")
			else
				check(p:GetAttribute("Stamina") == 76 and p:GetAttribute("DashReadyAt") <= h.now(), "wind pickup resets dash without refilling stamina")
			end
		end
		collect(1, "Stamina") collect(2, "Dash")
	end
	finish()
end
check(p:GetAttribute("Role") == "Escaped", "all later courses remain completable")
print("PASS: " .. passed .. " immediate forward pursuit, protected contact, fall recovery and distinct resource assertions")
