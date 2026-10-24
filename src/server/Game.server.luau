local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Shared = ReplicatedStorage:WaitForChild("RiftShared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
local Profiles = require(script.Parent.ProfileStore)
local Passes = require(script.Parent.PassService)
local World = require(script.Parent.WorldService)
local Creature = require(script.Parent.CreatureRig)
local Captures = require(script.Parent.CaptureService)
local Styles = require(script.Parent.StyleService)
local Courses = require(script.Parent.CourseService)
local Metrics = require(script.Parent.PlaytestService)
local Navigation = require(script.Parent.CatcherNavigation)
local Mastery = require(script.Parent.MasteryService)
local Practice = require(script.Parent.PracticeService)
local Gear = require(script.Parent.VIPGearService)
local Launch = require(script.Parent.LaunchService)
local Remote = ReplicatedStorage:WaitForChild("RiftAction")
local Arena = workspace:WaitForChild("RiftArena")
Players.CharacterAutoLoads = false
pcall(function() PhysicsService:RegisterCollisionGroup("RiftCharacters") end)
PhysicsService:CollisionGroupSetCollidable("RiftCharacters", "RiftCharacters", false)

local sessions = {}
local bots = {}
local chaserRosterDirty = false
local phase, round, wave, direction, deadline = "Intermission", 0, 0, 1, 0
local practice = false
local quickRetry, retryRequested = false, false
local soloPaused = false
local rng = Random.new()
local lobbyPoint = Vector3.new(0, Config.LobbyFloorY + Config.FloorY, 224)
local function track(player,event,stage) Metrics.event(player,event,stage) Launch.event(player,event,stage) end

local function setCourse(player, stage)
	local state = sessions[player]
	state.stage = stage
	chaserRosterDirty = true
	Metrics.stage(player, stage)
	state.courseBegan = os.clock()
	state.masteryValid = true
	state.routeBoostUntil = 0
	player:SetAttribute("CourseStage", stage)
	player:SetAttribute("CourseStartedAt",workspace:GetServerTimeNow())
	local profile = Profiles.get(player)
	if profile then Mastery.reached(profile,stage) Mastery.sync(player,profile) end
	player:SetAttribute("DashStartedAt", 0)
	if player.Character then player.Character:SetAttribute("DashStartedAt", 0) end
end

local function coursePoint(stage, x, z)
	local course = Config.Courses[stage or 1]
	return Vector3.new(course.x + x, Config.FloorY, course.z + z)
end

local function catcherPoint(stage)
	local x,z=Rules.catcherStation(stage,rng:NextInteger(1,Config.Courses[stage].bots))
	return coursePoint(stage,x,z)
end

local function livingRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then return root, humanoid end
	return nil, nil
end

local function syncProfile(player)
	local data = Profiles.get(player)
	if not data then return end
	for _, name in ipairs({ "Coins", "XP", "Wins", "Tags", "Crossings", "Equipped" }) do
		player:SetAttribute(name, data[name])
	end
	player:SetAttribute("Level", Rules.level(data.XP))
	Mastery.sync(player, data)
	local owned = {}
	for _, trail in ipairs(Config.Trails) do
		if Rules.trailAvailable(data, trail, Passes.entitlements(player)) then table.insert(owned, trail.id) end
		if trail.id == data.Equipped and trail.pass and not Passes.owns(player, trail.pass) then player:SetAttribute("Equipped", "None") end
	end
	player:SetAttribute("OwnedTrails", table.concat(owned, ","))
	Styles.sync(player, data, Passes.entitlements(player))
	local board = player:FindFirstChild("leaderstats")
	if board then
		board.Wins.Value = data.Wins
		board.Tags.Value = data.Tags
		board.Level.Value = Rules.level(data.XP)
	end
end

local function notify(player, message)
	if player.Parent then Remote:FireClient(player, "Notice", message) end
end

local function reward(player, coins, xp, stat)
	if practice and not Config.PracticeRewards then return end
	if practice and (stat == "Wins" or stat == "Tags") then return end
	local data = Profiles.get(player)
	if not data then return end
	if sessions[player] and sessions[player].training then return end
	local scale = practice and Config.PracticeRewardScale or 1
	data.Coins += Rules.rewardCoins(math.floor(coins*scale), practice and {} or Passes.entitlements(player))
	data.XP += math.floor(xp*scale)
	if stat then data[stat] += 1 end
	syncProfile(player)
end

local function appearance(player)
	local state = sessions[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not state or not root then return end
	local costume = Creature.apply(character, state.role == "Catcher")
	local profile = Profiles.get(player)
	if costume and profile then
		for _, definition in ipairs(Config.Cosmetics) do
			if definition.slot == "Skin" and definition.id == (profile.SkinEquipped or "DefaultSkin") and Rules.cosmeticAvailable(profile,definition,Passes.entitlements(player)) then Creature.skin(costume,definition.skin) end
		end
	end
	local old = character:FindFirstChild("RiftRole")
	if old then old:Destroy() end
	local highlight = Instance.new("Highlight")
	highlight.Name = "RiftRole"
	highlight.FillColor = state.role == "Catcher" and Color3.fromRGB(180, 105, 255) or Color3.fromRGB(100, 255, 201)
	highlight.FillTransparency = 0.94
	highlight.OutlineTransparency = state.role == "Spectator" and 1 or 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = character
	for _, name in ipairs({ "RiftTrail", "RiftTrailTop", "RiftTrailBottom" }) do
		local item = root:FindFirstChild(name)
		if item then item:Destroy() end
	end
	Styles.apply(player, profile, Passes.entitlements(player), state.role)
	if profile then
		for _, trail in ipairs(Config.Trails) do
			if trail.id == profile.Equipped and trail.id ~= "None" and Rules.trailAvailable(profile,trail,Passes.entitlements(player)) then
				local top = Instance.new("Attachment")
				top.Name, top.Position, top.Parent = "RiftTrailTop", Vector3.new(0, 1, 0.8), root
				local bottom = Instance.new("Attachment")
				bottom.Name, bottom.Position, bottom.Parent = "RiftTrailBottom", Vector3.new(0, -1, 0.8), root
				local effect = Instance.new("Trail")
				effect.Name = "RiftTrail"
				effect.Attachment0, effect.Attachment1 = top, bottom
				effect.Color = ColorSequence.new(Color3.fromRGB(unpack(trail.rgb)))
				if trail.colors then
					local keys = {}
					for index, rgb in ipairs(trail.colors) do table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#trail.colors - 1), Color3.fromRGB(unpack(rgb)))) end
					effect.Color = ColorSequence.new(keys)
					effect:SetAttribute("PaletteId", trail.id)
				end
				effect.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
				effect.Lifetime, effect.MinLength, effect.LightEmission = 0.28, 0.15, 0.7
				effect.Parent = root
			end
		end
	end
	local oldBadge = character:FindFirstChild("RiftVIP")
	if oldBadge then oldBadge:Destroy() end
	if Passes.owns(player, "VIP") then
		local badge = Instance.new("BillboardGui")
		badge.Name, badge.Adornee, badge.Size = "RiftVIP", character:FindFirstChild("Head") or root, UDim2.fromOffset(180, 24)
		badge.StudsOffset, badge.MaxDistance, badge.AlwaysOnTop = Vector3.new(0, 3, 0), 70, false
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, "VIP  |  " .. player.DisplayName
		text.Font, text.TextSize, text.TextColor3 = Enum.Font.GothamBold, 12, Color3.fromRGB(255, 210, 105)
		text.TextStrokeTransparency, text.Parent = 0.5, badge
		badge.Parent = character
	end
end

local function setRole(player, role)
	local state = sessions[player]
	if not state then return end
	state.role = role
	state.sprinting = false
	player:SetAttribute("Role", role)
	player:SetAttribute("DashStartedAt", 0)
	if player.Character then player.Character:SetAttribute("DashStartedAt", 0) end
	Remote:FireAllClients("DashCancel", player)
	appearance(player)
end

local function teleport(player, position, faceDirection)
	local root, humanoid = livingRoot(player)
	local state = sessions[player]
	if root and state then
		-- Release a garden seat before moving the character into a match.
		if humanoid.Sit then
			local seat = humanoid.SeatPart
			local weld = seat and seat:FindFirstChild("SeatWeld")
			if weld and weld:IsA("Weld") and weld.Part1 and weld.Part1:IsDescendantOf(player.Character) then weld:Destroy() end
			humanoid.Sit = false
		end
		player:SetAttribute("DashStartedAt", 0)
		if player.Character then player.Character:SetAttribute("DashStartedAt", 0) end
		Remote:FireAllClients("DashCancel", player)
		Remote:FireClient(player, "DashStop")
		root.CFrame = CFrame.lookAt(position, position + Vector3.new(0, 0, faceDirection or 1))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		state.lastPosition = position
		state.sampleAt = os.clock()
		state.movementCredit = 8
		state.graceUntil = os.clock() + Config.PortalGrace
		player:SetAttribute("SafeUntil", workspace:GetServerTimeNow()+Config.PortalGrace)
	end
end

local function resetStamina(player)
	local state = sessions[player]
	state.stamina = Config.StaminaMax
	state.lastDash = -100
	state.lastExertion = -100
	state.exhausted = false
	state.routeBoostUntil = 0
	player:SetAttribute("RouteBoost",false)
	state.crystals, state.crystalCount = {}, 0
	state.staminaPadAt, state.dashPadAt = -100, -100
	state.bonusCrystals = 0
	player:SetAttribute("Stamina", Config.StaminaMax)
	player:SetAttribute("DashReadyAt", 0)
	player:SetAttribute("StaminaBuffReadyAt",0)
	player:SetAttribute("DashBuffReadyAt",0)
end

Passes.init(function(player) syncProfile(player) appearance(player) end, notify)
local function inLobby(player)
	local state = sessions[player]
	return state and not state.training and not state.tutorial and state.ready and (not state.inMatch or state.role == "Escaped")
end
Gear.init({owns=Passes.owns,inLobby=inLobby,creature=function(name)
	local model=Creature.create(name)
	Creature.track(model)
	return model
end,shot=function(from,to) Remote:FireAllClients("VIPShot",{from=from,to=to}) end})
local function visitLounge(player)
	if not inLobby(player) or not livingRoot(player) then return end
	if Passes.owns(player, "VIP") then
		teleport(player, Vector3.new(101, Config.LobbyFloorY + Config.FloorY, 224), -1)
	else
		Remote:FireClient(player, "OpenPasses")
	end
end
World.init({
	inLobby = inLobby,
	openMastery = function(player) Remote:FireClient(player,"OpenMastery") end,
	openShop = function(player) Remote:FireClient(player, "OpenPasses") end,
	openStyles = function(player) Remote:FireClient(player, "OpenCosmetics") end,
	lounge = visitLounge,
	returnLobby = function(player) teleport(player, lobbyPoint, -1) end,
	moveLobby = function(player, position) teleport(player, position, -1) end,
	isVIP = function(player) return Passes.owns(player, "VIP") end,
	notice = notify,
	celebrate = function(position) Remote:FireAllClients("Confetti", position) end,
	tutorial = function(player) Launch.start(player) end,
	parkourBegin = function(player) Launch.ghost(player) end,
	parkourFinish = function(player,seconds,frames,valid) Launch.parkourFinish(player,seconds,frames,valid) end,
})
Launch.init({profile=Profiles.get,sync=syncProfile,send=function(player,action,data) Remote:FireClient(player,action,data) end,
	canStart=function(player) return inLobby(player) and livingRoot(player)~=nil end,
	enter=function(player)
		local state=sessions[player] state.tutorial=true state.inMatch=false
		World.resetParkour(player) Gear.remove(player) setRole(player,"Spectator")
	end,
	leave=function(player) local state=sessions[player] if state then state.tutorial=false end end,
	reset=resetStamina,move=teleport})
Courses.activate(ReplicatedStorage:GetAttribute("MapId"))

Practice.init({
	profile = Profiles.get,
	canStart = function(player)
		local state = sessions[player]
		return state and state.ready and not state.inMatch and livingRoot(player) ~= nil
	end,
	reset = resetStamina, move = teleport,
	enter = function(player)
		sessions[player].training = true
		sessions[player].browsingMastery = false
		sessions[player].completed = false
		World.resetParkour(player)
		setRole(player,"Trainee")
	end,
	leave = function(player)
		local state = sessions[player]
		if not state then return end
		state.training = false
		setRole(player,"Spectator")
		resetStamina(player)
		teleport(player,lobbyPoint,-1)
	end,
	finished = function(player,mapId,stage,elapsed)
		local profile = Profiles.get(player)
		if not profile then return end
		local card = Mastery.finish(player,profile,mapId,stage,elapsed,true)
		if card then Remote:FireClient(player,"MasteryResult",card) end
	end,
})

local function resourcePickup(player,state,interaction,now)
	if interaction.kind == "Stamina" and now-state.staminaPadAt >= Config.PadCooldown and state.stamina < 85 then
		state.staminaPadAt,state.stamina = now,math.min(Config.StaminaMax,state.stamina+Config.PadRecharge)
		player:SetAttribute("StaminaBuffReadyAt",workspace:GetServerTimeNow()+Config.PadCooldown)
		state.exhausted = false
		Remote:FireClient(player,"Recharge",interaction.part.Position,"Stamina")
		notify(player,"Energy!")
		return true
	elseif interaction.kind == "Dash" and now-state.dashPadAt >= Config.PadCooldown and now-state.lastDash < Config.DashCooldown then
		state.dashPadAt,state.lastDash = now,now-Config.DashCooldown
		player:SetAttribute("DashBuffReadyAt",workspace:GetServerTimeNow()+Config.PadCooldown)
		player:SetAttribute("DashReadyAt",workspace:GetServerTimeNow())
		Remote:FireClient(player,"Recharge",interaction.part.Position,"Dash")
		notify(player,"Dash Ready!")
		return true
	end
	return false
end

local function victory(player,position)
	local profile, effect = Profiles.get(player), "Confetti"
	if profile then
		for _, definition in ipairs(Config.Cosmetics) do
			if definition.slot == "Victory" and definition.id == profile.VictoryEquipped and Rules.cosmeticAvailable(profile,definition,Passes.entitlements(player)) then effect = definition.effect end
		end
	end
	Remote:FireAllClients("Victory",{player=player,position=position,effect=effect})
end

local function aliveRunners()
	local result = {}
	for player, state in pairs(sessions) do
		if not state.training and (state.completed or (state.inMatch and (state.role == "Runner" or state.role == "Escaped"))) and player.Parent then
			table.insert(result, player)
		end
	end
	return result
end

local function broadcast(nextPhase, seconds, message)
	phase = nextPhase
	deadline = workspace:GetServerTimeNow() + seconds
	for name, value in pairs({ Phase = phase, Round = round, Wave = wave, Direction = direction,
		Deadline = deadline, Message = message, Practice = practice }) do
		ReplicatedStorage:SetAttribute(name, value)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Arena }
rayParams.RespectCanCollide = true

local function clearLine(from, to)
	return workspace:Raycast(from, to - from, rayParams) == nil
end

local function tag(player, attacker)
	local state = sessions[player]
	if not state or state.role ~= "Runner" or phase ~= "Crossing" then return end
	setRole(player, "Catcher")
	state.graceUntil = os.clock() + Config.TagGrace
	if attacker then reward(attacker, Config.TagCoins, Config.TagXP, "Tags") end
	notify(player, "Catch the runners!")
end

Captures.init({
	dodged = function(player)
		local state = sessions[player]
		if not state or state.role ~= "Runner" then return end
		state.graceUntil = os.clock()+Config.MissRecovery
		track(player, "dodge", state.stage)
		notify(player, "Nice Dodge!")
	end,
	canLunge = function(from, to)
		local stage = Rules.courseAt(from.X, from.Z, Config.Courses, Config.StartZ)
		return stage and Rules.inCourse(to.X, to.Z, Config.Courses[stage], Config.StartZ, 0) and Navigation.safeSegment(from, to)
	end,
	valid = function(player, actorRoot, actorPlayer)
		local state = sessions[player]
		local root = livingRoot(player)
		if not state or not root or not state.inMatch or phase ~= "Crossing" then return end
		if not actorPlayer then
			local humanoid = actorRoot.Parent:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.FloorMaterial == Enum.Material.Air or workspace:GetServerTimeNow() < (actorRoot.Parent:GetAttribute("NavigationRecoverUntil") or 0) then return end
		end
		if actorPlayer then
			local actor = sessions[actorPlayer]
			if not actor or not actor.inMatch or actor.role ~= "Catcher" or actor.stage ~= state.stage then return end
		end
		if Rules.courseAt(actorRoot.Position.X, actorRoot.Position.Z, Config.Courses, Config.StartZ) ~= state.stage then return end
		local delta = actorRoot.CFrame:PointToObjectSpace(root.Position)
		if Rules.canGrab(state.role, phase, delta.X, delta.Y, delta.Z, os.clock(), state.graceUntil, actorRoot.Parent:GetAttribute("Archetype")) and clearLine(actorRoot.Position, root.Position) then return root end
	end,
	started = function(player, attacker)
		track(player, "catch", sessions[player].stage)
		setRole(player, "Captured")
		if attacker then reward(attacker, Config.TagCoins, Config.TagXP, "Tags") end
		notify(player, "Gotcha!")
	end,
	finished = function(player)
		local state = sessions[player]
		if not state or not player.Parent then return end
		-- A dodged, unconfirmed reach leaves the runner in the chase.
		if state.role ~= "Captured" then return end
		setRole(player, state.inMatch and "Catcher" or "Spectator")
		if state.inMatch then teleport(player, catcherPoint(state.stage), -1)
		else teleport(player, lobbyPoint, -1) end
		state.graceUntil = os.clock() + Config.TagGrace + .7
		if state.inMatch then notify(player, "Catch the runners!") end
	end,
})

local function createBot(index, stage)
	local model = Creature.create("Rift Stalker " .. stage .. "/" .. index, false)
	local root = model.PrimaryPart
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local kind = Rules.botKind(stage, index)
	Creature.variant(model, kind)
	model.Parent = workspace
	local x,z=Rules.catcherStation(stage,index)
	local spawn=coursePoint(stage,x,z)
	model:PivotTo(CFrame.lookAt(spawn, spawn+Vector3.new(0, 0, -1)))
	root:SetNetworkOwner(nil)
	Creature.track(model)
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.UseJumpPower = Rules.botSpeed(kind, stage), 45, true
	model:SetAttribute("CourseStage", stage)
	local bot = { index = index, stage = stage, kind = kind, model = model, root = root, humanoid = humanoid, nextCharge = 0, spawnPoint = spawn }
	Navigation.reset(bot, os.clock())
	return bot
end

local function reconcileChasers()
	local counts, current, occupied = {}, {}, {}
	for _, state in pairs(sessions) do
		if state.inMatch and (state.role == "Runner" or state.role == "Captured") then counts[state.stage] = (counts[state.stage] or 0) + 1 end
	end
	local allocation = Rules.chaserAllocation(counts, Config.Courses, Config.MaxActiveBots)
	for index = #bots, 1, -1 do
		local bot = bots[index]
		current[bot.stage] = (current[bot.stage] or 0) + 1
		if current[bot.stage] > allocation[bot.stage] and not Captures.busy(bot.root) then
			current[bot.stage] -= 1
			Navigation.remove(bot)
			bot.model:Destroy()
			table.remove(bots, index)
		end
	end
	for _, bot in ipairs(bots) do occupied[bot.stage] = occupied[bot.stage] or {} occupied[bot.stage][bot.index] = true end
	for stage, wanted in ipairs(allocation) do
		local missing = wanted-(current[stage] or 0)
		for index = 1, Config.Courses[stage].bots do
			if missing > 0 and not (occupied[stage] and occupied[stage][index]) then table.insert(bots, createBot(index, stage)) missing -= 1 end
		end
		ReplicatedStorage:SetAttribute("Chasers_" .. stage, wanted)
	end
	-- Human catchers follow the surviving pack when their section empties.
	local front
	for stage = #Config.Courses, 1, -1 do if (counts[stage] or 0) > 0 then front = stage break end end
	if front then
		for player, state in pairs(sessions) do
			local root = livingRoot(player)
			if state.inMatch and state.role == "Catcher" and (counts[state.stage] or 0) == 0 and root and not Captures.busy(root) then
				setCourse(player, front)
				resetStamina(player)
				teleport(player, catcherPoint(front), -1)
				notify(player, "Next Course!")
			end
		end
	end
end

local function clearBots()
	Captures.cancelAll()
	for _, bot in ipairs(bots) do Navigation.remove(bot) bot.model:Destroy() end
	bots = {}
end

local function closestRunner(bot)
	local target, nearest, targetGrace = nil, math.huge, 0
	for player, state in pairs(sessions) do
		if state.role == "Runner" and state.inMatch and state.stage == bot.stage then
			local root = livingRoot(player)
			if root then
				local dist = (root.Position - bot.root.Position).Magnitude
				if dist < nearest then target, nearest, targetGrace = root, dist, state.graceUntil end
			end
		end
	end
	return target, targetGrace
end

local function stepBot(bot, now)
	if not bot.model.Parent then return end
	if bot.root.Position.Y < -8 or not Rules.inCourse(bot.root.Position.X, bot.root.Position.Z, Config.Courses[bot.stage], Config.StartZ, 2) then
		Captures.cancelActor(bot.root)
		Navigation.recover(bot, now)
		return
	end
	if Captures.busy(bot.root) and not Captures.winding(bot.root) then Navigation.idle(bot, now) return end
	if Captures.winding(bot.root) and bot.chargeAt then bot.chargeAt = nil bot.model:SetAttribute("ChargeStage", nil) end
	if Captures.recovering(bot.root) then bot.humanoid.WalkSpeed = 0 Navigation.idle(bot, now) return end
	bot.humanoid.WalkSpeed = Rules.botSpeed(bot.kind, bot.stage)
	Courses.contact(bot.root.Position, bot.stage, bot.humanoid.FloorMaterial ~= Enum.Material.Air, now)
	local target, targetGrace = closestRunner(bot)
	if not target then Navigation.idle(bot, now) return end
	-- Pursue on arrival. Protection gates grabs and charges, never movement.
	local delta = target.Position - bot.root.Position
	local flat = Vector3.new(delta.X, 0, delta.Z)
	if bot.chargeAt then
		local age = now-bot.chargeAt
		if age < Config.ChargeWindup then
			bot.humanoid.WalkSpeed = 0 bot.humanoid:Move(Vector3.zero) return
		elseif age < Config.ChargeWindup+Config.ChargeDuration then
			if not Navigation.safeSegment(bot.root.Position, bot.root.Position+bot.chargeDirection*9) then
				bot.chargeAt, bot.recoverAt = nil, now+1.1
				bot.model:SetAttribute("ChargeStage", nil)
				bot.model:SetAttribute("RecoverUntil", workspace:GetServerTimeNow()+1.1)
				Navigation.reset(bot, now+.5)
				bot.humanoid:Move(Vector3.zero)
				return
			end
			bot.model:SetAttribute("ChargeStage", "Charge")
			bot.humanoid.WalkSpeed = 41
			bot.humanoid:Move(bot.chargeDirection)
			return
		else
			bot.chargeAt, bot.recoverAt = nil, now+1.1
			bot.model:SetAttribute("ChargeStage", nil)
			bot.model:SetAttribute("RecoverUntil", workspace:GetServerTimeNow()+1.1)
		end
	end
	if now < (bot.recoverAt or 0) then bot.humanoid.WalkSpeed = 0 bot.humanoid:Move(Vector3.zero) return end
	if not Captures.winding(bot.root) and bot.kind == "Stalker" and bot.humanoid.FloorMaterial ~= Enum.Material.Air
		and now >= targetGrace and now >= bot.nextCharge and flat.Magnitude > 9 and flat.Magnitude < 24 and math.abs(delta.Y) < 3
		and Navigation.safeSegment(bot.root.Position, bot.root.Position+flat.Unit*(41*Config.ChargeDuration+3)) then
		Navigation.reset(bot, now+Config.ChargeWindup+Config.ChargeDuration)
		bot.chargeAt, bot.nextCharge, bot.chargeDirection = now, now+Config.ChargeCooldown, flat.Unit
		bot.root.CFrame = CFrame.lookAt(bot.root.Position, bot.root.Position+flat.Unit)
		bot.model:SetAttribute("ChargeStage", "Warning")
		Remote:FireAllClients("ChargeWarning", { model = bot.model, duration = Config.ChargeWindup })
		bot.humanoid.WalkSpeed = 0 bot.humanoid:Move(Vector3.zero)
		return
	end
	Navigation.follow(bot, target, now)
end

local function applyParkourRetry(player,state)
	if not state.pendingParkourRetry then return end
	if not World.canRetryParkour(player) then
		state.pendingParkourRetry=nil
		player:SetAttribute("ParkourRetryPending",false)
		return
	end
	if state.ready and not state.spawning and state.clientReadyCharacter==player.Character then
		local root=livingRoot(player)
		local character=player.Character
		-- Hold authority while the new character accepts its first spawn pose.
		if root then root:SetNetworkOwner(nil) end
		if World.retryParkour(player) then
			state.pendingParkourRetry=nil
			player:SetAttribute("ParkourRetryPending",false)
		end
		if root then task.delay(.3,function()
			if player.Parent and player.Character==character and root.Parent then root:SetNetworkOwner(player) end
		end) end
	end
end

local function loadCharacter(player)
	local state=sessions[player]
	if not state then return end
	state.spawning=true
	state.clientReadyCharacter=nil
	local ok=pcall(function() player:LoadCharacterAsync() end)
	state.spawning=false
	if sessions[player]~=state then return end
	if ok then applyParkourRetry(player,state) end
end

local function characterAdded(player, character)
	local state = sessions[player]
	if not state then return end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not root or not humanoid or not player.Parent then return end
	if state.training then Practice.leave(player) end
	local function prepare(item)
		if item:IsA("BasePart") then item.CollisionGroup = "RiftCharacters" end
	end
	for _, item in ipairs(character:GetDescendants()) do prepare(item) end
	character.DescendantAdded:Connect(prepare)
	humanoid.JumpPower, humanoid.UseJumpPower = 45, true
	state.ready = true
	if state.inMatch and state.role == "Catcher" and (phase == "Crossing" or phase == "Ready") then
		teleport(player, catcherPoint(state.stage), -1)
	else
		state.inMatch = false
		setRole(player, "Spectator")
		player:SetAttribute("CourseStage", 0)
		Metrics.stage(player, 0)
		teleport(player, lobbyPoint + Vector3.new(rng:NextNumber(-12, 12), 0, 0), -1)
	end
	appearance(player)
	humanoid.Died:Connect(function()
		Launch.cancel(player)
		World.failParkour(player)
		Gear.remove(player)
		state.ready = false
		if state.inMatch and state.role == "Runner" then setRole(player, "Catcher") end
		if state.role == "Escaped" then state.inMatch = false setRole(player, "Spectator") end
		task.delay(2, function()
			if player.Parent then
				loadCharacter(player)
			end
		end)
	end)
end

local function playerAdded(player)
	if sessions[player] then return end
	local state = { role = "Spectator", stage = 1, inMatch = false, ready = false, stamina = 100, sprinting = false,
		lastDash = -100, lastExertion = -100, graceUntil = 0, catcherTurns = 0, rateTokens = 12,
		rateAt = os.clock(), purchaseAt = -100, lastPosition = nil, sampleAt = os.clock(), exhausted = false, movementCredit = 8 }
	sessions[player] = state
	Metrics.join(player)
	player:SetAttribute("Role", "Spectator")
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("DashReadyAt", 0)
	player:SetAttribute("CourseStage", 0)
	player:SetAttribute("DashStartedAt", 0)
	player:SetAttribute("SoloPaused", false)
	player:SetAttribute("CoursePractice",false)
	player:SetAttribute("PracticeOffsetY",0)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name, leaderstats.Parent = "leaderstats", player
	for _, name in ipairs({ "Wins", "Tags", "Level" }) do
		local value = Instance.new("IntValue")
		value.Name, value.Parent = name, leaderstats
	end
	player.CharacterAdded:Connect(function(character) characterAdded(player, character) end)
	Profiles.load(player)
	if not player.Parent then Profiles.save(player, true) return end
	Passes.load(player)
	syncProfile(player)
	loadCharacter(player)
	Launch.attach(player)
end

Players.PlayerAdded:Connect(playerAdded)
for _, player in ipairs(Players:GetPlayers()) do task.spawn(playerAdded, player) end
Players.PlayerRemoving:Connect(function(player)
	soloPaused, quickRetry = false, false
	for other in pairs(sessions) do other:SetAttribute("SoloPaused", false) end
	Metrics.leave(player)
	Launch.leave(player)
	Captures.remove(player)
	Practice.leave(player,true)
	sessions[player] = nil
	Passes.remove(player)
	Gear.remove(player)
	World.remove(player)
	Profiles.save(player, true)
end)

Remote.OnServerEvent:Connect(function(player, action, payload)
	local state = sessions[player]
	if not state or type(action) ~= "string" then return end
	local now = os.clock()
	state.rateTokens = math.min(12, state.rateTokens + (now - state.rateAt) * 8)
	state.rateAt = now
	if state.rateTokens < 1 then return end
	state.rateTokens -= 1
	if action == "Playtest" then Metrics.sample(player, payload) return end
	if action == "CharacterReady" then
		if payload==player.Character then state.clientReadyCharacter=payload applyParkourRetry(player,state) end
		return
	end
	if action=="TutorialStart" then Launch.start(player) return end
	if action=="TutorialSkip" then Launch.skip(player) return end
	if action=="JourneyReady" then
		if now-(state.journeyRequestAt or -100)>.75 then state.journeyRequestAt=now Launch.sync(player) Launch.ghost(player) end
		return
	end
	if action == "MasteryMenu" and type(payload) == "boolean" then
		if not state.inMatch then
			state.browsingMastery = payload
			if payload and #Players:GetPlayers() == 1 then
				soloPaused,quickRetry = true,false
				player:SetAttribute("SoloPaused",true)
			end
		end
		return
	end
	if action == "PracticeCourse" then
		if type(payload) ~= "table" or type(payload.mapId) ~= "string" then return end
		if now-(state.practiceRequestAt or -100) < .75 then return end
		state.practiceRequestAt = now
		if not Practice.start(player,payload.mapId,payload.stage) then notify(player,"Reach this course in a run first!") end
		return
	end
	if action == "PracticeRetry" then
		if now-(state.practiceRequestAt or -100) >= .3 then state.practiceRequestAt = now Practice.restart(player) end
		return
	end
	if action == "PracticeLeave" then Practice.leave(player) return end
	if action == "Retry" then
		if #Players:GetPlayers() == 1 and (phase == "Results" or (phase == "Intermission" and soloPaused)) then
			soloPaused, retryRequested = false, true
			player:SetAttribute("SoloPaused", false)
		end
		return
	end
	if action == "PauseSolo" then
		if #Players:GetPlayers() == 1 and (phase == "Results" or (phase == "Crossing" and state.role == "Escaped")) then
			soloPaused, quickRetry = true, false
			player:SetAttribute("SoloPaused", true)
		end
		return
	end
	if action == "Vote" then World.voteOnPlate(player, payload) return end
	if action == "RefreshPasses" then Passes.refresh(player) return end
	if action == "VIPFire" then Gear.fire(player,payload,now) return end
	if action == "ParkourRetry" then
		if state.training or (state.inMatch and state.role~="Escaped") or not World.canRetryParkour(player) then return end
		state.pendingParkourRetry=true
		player:SetAttribute("ParkourRetryPending",true)
		applyParkourRetry(player,state)
		return
	end
	if action == "VisitVIP" then
		if now-(state.loungeRequestAt or -100) >= .75 then
			state.loungeRequestAt = now
			visitLounge(player)
		end
		return
	end
	if action == "Trail" or action == "Cosmetic" then
		if type(payload) ~= "string" or #payload > 20 or now - state.purchaseAt < 0.5 then return end
		state.purchaseAt = now
		if phase ~= "Intermission" and phase ~= "Results" and state.inMatch and state.role ~= "Escaped" then
			notify(player, "Customize your style between matches.") return
		end
		local profile = Profiles.get(player)
		if not profile then return end
		if action == "Cosmetic" then
			for _, definition in ipairs(Config.Cosmetics) do
				if definition.id == payload then
					local ok, message = Rules.purchaseCosmetic(profile, definition, Passes.entitlements(player))
					notify(player, message)
					if ok then syncProfile(player) appearance(player) end
					return
				end
			end
			return
		end
		for _, trail in ipairs(Config.Trails) do
			if trail.id == payload then
				local ok, message = Rules.purchase(profile, trail, Passes.entitlements(player))
				notify(player, message)
				if ok then syncProfile(player) appearance(player) end
				return
			end
		end
		return
	end
	if action == "Sprint" and type(payload) == "boolean" then state.sprinting = payload return end
	local training = Practice.get(player)
	local trainingActive = state.tutorial or (training and not training.finished and workspace:GetServerTimeNow() >= training.started)
	if action ~= "Dash" or not (trainingActive or (phase == "Crossing" and state.inMatch and (state.role == "Runner" or state.role == "Catcher"))) then return end
	if typeof(payload) ~= "Vector3" then return end
	if payload.X ~= payload.X or payload.Z ~= payload.Z or math.abs(payload.X) > 1.1 or math.abs(payload.Z) > 1.1 then return end
	local move = Vector3.new(payload.X, 0, payload.Z)
	if move.Magnitude < 0.1 then return end
	if not Rules.canDash(state.stamina, now, state.lastDash, Config.DashCost, Config.DashCooldown) then return end
	local root = livingRoot(player)
	if not root then return end
	if Captures.busy(root) or Captures.isVictim(player) then return end
	state.stamina -= Config.DashCost
	state.lastDash, state.lastExertion = now, now
	-- Confirm the dodge on the server before the next capture recheck. The
	-- client's visible dash can precede its replicated position update.
	if state.role == "Runner" then
		state.graceUntil = math.max(state.graceUntil,now+Config.DashDodgeSeconds)
		Captures.evade(player)
	end
	player:SetAttribute("DashLearned", true)
	if state.tutorial then Launch.dash(player) end
	if not state.training and not state.tutorial then track(player, "dash", state.stage) end
	root.AssemblyLinearVelocity = move.Unit * Config.DashSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	player:SetAttribute("DashReadyAt", workspace:GetServerTimeNow() + Config.DashCooldown)
	local dashStarted = workspace:GetServerTimeNow()
	player:SetAttribute("DashStartedAt", dashStarted)
	player.Character:SetAttribute("DashStartedAt", dashStarted)
	Remote:FireClient(player, "Dash", move.Unit)
	Remote:FireAllClients("DashFX", { player = player, direction = move.Unit, started = dashStarted })
end)

local accumulated, nextChaserUpdate = 0, 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated < 0.1 then return end
	local step = math.min(accumulated, 0.5)
	accumulated = 0
	local now = os.clock()
	Captures.step(workspace:GetServerTimeNow())
	Courses.step(now, phase == "Crossing")
	Practice.step(now)
	if phase == "Crossing" and (chaserRosterDirty or now >= nextChaserUpdate) then
		chaserRosterDirty = false
		reconcileChasers()
		nextChaserUpdate = now + 1
	end
	for player, state in pairs(sessions) do
		local root, humanoid = livingRoot(player)
		if root and humanoid then
			local training = Practice.get(player)
			local lesson=state.tutorial==true
			if not training and ((state.role == "Spectator" and not state.inMatch) or state.role == "Escaped") then World.stepLobby(player, root, humanoid) end
			local gearSpeed,gearJump = Gear.update(player,humanoid)
			local busy = (Captures.busy(root) and not Captures.winding(root)) or Captures.isVictim(player)
			local trainingActive = lesson or (training and not training.finished and workspace:GetServerTimeNow() >= training.started)
			local active = trainingActive or (phase == "Crossing" and state.inMatch and not busy and (state.role == "Runner" or state.role == "Catcher"))
			if state.exhausted and state.stamina >= 22 then state.exhausted = false end
			local sprint = active and state.sprinting and humanoid.MoveDirection.Magnitude > 0.05 and not state.exhausted and state.stamina > 0
			if sprint then player:SetAttribute("SprintLearned", true) end
			local boostContact = active and (training and Practice.contact(player,root,humanoid,now) or (not training and Courses.contact(root.Position,state.stage,humanoid.FloorMaterial ~= Enum.Material.Air,now)))
			if boostContact then
				state.routeBoostUntil = now+Config.RouteBoostSeconds
			end
			local boostSpeed = active and now < (state.routeBoostUntil or 0) and Config.RouteBoostSpeed or 0
			player:SetAttribute("RouteBoost", boostSpeed > 0)
			state.stamina, state.lastExertion = Rules.stepStamina(state.stamina, sprint, step, now, state.lastExertion, Config)
			if state.stamina <= 0 then state.exhausted = true end
			player:SetAttribute("Stamina", math.floor(state.stamina))
			local base = (state.role == "Catcher" and Config.CatcherSpeed or Config.WalkSpeed)+boostSpeed
			local fast = (state.role == "Catcher" and Config.CatcherSprintSpeed or Config.SprintSpeed)+boostSpeed
			local locked = (training and workspace:GetServerTimeNow() < training.started) or (state.inMatch and (phase == "Ready" or busy))
			humanoid.WalkSpeed = locked and 0 or (gearSpeed or ((sprint and fast or base)*(Captures.recovering(root) and .35 or 1)))
			humanoid.JumpPower = locked and 0 or (gearJump or 45)
			if Launch.step(player,root,humanoid,sprint,now) then continue end
			if locked and not busy and state.lastPosition then
				local drift = root.Position - state.lastPosition
				if Vector3.new(drift.X, 0, drift.Z).Magnitude > 1.5 then teleport(player, state.lastPosition, direction) end
				state.sampleAt = now
			end
			if training then
				local position = root.Position
				local delta = position-(state.lastPosition or position)
				local distance = Vector3.new(delta.X,0,delta.Z).Magnitude
				local elapsed = math.clamp(now-state.sampleAt,.1,2)
				local speed = now-state.lastDash < Config.DashDuration+.2 and Config.DashSpeed+5 or ((sprint and fast or base)+3)
				local allowed = state.movementCredit+speed*elapsed
				local status = Practice.check(player,root,workspace:GetServerTimeNow(),distance <= allowed)
				if status == "running" or status == "finished" then
					state.lastPosition,state.sampleAt,state.movementCredit = position,now,math.min(10,allowed-distance)
					if status == "running" then
						for _, pickup in ipairs(Practice.pickups(player)) do
							local gap = position-pickup.part.Position
							if Vector3.new(gap.X,0,gap.Z).Magnitude <= 5.5 and math.abs(gap.Y) <= 6 and Practice.clearLine(player,position,pickup.part.Position+Vector3.new(0,3,0)) then resourcePickup(player,state,pickup,now) end
						end
					end
				end
				continue
			end
			if active then
				local position = root.Position
				local course = Config.Courses[state.stage]
				local elapsed = math.clamp(now - state.sampleAt, 0.1, 2)
				local dash = now - state.lastDash < Config.DashDuration + 0.2
				local allowedSpeed = dash and Config.DashSpeed + 5 or (sprint and fast or base) + 3
				local maxDistance = state.movementCredit + allowedSpeed * elapsed
				local previous = state.lastPosition or position
				local delta = position - previous
				local horizontalDistance = Vector3.new(delta.X, 0, delta.Z).Magnitude
				if position.Y < -10 then
					track(player, "fall", state.stage)
					tag(player, nil)
					teleport(player, catcherPoint(state.stage), -1)
				elseif not Rules.inCourse(position.X, position.Z, course, Config.StartZ, 2) or horizontalDistance > maxDistance then
					state.masteryValid = false
					teleport(player, previous, direction)
					state.movementCredit = 0
				elseif position.Y > 38 then
					tag(player, nil)
					teleport(player, catcherPoint(state.stage), -1)
				else
					state.movementCredit = math.min(10, maxDistance - horizontalDistance)
					state.lastPosition, state.sampleAt = position, now
					local interactable = table.clone(World.getInteractions(state.stage))
					for _, interaction in ipairs(Courses.interactions(state.stage)) do table.insert(interactable, interaction) end
					for _, interaction in ipairs(interactable) do
						local deltaTo = position - interaction.part.Position
						if Rules.interactionAllowed(state.role, phase, state.inMatch, Vector3.new(deltaTo.X, 0, deltaTo.Z).Magnitude, math.abs(deltaTo.Y)) and clearLine(position, interaction.part.Position + Vector3.new(0, 3, 0)) then
							if resourcePickup(player,state,interaction,now) then
							elseif interaction.kind == "BonusCrystal" and state.role == "Runner" and state.bonusCrystals < 2 and not state.crystals[interaction.part] then
								state.crystals[interaction.part], state.bonusCrystals = true, state.bonusCrystals+1
								reward(player, Config.CrystalCoins, Config.CrystalXP)
								Remote:FireClient(player, "Crystal", interaction.part)
								track(player,"crystal",state.stage)
								notify(player, "Shortcut Bonus!")
							elseif interaction.kind == "Crystal" and state.role == "Runner" and state.crystalCount < Config.CrystalLimit and not state.crystals[interaction.part] then
								state.crystals[interaction.part], state.crystalCount = true, state.crystalCount + 1
								reward(player, Config.CrystalCoins, Config.CrystalXP)
								Remote:FireClient(player, "Crystal", interaction.part)
								track(player,"crystal",state.stage)
								notify(player, "+" .. Rules.rewardCoins(math.floor(Config.CrystalCoins*(practice and Config.PracticeRewardScale or 1)), practice and {} or Passes.entitlements(player)) .. " Coins")
							end
						end
					end
					local onward = Rules.courseFinish(state.role, phase, position.X, position.Z, state.stage, Config)
					if onward and now-state.courseBegan >= Config.MinCourseSeconds then
						track(player, "finish", state.stage)
						local profile = Profiles.get(player)
						local card = profile and state.masteryValid and Mastery.finish(player,profile,ReplicatedStorage:GetAttribute("MapId"),state.stage,now-state.courseBegan,false)
						if card then Remote:FireClient(player,"MasteryResult",card) end
						local firstUnlock = profile and profile.Crossings < 3
						reward(player, Config.CrossingCoins, Config.CrossingXP, "Crossings")
						if firstUnlock and profile.Crossings >= 3 then
							if (profile.TitleEquipped or "NoTitle") == "NoTitle" then profile.TitleEquipped = "CrystalScout" syncProfile(player) appearance(player) end
							Remote:FireClient(player, "ScoutUnlocked")
						end
						if onward == 0 then
							state.completed = true
							track(player, "complete", state.stage)
							setRole(player, "Escaped")
							teleport(player, lobbyPoint, -1)
							notify(player, "You Made It!")
							victory(player,root.Position)
						else
							setCourse(player, onward)
							resetStamina(player)
							teleport(player, coursePoint(onward, 0, -Config.StartZ), 1)
							notify(player, "Next Course!")
							Remote:FireClient(player, "CourseClear", { stage = onward, position = root.Position })
						end
					end
				end
			end
		end
	end
	Gear.stepEnemies(now)
	if phase == "Ready" then
		for _,bot in ipairs(bots) do
			local target = closestRunner(bot)
			if target then Navigation.prime(bot, target, now) end
		end
	end
	if phase ~= "Crossing" then return end
	-- A portal finish changes the roster in this heartbeat, before NPC movement.
	if chaserRosterDirty then
		chaserRosterDirty = false
		reconcileChasers()
		nextChaserUpdate = now + 1
	end
	for _, bot in ipairs(bots) do stepBot(bot, now) end
	local attackers = {}
	for player, state in pairs(sessions) do
		if state.role == "Catcher" and state.inMatch and now >= state.graceUntil then
			local root = livingRoot(player)
			if root and not Captures.busy(root) then table.insert(attackers, { stage = state.stage, root = root, player = player, model = player.Character:FindFirstChild("RiftCatcherCreature") }) end
		end
	end
	for _, bot in ipairs(bots) do if not Captures.busy(bot.root) and not Captures.recovering(bot.root) and bot.model:GetAttribute("ChargeStage") ~= "Warning" and now >= (bot.recoverAt or 0) then table.insert(attackers, { stage = bot.stage, root = bot.root, model = bot.model }) end end
	for player, state in pairs(sessions) do
		if state.role == "Runner" and state.inMatch then
			local root = livingRoot(player)
			if root then
				for _, attacker in ipairs(attackers) do
					if attacker.stage ~= state.stage then continue end
					local delta = attacker.root.CFrame:PointToObjectSpace(root.Position)
					if Rules.canGrab(state.role, phase, delta.X, delta.Y, delta.Z, now, state.graceUntil, attacker.model and attacker.model:GetAttribute("Archetype"))
						and clearLine(attacker.root.Position, root.Position) then
						Captures.tryGrab(player, attacker.model, attacker.root, attacker.player)
						break
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(Config.SaveInterval)
		for player in pairs(sessions) do task.spawn(Profiles.save, player, false) end
	end
end)

