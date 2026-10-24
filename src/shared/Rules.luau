-- Engine-independent rules also exercised by tests/rules.spec.luau.
local Rules = {}
Rules.MasteryRevision = 2
local masteryMaps = { CrystalGrove = "GroveMedals", SunsetRuins = "RuinsMedals", NeonHarbor = "HarborMedals" }

function Rules.masteryKey(mapId, stage)
	if not masteryMaps[mapId] or type(stage) ~= "number" or stage % 1 ~= 0 or stage < 1 or stage > 5 then return nil end
	return mapId .. "_" .. stage
end

function Rules.refreshMastery(profile)
	for _, stat in ipairs({ "MedalPoints", "BronzeMedals", "SilverMedals", "GoldMedals", "GroveMedals", "RuinsMedals", "HarborMedals" }) do profile[stat] = 0 end
	for mapId, stat in pairs(masteryMaps) do
		for stage = 1, 5 do
			local record = profile.Mastery.Races[Rules.masteryKey(mapId, stage)]
			if record then
				profile.MedalPoints += record.medal
				profile.BronzeMedals += 1
				profile.SilverMedals += record.medal >= 2 and 1 or 0
				profile.GoldMedals += record.medal == 3 and 1 or 0
				profile[stat] += 1
			end
		end
	end
end

function Rules.medalTargets(config, mapId, stage)
	if not Rules.masteryKey(mapId, stage) then return nil end
	local scale = config.Mastery.ThemeScale[mapId]
	return config.Mastery.GoldSeconds[stage]*scale, config.Mastery.SilverSeconds[stage]*scale
end

function Rules.recordCourse(profile, config, mapId, stage, seconds, training)
	local key = Rules.masteryKey(mapId, stage)
	if not key or type(seconds) ~= "number" or seconds ~= seconds or seconds < config.MinCourseSeconds or seconds > config.RunSeconds then return nil end
	local ms = math.floor(seconds*1000+.5)
	local gold, silver = Rules.medalTargets(config, mapId, stage)
	local medal = ms <= math.floor(gold*1000+.5) and 3 or (ms <= math.floor(silver*1000+.5) and 2 or 1)
	local records = training and profile.Mastery.Practice or profile.Mastery.Races
	local old = records[key]
	local previous = old and old.bestMs
	local newBest = not previous or ms < previous
	local bestMedal = training and 0 or math.max(old and old.medal or 0, medal)
	records[key] = { bestMs = newBest and ms or previous, medal = bestMedal, legacyBestMs = old and old.legacyBestMs }
	if not training then Rules.refreshMastery(profile) end
	return { mapId = mapId, stage = stage, time = ms/1000, best = records[key].bestMs/1000,
		delta = previous and (previous-ms)/1000, newBest = newBest, medal = training and 0 or medal,
		bestMedal = bestMedal, practice = training == true, gold = gold, silver = silver }
end

function Rules.trailAvailable(profile, trail, entitlements)
	if not trail or not profile then return false end
	if trail.pass then return entitlements and entitlements[trail.pass] == true end
	if trail.requirement then return (profile[trail.requirement.stat] or 0) >= trail.requirement.amount end
	return trail.cost == 0 or profile.Owned[trail.id] == true
end

function Rules.isGoal(z, direction, halfLength)
	return z * direction >= halfLength
end

function Rules.inArena(x, z, halfWidth, startZ)
	return math.abs(x) <= halfWidth and math.abs(z) <= startZ + 12
end

function Rules.inCourse(x, z, course, startZ, margin)
	return Rules.inArena(x - course.x, z - course.z, course.halfWidth + (margin or 0), startZ)
end

function Rules.courseAt(x, z, courses, startZ)
	for index, course in ipairs(courses) do
		if Rules.inCourse(x, z, course, startZ, 2) then return index end
	end
	return nil
end

function Rules.courseFinish(role, phase, x, z, stage, config)
	local course = config.Courses[stage]
	if role ~= "Runner" or phase ~= "Crossing" or not course
		or not Rules.inCourse(x, z, course, config.StartZ, 0)
		or z - course.z < config.ArenaHalfLength then return nil end
	return stage < #config.Courses and stage + 1 or 0
