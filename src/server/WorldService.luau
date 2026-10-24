local Storage = game:GetService("ServerStorage")
local Replicated = game:GetService("ReplicatedStorage")
local Shared = Replicated:WaitForChild("RiftShared")
local Config, Rules = require(Shared.Config), require(Shared.Rules)
local Arena = workspace:WaitForChild("RiftArena")
local Templates = Storage:WaitForChild("RiftMaps")
local Lobby = workspace:WaitForChild("RiftLobby")
local World = {}
local votes, active, previous = {}, Arena:FindFirstChild("ActiveMap"), nil
local callbacks, interactions = nil, {}
local courseInteractions = {}
local function resourceKind(part)
	local marker = part:FindFirstChild("HoverIcon")
	local kind = marker and marker:FindFirstChild("Kind")
	assert(kind and (kind.Value == "Stamina" or kind.Value == "Dash"), "Missing resource pickup kind: " .. part.Name)
	return kind.Value
end
for stage = 2, #Config.Courses do
	courseInteractions[stage] = {}
	local section = Arena.ChaseCourses:WaitForChild("Course_" .. stage)
	for _, part in ipairs(section:GetChildren()) do
		if part:IsA("BasePart") and string.sub(part.Name, 1, 8) == "Recharge" then
			table.insert(courseInteractions[stage], { part = part, kind = resourceKind(part) })
		end
	end
end
local voting = false
local course = Lobby:WaitForChild("Parkour")
local parkour, best, retry = {}, {}, {}
local plateDown, votePlates = {}, {}
for _,map in ipairs(Config.Maps) do table.insert(votePlates,Lobby:WaitForChild("Vote_"..map.id)) end
local courseSteps = {}
for index = 1, Config.ParkourSteps do courseSteps[index] = course:WaitForChild("ParkourStep_" .. index) end
local function ghostFrame(state,position,now,force)
	if not force and now-state.sampledAt<.2 then return end
	local delta=position-state.last
	local elapsed=math.max(.05,now-state.checkedAt)
	if Vector3.new(delta.X,0,delta.Z).Magnitude>31*elapsed+3 then state.valid=false end
	local movement=position-state.framePosition
	if movement.X*movement.X+movement.Z*movement.Z>.01 then state.yaw=math.atan2(-movement.X,-movement.Z) end
	local ms=math.floor((now-state.started)*1000+.5)
	if #state.frames<602 and ms<=120000 and (#state.frames==0 or ms>state.frames[#state.frames][1]) then
		table.insert(state.frames,{ms,math.floor(position.X*10+.5),math.floor(position.Y*10+.5),math.floor(position.Z*10+.5),math.floor(state.yaw*1000+.5)})
	end
	state.sampledAt,state.framePosition=now,position
end

local function closeEnough(player, part, radius)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root and humanoid and humanoid.Health > 0 and (root.Position - part.Position).Magnitude <= radius
end

local function voteCounts()
	for _, map in ipairs(Config.Maps) do
		local count = 0
		for _, id in pairs(votes) do if id == map.id then count += 1 end end
		Replicated:SetAttribute("Votes_" .. map.id, count)
	end
end

local function activate(id)
	local template = Templates:FindFirstChild(id)
	assert(template, "Missing map template: " .. id)
	local replacement = template:Clone()
	replacement.Name = "ActiveMap"
	if active then active:Destroy() end
	active = replacement
	active.Parent = Arena
	interactions = {}
	for _, part in ipairs(active:GetDescendants()) do
		if part:IsA("BasePart") and (string.sub(part.Name, 1, 7) == "Crystal" or string.sub(part.Name, 1, 8) == "Recharge") then
			table.insert(interactions, { part = part, kind = string.sub(part.Name, 1, 7) == "Crystal" and "Crystal" or resourceKind(part) })
		end
	end
	for _, map in ipairs(Config.Maps) do
		if map.id == id then
			Replicated:SetAttribute("MapId", id)
			Replicated:SetAttribute("MapName", map.name)
			game:GetService("Lighting").ClockTime = map.clock
			Arena.ArenaFloor.Color = Color3.fromRGB(unpack(map.floor))
			for _, part in ipairs(Arena.ChaseCourses:GetDescendants()) do
				if part:IsA("BasePart") then
					if part.Name == "CourseFloor" or part.Name == "CourseDeck" then part.Color = Color3.fromRGB(unpack(map.floor)) end
					if part.Name == "CourseAccent" or part.Name == "CourseFinish" then part.Color = Color3.fromRGB(unpack(map.rgb)) end
				end
			end
			break
		end
	end
	previous = id