game:BindToClose(function()
	Metrics.report(ReplicatedStorage:GetAttribute("MapId"), round)
	local pending = 0
	for player in pairs(sessions) do
		pending += 1
		task.spawn(function() Profiles.save(player, true) pending -= 1 end)
	end
	local endAt = os.clock() + 25
	repeat task.wait(0.1) until pending == 0 or os.clock() >= endAt
end)

local function waitPhase(seconds, stopWhenResolved)
	local untilTime = os.clock() + seconds
	repeat
		task.wait(0.2)
		if phase == "Results" and practice and retryRequested then return end
		if stopWhenResolved then
			local remaining = false
			for _, state in pairs(sessions) do
				if state.inMatch and (state.role == "Runner" or state.role == "Captured") then remaining = true break end
			end
			if not remaining then return end
		end
	until os.clock() >= untilTime
	if stopWhenResolved then
		local settleUntil = os.clock() + Config.CaptureDuration + Config.GrabWindup + .5
		while Captures.hasActive() and os.clock() < settleUntil do task.wait(.1) end
		if Captures.hasActive() then Captures.cancelAll() end
	end
end

while true do
	clearBots()
	practice = false
	retryRequested = false
	wave = 0
	for player, state in pairs(sessions) do
		if state.training or state.tutorial or state.browsingMastery or World.isParkouring(player) or Gear.inArena(player) then continue end
		state.inMatch = false
		state.completed = false
		setRole(player, "Spectator")
		setCourse(player, 1)
		player:SetAttribute("CourseStage", 0)
		Metrics.stage(player, 0)
		resetStamina(player)
		teleport(player, lobbyPoint + Vector3.new(rng:NextNumber(-15, 15), 0, 0), -1)
	end
	World.startVoting()
	broadcast("Intermission", Config.Intermission, "Choose your next run!")
	waitPhase(Config.Intermission, false)
	local participants = {}
	for player, state in pairs(sessions) do
		if state.ready and not state.spawning and not state.training and not state.tutorial and not state.browsingMastery
			and not World.isParkouring(player) and not Gear.inArena(player) and livingRoot(player)
			and not (soloPaused and #Players:GetPlayers() == 1) then table.insert(participants, player) end
	end
	if #participants == 0 then task.wait(1) continue end
	World.choose(rng:NextInteger(1, #Config.Maps))
	Courses.activate(ReplicatedStorage:GetAttribute("MapId"))
	round += 1
	practice = #participants == 1
	if not practice then soloPaused = false end
	direction = 1
	local candidates = {}
	for _, player in ipairs(participants) do
		World.resetParkour(player)
		local state = sessions[player]
		state.inMatch = true
		player:SetAttribute("SoloPaused", false)
		track(player, "start", 1)
		if quickRetry then track(player, "retry", 1) end
		setCourse(player, 1)
		setRole(player, "Runner")
		table.insert(candidates, { id = player, turns = state.catcherTurns })
	end
	if not practice then
		for _ = 1, Rules.initialCatcherCount(#participants, Config.PlayersPerCatcher) do
			local selected = Rules.selectCatcher(candidates, rng:NextInteger(1, #candidates))
			sessions[selected].catcherTurns += 1
			setRole(selected, "Catcher")
			for index, candidate in ipairs(candidates) do if candidate.id == selected then table.remove(candidates, index) break end end
		end
	end
	wave = 1
	local runners, index = aliveRunners(), 0
	for _, player in ipairs(participants) do
		local state = sessions[player]
		resetStamina(player)
		if state.role == "Runner" then
			index += 1
			local x = #runners == 1 and 0 or -60 + (index - 1) * 120 / math.max(1, #runners - 1)
			teleport(player, coursePoint(1, x, -Config.StartZ), 1)
		else teleport(player, catcherPoint(1), -1) end
	end
	reconcileChasers()
	for _, bot in ipairs(bots) do bot.humanoid.WalkSpeed = 0 end
	local readySeconds = Config.ReadySeconds
	broadcast("Ready", readySeconds, "Run to Finish!")
	waitPhase(readySeconds, false)
	for _, bot in ipairs(bots) do bot.humanoid.WalkSpeed = Rules.botSpeed(bot.kind, bot.stage) end
	-- Individual course transitions keep this single shared run clock ticking.
	broadcast("Crossing", Config.RunSeconds, "CLEAR FIVE RIFTS. OUTRUN THE HORDE.")
	for _, player in ipairs(participants) do
		sessions[player].courseBegan = os.clock()
		sessions[player].graceUntil = os.clock()+Config.PortalGrace
		player:SetAttribute("SafeUntil",workspace:GetServerTimeNow()+Config.PortalGrace)
		player:SetAttribute("CourseStartedAt",workspace:GetServerTimeNow())
	end
	waitPhase(Config.RunSeconds, true)
	phase = "Resolving"
	for player, state in pairs(sessions) do
		if state.inMatch and state.role == "Runner" then
			setRole(player, "Catcher")
			notify(player, "Time's Up!")
		end
	end
	local winners = aliveRunners()
	local winnerSet = {}
	for _, player in ipairs(winners) do
		winnerSet[player] = true
		reward(player, Config.WinCoins, Config.WinXP, not practice and "Wins" or nil)
	end
	local resultText = #winners > 0 and (#winners .. " runner" .. (#winners == 1 and "" or "s") .. " survived the valley!") or "The catchers claimed the valley."
	if practice then
		resultText = #winners > 0 and "Practice complete: all five courses cleared!" or "Practice ended: the catchers claimed the valley."
	end
	if #winners == 0 then
		for player, state in pairs(sessions) do
			if state.inMatch and state.role == "Catcher" then reward(player, Config.WinCoins, Config.WinXP, "Wins") end
		end
	end
	clearBots()
	quickRetry = practice and #Players:GetPlayers() == 1 and not soloPaused
	local resultsSeconds = quickRetry and Config.SoloRetrySeconds or Config.ResultsSeconds
	broadcast("Results", resultsSeconds, resultText)
	Metrics.report(ReplicatedStorage:GetAttribute("MapId"), round)
	for player, state in pairs(sessions) do
		if state.training or state.tutorial or World.isParkouring(player) or Gear.inArena(player) then
			state.inMatch=false state.completed=false
			continue
		end
		if state.inMatch then
			Remote:FireClient(player, "Results", { won = winnerSet[player] == true or (not practice and #winners == 0), message = resultText, practice = practice })
		end
		state.inMatch = false
		setRole(player, "Spectator")
		player:SetAttribute("CourseStage", 0)
		Metrics.stage(player, 0)
		teleport(player, lobbyPoint + Vector3.new(rng:NextNumber(-15, 15), 0, 0), -1)
	end
	waitPhase(resultsSeconds, false)
end
