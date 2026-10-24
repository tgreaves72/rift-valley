local Pathfinding = game:GetService("PathfindingService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Config = require(Shared.Config)
local Arena = workspace:WaitForChild("RiftArena")
local Navigation = {}
local params = RaycastParams.new()
params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Include, { Arena }, true
local stable = { ArenaFloor = true, SafeDeck = true, CourseFloor = true, CourseDeck = true, CourseBypass = true, CourseBypassLane = true, CourseJunction = true }
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function ground(point)
	local hit = workspace:Raycast(point+Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), params)
	if hit and hit.Normal.Y > .7 and hit.Position.Y <= point.Y-1 then return hit end
	return nil
end
local function clearBody(from, to)
	local travel = flat(to-from)
	if travel.Magnitude < .01 then return true end
	local side = Vector3.new(-travel.Unit.Z, 0, travel.Unit.X)*1.4
	for _, offset in ipairs({ Vector3.new(0, -2, 0), side+Vector3.new(0, -2, 0), -side+Vector3.new(0, -2, 0), Vector3.new(0, 1.5, 0) }) do
		if workspace:Raycast(from+offset, travel, params) then return false end
	end
	return true
end

-- Charges/lunges must have a full body-width supported corridor. A chest-height
-- line alone misses low hurdles, vanished stones and the empty space over gaps.
function Navigation.safeSegment(from, to)
	if not clearBody(from, to) then return false end
	local travel = flat(to-from)
	local base = ground(from)
	if not base or base.Instance.Name == "CrumbleTile" then return false end
	local side = travel.Magnitude > .01 and Vector3.new(-travel.Unit.Z, 0, travel.Unit.X)*1.4 or Vector3.new(1.4, 0, 0)
	local steps = math.max(1, math.ceil(travel.Magnitude/2))
	for i = 0, steps do
		local point = from+travel*(i/steps)
		for _, offset in ipairs({ Vector3.zero, side, -side }) do
			local hit = ground(point+offset)
			if not hit or hit.Instance.Name == "CrumbleTile" or math.abs(hit.Position.Y-base.Position.Y) > .8 then return false end
		end
	end
	return true
end

function Navigation.reset(bot, now)
	local nav = bot.navigation
	if nav and nav.blocked then nav.blocked:Disconnect() end
	bot.navigation = { revision = nav and nav.revision+1 or 1, waypoints = {}, index = 1,
		computing = false, nextPath = now, progressAt = now, progressOrigin = bot.root.Position,
		lastSafe = nav and nav.lastSafe or bot.spawnPoint, previousSafe = nav and nav.previousSafe }
	bot.humanoid.Jump = false
end
function Navigation.remove(bot)
	Navigation.reset(bot, 0)
	bot.navigation.removed = true
end
function Navigation.recover(bot, now, stuck)
	local nav = bot.navigation
	local point = nav and nav.lastSafe or bot.spawnPoint
	if stuck and flat(point-bot.root.Position).Magnitude < 4 then point = nav.previousSafe or bot.spawnPoint end
	local hit = ground(point)
	if not hit or not stable[hit.Instance.Name] then point = bot.spawnPoint hit = ground(point) end
	if hit then point = Vector3.new(point.X, hit.Position.Y+Config.FloorY, point.Z) end
	Navigation.reset(bot, now+.5)
	bot.chargeAt, bot.recoverAt, bot.nextCharge = nil, now+.9, now+Config.ChargeCooldown
	bot.model:SetAttribute("ChargeStage", nil)
	bot.model:SetAttribute("RecoverUntil", workspace:GetServerTimeNow()+.9)
	bot.model:SetAttribute("NavigationRecoverUntil", workspace:GetServerTimeNow()+.9)
	bot.model:PivotTo(CFrame.lookAt(point, point+Vector3.new(0, 0, 1)))
	bot.navigation.lastSafe, bot.navigation.progressOrigin = point, point
	bot.root.AssemblyLinearVelocity, bot.root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	bot.humanoid:Move(Vector3.zero)
end
function Navigation.idle(bot, now)
	if bot.navigation then bot.navigation.progressAt = now bot.navigation.progressOrigin = bot.root.Position end
	bot.humanoid:Move(Vector3.zero)
end