end

-- Later sections get priority when a split group reaches the NPC budget.
function Rules.chaserAllocation(counts, courses, budget)
	local result, remaining = {}, budget
	for index, course in ipairs(courses) do
		result[index] = (counts[index] or 0) > 0 and 1 or 0
		remaining -= result[index]
	end
	for index = #courses, 1, -1 do
		if result[index] > 0 then
			local extra = math.min(courses[index].bots - 1, math.max(0, remaining))
			result[index] += extra
			remaining -= extra
		end
	end
	return result
end

function Rules.canDash(stamina, now, lastDash, cost, cooldown)
	return stamina >= cost and now - lastDash >= cooldown
end

function Rules.stepStamina(stamina, sprinting, dt, now, lastExertion, config)
	if sprinting and stamina > 0 then
		return math.max(0, stamina - config.StaminaDrain * dt), now
	end
	if now - lastExertion >= config.StaminaRegenDelay then
		return math.min(config.StaminaMax, stamina + config.StaminaRegen * dt), lastExertion
	end
	return stamina, lastExertion
end

function Rules.level(xp)
	return 1 + math.floor(math.sqrt(math.max(0, xp) / 100))
end

function Rules.canTag(runnerRole, phase, distance, height, now, graceUntil)
	return runnerRole == "Runner" and phase == "Crossing" and distance <= 4.2
		and height <= 3.2 and now >= graceUntil
end

function Rules.canGrab(role, phase, x, y, z, now, graceUntil, kind)
	local bounds = Rules.grabBounds(kind)
	return Rules.canTag(role, phase, math.sqrt(x*x + z*z), math.abs(y), now, graceUntil)
		and math.abs(x) <= bounds.width and z >= -bounds.depth and z <= bounds.back
end

function Rules.grabBounds(kind)
	return { width = kind == "Stalker" and 2.3 or 3.1, depth = kind == "Stalker" and 3.4 or 4, back = .25, radius = 4.2 }
end

