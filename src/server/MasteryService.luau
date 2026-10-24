local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Config, Rules = require(Shared.Config), require(Shared.Rules)
local Mastery = {}
local stats = { "MedalPoints", "BronzeMedals", "SilverMedals", "GoldMedals", "GroveMedals", "RuinsMedals", "HarborMedals" }

function Mastery.ensure(profile)
	if not profile.Mastery or profile.Mastery.Revision ~= Rules.MasteryRevision then profile.Mastery = Rules.sanitizeProfile(profile, Config.Trails, Config.Cosmetics).Mastery end
	Rules.refreshMastery(profile)
	return profile.Mastery
end

function Mastery.sync(player, profile)
	local data = Mastery.ensure(profile)
	player:SetAttribute("UnlockedCourse", data.UnlockedCourse)
	for _, stat in ipairs(stats) do player:SetAttribute(stat, profile[stat]) end
	for _, map in ipairs(Config.Maps) do
		for stage = 1, #Config.Courses do
			local key = Rules.masteryKey(map.id, stage)
			local race, practice = data.Races[key], data.Practice[key]
			player:SetAttribute("Best_" .. key, race and race.bestMs and race.bestMs/1000 or nil)
			player:SetAttribute("Medal_" .. key, race and race.medal or 0)
			player:SetAttribute("PracticeBest_" .. key, practice and practice.bestMs and practice.bestMs/1000 or nil)
		end
	end
end

function Mastery.reached(profile, stage)
	local data = Mastery.ensure(profile)
	if stage >= 1 and stage <= #Config.Courses then data.UnlockedCourse = math.max(data.UnlockedCourse, stage) end
end

function Mastery.finish(player, profile, mapId, stage, elapsed, training)
	Mastery.ensure(profile)
	local available = {}
	for _, definition in ipairs(Config.Trails) do available[definition.id] = Rules.trailAvailable(profile, definition, {}) end
	for _, definition in ipairs(Config.Cosmetics) do available[definition.id] = Rules.cosmeticAvailable(profile, definition, {}) end
	local result = Rules.recordCourse(profile, Config, mapId, stage, elapsed, training)
	if not result then return nil end
	result.unlocks = {}
	for _, definition in ipairs(Config.Trails) do
		if definition.requirement and not available[definition.id] and Rules.trailAvailable(profile, definition, {}) then table.insert(result.unlocks, definition.name) end
	end
	for _, definition in ipairs(Config.Cosmetics) do
		if definition.requirement and not available[definition.id] and Rules.cosmeticAvailable(profile, definition, {}) then table.insert(result.unlocks, definition.name) end
	end
	Mastery.sync(player, profile)
	return result
end

return Mastery