local function request(bot, target, now)
	local nav = bot.navigation
	if nav.computing or now < nav.nextPath or bot.humanoid.FloorMaterial == Enum.Material.Air then return end
	nav.computing, nav.nextPath = true, now+1
	local origin, destination = bot.root.Position, target.Position
	task.spawn(function()
		local ok, path, points = pcall(function()
			local path = Pathfinding:CreatePath({ AgentRadius = 2, AgentHeight = 6, AgentCanJump = true, WaypointSpacing = 4,
				Costs = { Unstable = math.huge } })
			path:ComputeAsync(origin, destination)
			return path, path.Status == Enum.PathStatus.Success and path:GetWaypoints() or nil
		end)
		-- A fall, despawn, charge or completed course invalidates in-flight work.
		if bot.navigation ~= nav or nav.removed or not bot.model.Parent then return end
		nav.computing = false
		if not ok or not points or #points < 2 then nav.failed = true return end
		if flat(bot.root.Position-origin).Magnitude > 12 then nav.nextPath = 0 return end
		if nav.blocked then nav.blocked:Disconnect() end
		nav.waypoints, nav.index, nav.goal, nav.failed, nav.jumpIndex = points, 2, destination, false, nil
		if path.Blocked then
			nav.blocked = path.Blocked:Connect(function(index)
				if bot.navigation == nav and index >= nav.index then nav.dirty = true nav.nextPath = 0 end
			end)
		end
		nav.dirty = false
	end)
end

function Navigation.prime(bot, target, now)
	if not bot.navigation then Navigation.reset(bot, now) end
	local nav = bot.navigation
	-- Ready time is preparation time, never evidence that the actor is stuck.
	nav.progressAt, nav.progressOrigin = now, bot.root.Position
	if #nav.waypoints == 0 then request(bot, target, now) end
end

function Navigation.follow(bot, target, now)
	if not bot.navigation then Navigation.reset(bot, now) end
	local nav, position = bot.navigation, bot.root.Position
	local distance = flat(target.Position-position).Magnitude
	if distance < 1.8 then
		nav.progressAt, nav.progressOrigin = now, position
		if distance > .1 then bot.root.CFrame = CFrame.lookAt(position, position+flat(target.Position-position)) end
		bot.humanoid:Move(Vector3.zero)
		return
	end
	if flat(position-nav.progressOrigin).Magnitude > 1.2 then nav.progressAt, nav.progressOrigin = now, position end
	if bot.humanoid.FloorMaterial ~= Enum.Material.Air then
		local hit = ground(position)
		if hit and stable[hit.Instance.Name] and flat(position-nav.lastSafe).Magnitude > 8 then nav.previousSafe, nav.lastSafe = nav.lastSafe, position end
	end
	if now-nav.progressAt > 3.5 then Navigation.recover(bot, now, true) return end
	local travel = flat(target.Position-position)
	if math.abs(target.Position.Y-position.Y) < 2 and clearBody(position, target.Position)
		and Navigation.safeSegment(position, position+travel.Unit*math.min(8, travel.Magnitude)) then
		-- A direct shortcut can pass old path nodes. Discard that route rather
		-- than walking backwards to it when the next bend needs pathfinding.
		if not nav.direct then Navigation.reset(bot, now) nav = bot.navigation nav.direct = true end
		bot.humanoid:Move(travel.Unit)
		return
	end
	if nav.direct then Navigation.reset(bot, now) nav = bot.navigation end
	local exhausted = nav.index > #nav.waypoints
	if nav.dirty or exhausted or not nav.goal or flat(target.Position-nav.goal).Magnitude > 8 or now-nav.progressAt > 1.2 then request(bot, target, now) end
	if nav.dirty then bot.humanoid:Move(Vector3.zero) return end
	local waypoint = nav.waypoints[nav.index]
	-- Waypoints lie on the floor. Compare horizontal progress, not root-to-floor
	-- 3D distance, and select the next waypoint before issuing MoveTo.
	while waypoint and flat(position-waypoint.Position).Magnitude < 2.2
		and position.Y >= waypoint.Position.Y-1 and position.Y <= waypoint.Position.Y+7
		and bot.humanoid.FloorMaterial ~= Enum.Material.Air do
		nav.index += 1
		waypoint = nav.waypoints[nav.index]
	end
	if not waypoint then bot.humanoid:Move(Vector3.zero) return end
	if waypoint.Action == Enum.PathWaypointAction.Jump and nav.jumpIndex ~= nav.index and bot.humanoid.FloorMaterial ~= Enum.Material.Air then
		bot.humanoid.Jump, nav.jumpIndex = true, nav.index
	end
	bot.humanoid:MoveTo(waypoint.Position)
end
return Navigation
