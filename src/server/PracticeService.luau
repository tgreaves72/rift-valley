-- Training instances never share collision, hazards, rewards or chase clocks
-- with the main race. Equal course/theme choices share one bounded copy.
local Replicated = game:GetService("ReplicatedStorage")
local Storage = game:GetService("ServerStorage")
local Shared = Replicated:WaitForChild("RiftShared")
local Config, Rules = require(Shared.Config), require(Shared.Rules)
local Courses = require(script.Parent.CourseService)
local Arena = workspace:WaitForChild("RiftArena")
local Practice = {}
local groups, attempts = {}, {}
local handlers

local function shift(model, y)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then part.CFrame += Vector3.new(0,y,0) end
	end
end

local function acquire(mapId, stage)
	local key = Rules.masteryKey(mapId, stage)
	if groups[key] then groups[key].users += 1 return groups[key] end
	local map, index
	for i, definition in ipairs(Config.Maps) do if definition.id == mapId then map, index = definition, i end end
	local y = -Config.Mastery.PracticeLayerDepth*index
	local model = Instance.new("Model")
	model.Name = "Practice_" .. key
	local geometry = Instance.new("Model")
	geometry.Name, geometry.Parent = "CourseGeometry", model
	if stage == 1 then
		for _, part in ipairs(Arena:GetChildren()) do if part:IsA("BasePart") then part:Clone().Parent = geometry end end
		Storage.RiftMaps:FindFirstChild(mapId):Clone().Parent = geometry
	else
		Arena.ChaseCourses:FindFirstChild("Course_" .. stage):Clone().Parent = geometry
	end
	shift(geometry, y)
	for _, part in ipairs(geometry:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "ArenaFloor" or part.Name == "SafeDeck" or part.Name == "CourseFloor" or part.Name == "CourseDeck" then part.Color = Color3.fromRGB(unpack(map.floor)) end
			if part.Name == "CourseAccent" or part.Name == "CourseFinish" then part.Color = Color3.fromRGB(unpack(map.rgb)) end
		end
	end
	local mechanics = Instance.new("Model")
	Storage.RiftMechanics:FindFirstChild(mapId):FindFirstChild(tostring(stage)):Clone().Parent = mechanics
	shift(mechanics, y)
	local service = Courses.new(model)
	service.bind(mechanics)
	-- A separate night canopy keeps the practice arena inside the Rift theme.
	local canopy = Instance.new("Part")
	canopy.Name, canopy.Size = "PracticeNight", Vector3.new(800, 2, 800)
	local course = Config.Courses[stage]
	canopy.CFrame, canopy.Color = CFrame.new(course.x,y+100,course.z), Color3.fromRGB(24,19,43)
	canopy.Anchored, canopy.CanCollide, canopy.CanTouch, canopy.CanQuery, canopy.CastShadow = true, false, false, false, false
	canopy.Material, canopy.Parent = Enum.Material.Neon, model
	local pickups = {}
	for _, part in ipairs(geometry:GetDescendants()) do
		if part:IsA("BasePart") and string.sub(part.Name,1,8) == "Recharge" then
			table.insert(pickups,{part=part,kind=part.HoverIcon.Kind.Value})
		end
	end
	local params = RaycastParams.new()
	params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Include, {model}, true
	model.Parent = workspace
	local group = { key=key, model=model, service=service, pickups=pickups, params=params, y=y, users=1, mapId=mapId, stage=stage }
	groups[key] = group
	return group
end

local function release(player)
	local attempt = attempts[player]
	if not attempt then return end
	attempt.group.users -= 1
	if attempt.group.users == 0 then attempt.group.model:Destroy() groups[attempt.group.key] = nil end
	attempts[player] = nil
end

function Practice.init(callbacks) handlers = callbacks end
function Practice.get(player) return attempts[player] end

function Practice.restart(player)
	local attempt = attempts[player]
	if not attempt then return false end
	local now = workspace:GetServerTimeNow()
	attempt.started, attempt.finished = now+Config.Mastery.PracticeCountdown, false
	player:SetAttribute("PracticeStartedAt", attempt.started)
	player:SetAttribute("PracticeFinished", false)
	player:SetAttribute("PracticeFinalTime",nil)
	handlers.reset(player)
	local course = Config.Courses[attempt.group.stage]
	handlers.move(player, Vector3.new(course.x,attempt.group.y+Config.FloorY,course.z-Config.StartZ),1)
	return true
end

function Practice.start(player, mapId, stage)
	if not Rules.masteryKey(mapId, stage) or not handlers.canStart(player) then return false end
	local profile = handlers.profile(player)
	if not profile or stage > profile.Mastery.UnlockedCourse then return false end
	-- Acquire before release so restarting a shared course cannot delete it.
	local group = acquire(mapId,stage)
	release(player)
	attempts[player] = {group=group}
	player:SetAttribute("PracticeMapId",mapId)
	player:SetAttribute("PracticeOffsetY",group.y)
	player:SetAttribute("CoursePractice",true)
	player:SetAttribute("CourseStage",stage)
	handlers.enter(player)
	Practice.restart(player)
	return true
end

function Practice.leave(player, removed)
	if not attempts[player] then return end
	release(player)
	if removed then return end
	player:SetAttribute("CoursePractice",false)
	player:SetAttribute("PracticeFinished",false)
	player:SetAttribute("PracticeFinalTime",nil)
	player:SetAttribute("PracticeOffsetY",0)
	player:SetAttribute("PracticeMapId",nil)
	player:SetAttribute("CourseStage",0)
	handlers.leave(player)
end

function Practice.step(now)
	for _, group in pairs(groups) do group.service.step(now,true) end
end

function Practice.check(player, root, now, validMovement)
	local attempt = attempts[player]
	if not attempt then return end
	local course = Config.Courses[attempt.group.stage]
	local position = root.Position
	if position.Y-attempt.group.y < -10 then Practice.restart(player) return "retry" end
	if not Rules.inCourse(position.X,position.Z,course,Config.StartZ,2) or position.Y-attempt.group.y > 38 or not validMovement then
		-- Invalid movement cannot produce a practice personal best.
		Practice.restart(player) return "retry"
	end
	if now < attempt.started then
		handlers.move(player,Vector3.new(course.x,attempt.group.y+Config.FloorY,course.z-Config.StartZ),1)
		return "ready"
	end
	if attempt.finished then return "finished" end
	if now-attempt.started > Config.Mastery.PracticeTimeLimit then Practice.restart(player) return "retry" end
	if position.Z-course.z >= Config.ArenaHalfLength and now-attempt.started >= Config.MinCourseSeconds then
		attempt.finished = true
		player:SetAttribute("PracticeFinalTime",now-attempt.started)
		player:SetAttribute("PracticeFinished",true)
		handlers.finished(player,attempt.group.mapId,attempt.group.stage,now-attempt.started)
		return "finished"
	end
	return "running"
end

function Practice.contact(player, root, humanoid, now)
	local attempt = attempts[player]
	return attempt and attempt.group.service.contact(root.Position,attempt.group.stage,humanoid.FloorMaterial ~= Enum.Material.Air,now)
end

function Practice.pickups(player)
	local attempt = attempts[player]
	return attempt and attempt.group.pickups or {}
end

function Practice.clearLine(player, from, to)
	local attempt = attempts[player]
	return attempt and workspace:Raycast(from,to-from,attempt.group.params) == nil
end

return Practice