end

function World.vote(player, id)
	if not voting or type(id) ~= "string" or not callbacks.inLobby(player) then return false end
	for _, map in ipairs(Config.Maps) do
		if map.id == id then
			votes[player] = id
			player:SetAttribute("MapVote", id)
			voteCounts()
			return true
		end
	end
	return false
end

function World.voteOnPlate(player,id)
	if type(id)~="string" then return false end
	local plate=Lobby:FindFirstChild("Vote_"..id)
	local character=player.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	return plate and root and humanoid and humanoid.Health>0
		and Rules.onSurface(root.Position,plate,humanoid.FloorMaterial~=Enum.Material.Air) and World.vote(player,id) or false
end

function World.startVoting()
	votes, voting = {}, true
	for player,plate in pairs(plateDown) do if plate~=course.ParkourStart then plateDown[player]=nil end end
	Replicated:SetAttribute("VotingOpen", true)
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do player:SetAttribute("MapVote", "") end
	voteCounts()
end

function World.choose(pick)
	voting = false
	Replicated:SetAttribute("VotingOpen", false)
	local id = Rules.chooseMap(Config.Maps, votes, previous, pick)
	activate(id)
	return id
end

function World.closeVoting()
	voting = false
	Replicated:SetAttribute("VotingOpen", false)
end

function World.getInteractions(stage)
	if not stage or stage == 1 then return interactions end
	return courseInteractions[stage] or {}
end

function World.resetParkour(player)
	parkour[player] = nil
	retry[player] = nil
	player:SetAttribute("ParkourRetryAvailable", false)
	player:SetAttribute("ParkourActive", false)
	player:SetAttribute("ParkourCheckpoint", 0)
end

function World.failParkour(player)
	if not parkour[player] then return false end
	World.resetParkour(player)
	retry[player] = true
	plateDown[player] = nil
	player:SetAttribute("ParkourRetryAvailable", true)
	return true
end

function World.canRetryParkour(player) return retry[player] == true end
function World.isParkouring(player) return parkour[player] ~= nil end

function World.retryParkour(player)
	if not retry[player] or not callbacks.inLobby(player) then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	World.resetParkour(player)
	plateDown[player] = nil
	callbacks.moveLobby(player, course.ParkourStart.Position+Vector3.new(0, Config.FloorY, 0))
	return true
end

function World.beginParkour(player)
	if parkour[player] or not callbacks.inLobby(player) or not closeEnough(player, course.ParkourStart, 14) then return false end
	retry[player] = nil
	player:SetAttribute("ParkourRetryAvailable", false)
	local now=workspace:GetServerTimeNow()
	local position=player.Character:FindFirstChild("HumanoidRootPart").Position
	parkour[player] = { checkpoint = 0, saved = 0, falls = 0, started = now, sampledAt=now,checkedAt=now,
		last=position,framePosition=position,yaw=math.pi,valid=true,frames={{0,math.floor(position.X*10+.5),math.floor(position.Y*10+.5),math.floor(position.Z*10+.5),3142}} }
	player:SetAttribute("ParkourActive", true)
	player:SetAttribute("ParkourCheckpoint", 0)
	player:SetAttribute("ParkourFalls", 0)
	player:SetAttribute("ParkourStartedAt", parkour[player].started)
	if callbacks.parkourBegin then callbacks.parkourBegin(player) end
	callbacks.notice(player, "Jump to the Top!")
	return true
end