-- Clip the contact circle to the exact front/side limits used by canGrab.
function Rules.grabOutline(kind)
	local bounds, polygon = Rules.grabBounds(kind), {}
	for index=0,47 do local angle=index/48*math.pi*2 table.insert(polygon,{x=math.cos(angle)*bounds.radius,z=math.sin(angle)*bounds.radius}) end
	for _,plane in ipairs({{1,0,bounds.width},{-1,0,bounds.width},{0,1,bounds.back},{0,-1,bounds.depth}}) do
		local clipped={}
		for index,a in ipairs(polygon) do
			local b=polygon[index%#polygon+1]
			local da,db=plane[1]*a.x+plane[2]*a.z-plane[3],plane[1]*b.x+plane[2]*b.z-plane[3]
			if da<=0 then table.insert(clipped,a) end
			if (da<=0)~=(db<=0) then local t=da/(da-db) table.insert(clipped,{x=a.x+(b.x-a.x)*t,z=a.z+(b.z-a.z)*t}) end
		end
		polygon=clipped
	end
	return polygon
end

local challengePool = {
	{id="Course3",event="finish",target=3,coins=35,text="Finish 3 courses"},
	{id="Coins6",event="crystal",target=6,coins=35,text="Collect 6 rift coins"},
	{id="Dodge3",event="dodge",target=3,coins=45,text="Dodge 3 attacks"},
	{id="Ascent1",event="parkour",target=1,coins=50,text="Finish Rift Ascent"},
	{id="Escape1",event="complete",target=1,coins=60,text="Escape all 5 courses"},
	{id="Course6",event="finish",target=6,coins=60,text="Finish 6 courses"},
	{id="Coins12",event="crystal",target=12,coins=55,text="Collect 12 rift coins"},
}
function Rules.dailyChallenges(day)
	local result={}
	for index=0,2 do result[index+1]=challengePool[(day+index*2)%#challengePool+1] end
	return result
end

function Rules.sanitizeGhost(value)
	if type(value)~="table" or value.revision~=1 or type(value.frames)~="table" or #value.frames<2 or #value.frames>602 then return nil end
	local frames,previous={},-1
	for _,frame in ipairs(value.frames) do
		if type(frame)~="table" or #frame~=5 then return nil end
		for _,n in ipairs(frame) do if type(n)~="number" or n~=n or math.abs(n)>1000000 or n%1~=0 then return nil end end
		if frame[1]<=previous or frame[1]>120000 or frame[2]<-1450 or frame[2]>-600 or frame[3]<-650 or frame[3]>900 or frame[4]<1900 or frame[4]>2750 or math.abs(frame[5])>3142 then return nil end
		previous=frame[1] table.insert(frames,table.clone(frame))
	end
	if frames[1][1]~=0 or previous<15000 or value.durationMs~=previous then return nil end
	return {revision=1,durationMs=previous,frames=frames}
end

function Rules.botKind(stage, index)
	return (stage <= 2 or index % 2 == 1) and "Bruiser" or "Stalker"
end

function Rules.botSpeed(kind, stage)
	local speeds = kind == "Stalker" and {30,31,32.25,33,33.5} or {29,30,31,32,32.5}
	return speeds[stage]
end

-- Supported interception stations ahead of the runner entry, with room to
-- approach through the course's actual openings rather than spawning in walls.
function Rules.catcherStation(stage,index)
	if stage==1 then return index%2==1 and -46 or 46,-56 end
	if stage==2 then return -22+(index-1)*22,-52 end
	if stage==3 then return index%2==1 and -22 or 22,-62+math.floor((index-1)/2)*12 end
	if stage==4 then return 6+(index-1)*3,-40 end
	return index%2==1 and -22 or 22,-78+math.floor((index-1)/2)*18
end

function Rules.onSurface(position, part, grounded)
	local p, s = part.Position, part.Size
	return grounded and part.CanCollide and math.abs(position.X-p.X) <= s.X/2+.4
		and math.abs(position.Z-p.Z) <= s.Z/2+.4
		and position.Y >= p.Y+s.Y/2+1.5 and position.Y <= p.Y+s.Y/2+5.5
end

function Rules.selectCatcher(candidates, pick)
	local minimum = math.huge
	local choices = {}
	for _, candidate in ipairs(candidates) do
		if candidate.turns < minimum then
			minimum = candidate.turns
			choices = { candidate.id }
		elseif candidate.turns == minimum then
			table.insert(choices, candidate.id)
		end
	end
	if #choices == 0 then return nil end
	return choices[1 + ((pick - 1) % #choices)]
end

function Rules.cosmeticAvailable(profile, definition, entitlements)
	if not profile or not definition then return false end
	if definition.pass then return entitlements ~= nil and entitlements[definition.pass] == true end
	if definition.requirement then return (profile[definition.requirement.stat] or 0) >= definition.requirement.amount end
	return definition.cost == 0 or (profile.CosmeticOwned ~= nil and profile.CosmeticOwned[definition.id] == true)
end

function Rules.purchaseCosmetic(profile, definition, entitlements)
	if not definition then return false, "Unknown cosmetic." end
	local field = definition.slot .. "Equipped"
	if Rules.cosmeticAvailable(profile, definition, entitlements) then
		profile[field] = definition.id
		return true, "Equipped " .. definition.name .. "."
	end
	if definition.pass then return false, "This cosmetic is included with Valley VIP. Visit Passes." end
	if definition.requirement then return false, "Reach " .. definition.requirement.amount .. " " .. string.lower(definition.requirement.stat) .. " to unlock " .. definition.name .. "." end
	if profile.Coins < definition.cost then return false, "You need " .. definition.cost .. " coins." end
	profile.Coins -= definition.cost
	profile.CosmeticOwned = profile.CosmeticOwned or {}
	profile.CosmeticOwned[definition.id] = true
	profile[field] = definition.id
	return true, "Unlocked " .. definition.name .. "."
end

function Rules.sanitizeProfile(data, trails, cosmetics)
	local result = { Coins = 0, XP = 0, Wins = 0, Tags = 0, Crossings = 0, Owned = { None = true }, Equipped = "None",
		CosmeticOwned = { NoAura = true, NoTitle = true, DefaultSkin = true, DefaultVictory = true }, AuraEquipped = "NoAura", TitleEquipped = "NoTitle",
		SkinEquipped = "DefaultSkin", VictoryEquipped = "DefaultVictory", TutorialSeen=false, TutorialCompleted=false,
		ParkourFinishes=0, ParkourBestMs=0, Daily={day=0,progress={},claimed={}},
		Mastery = { Revision = Rules.MasteryRevision, UnlockedCourse = 1, Races = {}, Practice = {} } }
	Rules.refreshMastery(result)
	if type(data) ~= "table" then return result end
	for _, key in ipairs({ "Coins", "XP", "Wins", "Tags", "Crossings", "ParkourFinishes" }) do
		local value = data[key]
		if type(value) == "number" and value == value and value < math.huge then
			result[key] = math.clamp(math.floor(value), 0, 1000000000)
		end
	end
	result.TutorialSeen=data.TutorialSeen==true
	result.TutorialCompleted=data.TutorialCompleted==true
	local pb=data.ParkourBestMs
	if type(pb)=="number" and pb==pb and pb>=15000 and pb<=3600000 then result.ParkourBestMs=math.floor(pb) end
	local ghost=Rules.sanitizeGhost(data.ParkourGhost)
	if ghost and ghost.durationMs==result.ParkourBestMs then result.ParkourGhost=ghost end
	local daily=type(data.Daily)=="table" and data.Daily or {}
	if type(daily.day)=="number" and daily.day==daily.day and daily.day>=0 and daily.day<=100000 and daily.day%1==0 then
		result.Daily.day=daily.day
		for _,goal in ipairs(Rules.dailyChallenges(daily.day)) do
			local progress=type(daily.progress)=="table" and daily.progress[goal.id]
			if type(progress)=="number" and progress==progress then result.Daily.progress[goal.id]=math.clamp(math.floor(progress),0,goal.target) end
			result.Daily.claimed[goal.id]=type(daily.claimed)=="table" and daily.claimed[goal.id]==true and result.Daily.progress[goal.id]==goal.target or false
		end
	end
	local mastery = type(data.Mastery) == "table" and data.Mastery or {}
	local function validTime(value)
		return type(value) == "number" and value == value and value >= 6000 and value <= 150000
	end
	local unlocked = mastery.UnlockedCourse
	result.Mastery.UnlockedCourse = type(unlocked) == "number" and unlocked == unlocked and math.clamp(math.floor(unlocked), 1, 5) or math.min(5, result.Crossings+1)
	for _, mode in ipairs({ "Races", "Practice" }) do
		local records = type(mastery[mode]) == "table" and mastery[mode] or {}
		for mapId in pairs(masteryMaps) do
			for stage = 1, 5 do
				local key = Rules.masteryKey(mapId, stage)
				local record = records[key]
				if type(record) == "table" and (validTime(record.bestMs) or validTime(record.legacyBestMs)) then
					local medal = record.medal
					if mode == "Practice" or (type(medal) == "number" and medal == medal and medal >= 1 and medal <= 3 and medal % 1 == 0) then
						local current = mastery.Revision == Rules.MasteryRevision and validTime(record.bestMs) and math.floor(record.bestMs) or nil
						local legacy = mastery.Revision ~= Rules.MasteryRevision and validTime(record.bestMs) and math.floor(record.bestMs) or (validTime(record.legacyBestMs) and math.floor(record.legacyBestMs) or nil)
						result.Mastery[mode][key] = { bestMs = current, legacyBestMs = legacy, medal = mode == "Practice" and 0 or medal }
						if mode == "Races" then result.Mastery.UnlockedCourse = math.max(result.Mastery.UnlockedCourse, stage) end
					end
				end
			end
		end
	end
	Rules.refreshMastery(result)
	for _, trail in ipairs(trails) do
		if not trail.pass and not trail.requirement and type(data.Owned) == "table" and data.Owned[trail.id] == true then
			result.Owned[trail.id] = true
		end
		if data.Equipped == trail.id and (trail.pass or Rules.trailAvailable(result, trail, {})) then result.Equipped = trail.id end
	end
	if type(data.Equipped) == "string" and result.Owned[data.Equipped] then
		result.Equipped = data.Equipped
	end
	for _, definition in ipairs(cosmetics or {}) do
		if not definition.pass and not definition.requirement and type(data.CosmeticOwned) == "table" and data.CosmeticOwned[definition.id] == true then
			result.CosmeticOwned[definition.id] = true
		end
		local field = definition.slot .. "Equipped"
		if data[field] == definition.id and (definition.pass or Rules.cosmeticAvailable(result, definition, {})) then result[field] = definition.id end
	end
	return result
end

function Rules.purchase(profile, trail, entitlements)
	if not trail then return false, "Unknown trail." end
	if trail.requirement then
		if not Rules.trailAvailable(profile, trail, entitlements) then return false, "Earn more course medals to unlock this trail." end
		profile.Equipped = trail.id
		return true, "Equipped " .. trail.name .. "."
	end
	if trail.pass then
		if not entitlements or entitlements[trail.pass] ~= true then return false, "This trail requires its game pass. Visit Passes." end
		profile.Equipped = trail.id
		return true, "Equipped " .. trail.name .. "."
	end
	if profile.Owned[trail.id] then
		profile.Equipped = trail.id
		return true, "Equipped " .. trail.name .. "."
	end
	if profile.Coins < trail.cost then return false, "You need " .. tostring(trail.cost) .. " coins." end
	profile.Coins -= trail.cost
	profile.Owned[trail.id] = true
	profile.Equipped = trail.id
	return true, "Unlocked " .. trail.name .. "."
end

function Rules.chooseMap(maps, votes, previous, pick)
	local most, choices = -1, {}
	for _, map in ipairs(maps) do
		local count = 0
		for _, vote in pairs(votes) do if vote == map.id then count += 1 end end
		if count > most then most, choices = count, { map.id }
		elseif count == most then table.insert(choices, map.id) end
	end
	if #choices > 1 then
		for index, id in ipairs(choices) do if id == previous then table.remove(choices, index) break end end
	end
	return choices[1 + ((pick - 1) % #choices)]
end

function Rules.interactionAllowed(role, phase, inMatch, distance, height)
	return phase == "Crossing" and inMatch and (role == "Runner" or role == "Catcher") and distance <= 5.5 and height <= 6
end

function Rules.rewardCoins(coins, entitlements)
	return coins * (entitlements and entitlements.DoubleCoins == true and 2 or 1)
end

function Rules.initialCatcherCount(players, perCatcher)
	return math.min(players - 1, math.max(1, math.floor(players / perCatcher)))
end

function Rules.lobbyZone(x, y, z)
	if y > 88 then return nil end
	if x>=-226 and x<=-194 and z>=280 and z<=412 and y>=-10 then return "Tutorial" end
	if x >= -142 and x <= -62 and z >= 192 and z <= 272 and y >= -65 then return "Parkour" end
	if y < 25 then return nil end
	if x >= -52 and x <= 52 and z >= 192 and z <= 278 then return "Main" end
	if x >= -72 and x <= 72 and z >= 276 and z <= 372 then return "Plaza" end
	if x >= -62 and x <= -52 and z >= 220 and z <= 236 then return "Bridge" end
	if x >= 77 and x <= 125 and z >= 196 and z <= 252 then return "Lounge" end
	if x > 125 and x <= 148 and z >= 216 and z <= 232 then return "VIPBridge" end
	if x >= 148 and x <= 218 and z >= 194 and z <= 254 then return "VIPActivity" end
	return nil
end
function Rules.onParkourStep(x, y, z, cx, top, cz, grounded, halfX, halfZ)
	return grounded and math.abs(x - cx) <= (halfX or 3) and math.abs(z - cz) <= (halfZ or 3) and y >= top + 1.5 and y <= top + 5.5
end
return table.freeze(Rules)