function World.stepLobby(player, root, humanoid)
	if not callbacks.inLobby(player) or humanoid.Health<=0 then return end
	local position = root.Position
	local state = parkour[player]
	local zone = Rules.lobbyZone(position.X, position.Y, position.Z)
	local function recover()
		if state then World.failParkour(player) end
		callbacks.returnLobby(player)
	end
	if not zone or ((zone == "Lounge" or zone == "VIPBridge" or zone == "VIPActivity") and not callbacks.isVIP(player)) then
		recover()
		return
	end
	local tutorialPlate=Lobby:FindFirstChild("TutorialPlate")
	if tutorialPlate and Rules.onSurface(position,tutorialPlate,humanoid.FloorMaterial~=Enum.Material.Air) and callbacks.tutorial then
		callbacks.tutorial(player) return
	end
	if zone=="Tutorial" then recover() return end
	if zone == "Parkour" and position.Y < Config.LobbyFloorY - 22 then recover() return end
	local pressed=nil
	local grounded=humanoid.FloorMaterial~=Enum.Material.Air
	for _,plate in ipairs(votePlates) do if Rules.onSurface(position,plate,grounded) then pressed=plate break end end
	if not pressed and Rules.onSurface(position,course.ParkourStart,grounded) then pressed=course.ParkourStart end
	if pressed~=plateDown[player] then
		plateDown[player]=pressed
		if pressed==course.ParkourStart then World.beginParkour(player)
		elseif pressed then World.vote(player,string.sub(pressed.Name,6)) end
	end
	state=parkour[player]
	if not state then return end
	if zone ~= "Parkour" and zone ~= "Bridge" then World.resetParkour(player) return end
	local now=workspace:GetServerTimeNow()
	ghostFrame(state,position,now,false)
	local movement=position-state.last
	if Vector3.new(movement.X,0,movement.Z).Magnitude>31*math.max(.05,now-state.checkedAt)+3 then state.valid=false end
	state.last,state.checkedAt=position,now
	local nextStep = courseSteps[state.checkpoint + 1]
	local center, top = nextStep.Position, nextStep.Position.Y + nextStep.Size.Y/2
	if not Rules.onParkourStep(position.X, position.Y, position.Z, center.X, top, center.Z, humanoid.FloorMaterial ~= Enum.Material.Air, nextStep.Size.X/2 - .25, nextStep.Size.Z/2 - .25) then return end
	state.checkpoint += 1
	if state.checkpoint % Config.ParkourCheckpointEvery == 0 then state.saved = state.checkpoint end
	player:SetAttribute("ParkourCheckpoint", state.checkpoint)
	if state.checkpoint == #courseSteps then
		local elapsed = now - state.started
		ghostFrame(state,position,now,true)
		best[player] = math.min(best[player] or math.huge, elapsed)
		player:SetAttribute("ParkourBest", best[player])
		if callbacks.parkourFinish then callbacks.parkourFinish(player,elapsed,state.frames,state.valid) end
		World.resetParkour(player)
		retry[player] = true
		player:SetAttribute("ParkourRetryAvailable", true)
		callbacks.notice(player, string.format("You Did It! %.1fs", elapsed))
		callbacks.celebrate(position + Vector3.new(0, 3, 0))
	elseif state.checkpoint % Config.ParkourCheckpointEvery == 0 then callbacks.notice(player, "Checkpoint!") end
end

function World.remove(player)
	votes[player] = nil
	plateDown[player]=nil
	parkour[player], best[player], retry[player] = nil, nil, nil
	if voting then voteCounts() end
end

function World.init(handlers)
	callbacks = handlers
	activate(Config.Maps[1].id)
	for _, part in ipairs(Lobby:GetDescendants()) do
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if not callbacks.inLobby(player) or not closeEnough(player, part, 14) then return end
				if string.sub(part.Name, 1, 5) == "Vote_" then
					World.vote(player, string.sub(part.Name, 6))
				elseif part.Name == "PassVendor" then callbacks.openShop(player)
				elseif part.Name == "MasteryPortal" then callbacks.openMastery(player)
				elseif part.Name == "StyleMirror" then
					if callbacks.isVIP(player) then callbacks.openStyles(player) else callbacks.openShop(player) end
				elseif part.Name == "VIPPortal" then callbacks.lounge(player)
				elseif part.Name == "LoungeExit" then callbacks.returnLobby(player)
				end
			end)
		end
	end
end

return World
