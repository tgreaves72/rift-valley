-- Run the actual ProfileStore module against a controlled DataStore API substitute.
-- This checks lease and failure behavior; it does not assert live Roblox API access.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Config = require("../src/shared/Config")
local Rules = require("../src/shared/Rules")
local source = fs.readFile("src/server/ProfileStore.luau")
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end
local function player(id)
	return { UserId = id, Parent = true, attributes = {}, SetAttribute = function(self, key, value) self.attributes[key] = value end }
end

local function host(studio, options)
	options = options or {}
	local gameId = options.gameId or 1
	local backend = { records = {}, calls = 0, getCalls = 0, failures = 0, token = 0 }
	local store = {}
	function store:UpdateAsync(key, transform)
		backend.calls += 1
		if backend.failures > 0 then backend.failures -= 1 error("simulated API failure") end
		if backend.beforeUpdate then local callback = backend.beforeUpdate backend.beforeUpdate = nil callback() end
		local result = transform(clone(backend.records[key]))
		if result == nil then return nil end
		backend.records[key] = clone(result)
		return clone(result)
	end
	local shared = { Config = "config", Rules = "rules" }
	local services = {
		DataStoreService = { GetDataStore = function()
			backend.getCalls += 1
			assert(not studio and gameId ~= 0, "You must publish this place to the web to access DataStore.")
			if options.failCreation then error("simulated DataStore initialization failure") end
			return store
		end },
		HttpService = { GenerateGUID = function() backend.token += 1 return "test-token-" .. backend.token end },
		RunService = { IsStudio = function() return studio end },
		ReplicatedStorage = { WaitForChild = function() return shared end },
	}
	local environment = {
		game = { GameId = gameId, GetService = function(_, name) return services[name] end },
		task = { wait = function() end },
		require = function(name) if name == "config" then return Config elseif name == "rules" then return Rules end error("unknown module") end,
	}
	return luau.load(source, { environment = environment, debugName = "ProfileStoreUnderTest" })(), backend
end

local profiles, backend = host(true)
local p = player(1)
local data = profiles.load(p)
check(backend.calls == 0 and backend.getCalls == 0, "Studio must never create or access a DataStore")
data.Coins = 60
check(profiles.save(p, false) and backend.calls == 0, "Studio save stays local")
check(p.attributes.SaveStatus == "Studio session", "Studio status truthful")

profiles, backend = host(true, { gameId = 0 })
p = player(9)
data = profiles.load(p)
check(backend.getCalls == 0 and data.Owned.None, "unpublished Studio place starts without DataStore access")
check(profiles.save(p, true) and backend.getCalls == 0, "unpublished Studio shutdown never creates a store")

profiles, backend = host(false, { gameId = 0 })
p = player(10)
data = profiles.load(p)
check(backend.getCalls == 0 and data.Coins == 0, "unpublished place outside Studio skips store creation")

profiles, backend = host(false, { failCreation = true })
p = player(11)
data = profiles.load(p)
check(backend.getCalls == 3 and backend.calls == 0, "handle initialization retries inside protected load")
check(p.attributes.SaveStatus == "Session only: profile unavailable", "failed handle initialization does not crash game startup")

profiles, backend = host(false)
p = player(2)
data = profiles.load(p)
check(data.Coins == 0 and data.Owned.None, "new profile defaults")
check(backend.records.Player_2.Session.Token == "test-token-1", "load acquires session lease")
check(p.attributes.SaveStatus == "Saved", "loaded status")
data.Coins, data.Wins = 140, 1
check(profiles.save(p, false), "autosave succeeds")
check(backend.records.Player_2.Coins == 140 and backend.records.Player_2.Wins == 1, "autosave persists actual data")
check(backend.records.Player_2.Session ~= nil, "autosave renews lease")
check(profiles.save(p, true), "disconnect save succeeds")
check(backend.records.Player_2.Session == nil, "disconnect releases lease")
check(profiles.get(p) == nil, "disconnect removes in-memory profile")

profiles, backend = host(false)
p = player(3)
backend.records.Player_3 = { Coins = 400, Session = { Token = "other-server", Expires = os.time() + 100 } }
data = profiles.load(p)
check(p.attributes.SaveStatus == "Session only: profile unavailable", "active foreign lease blocks writable load")
data.Coins = 999
profiles.save(p, true)
check(backend.records.Player_3.Coins == 400, "blocked load never overwrites stored coins")
check(backend.records.Player_3.Session.Token == "other-server", "blocked load preserves foreign session")

profiles, backend = host(false)
p = player(4)
backend.records.Player_4 = { Coins = 220, Session = { Token = "expired", Expires = os.time() - 1 } }
data = profiles.load(p)
check(data.Coins == 220, "expired lease recovers progress")
check(backend.records.Player_4.Session.Token == "test-token-1", "expired lease replaced")

profiles, backend = host(false)
p = player(5)
backend.failures = 3
data = profiles.load(p)
check(backend.calls == 3, "load retry limit")
check(p.attributes.SaveStatus == "Session only: profile unavailable", "failed load marks local session")
data.Coins = 800
profiles.save(p, false)
check(backend.records.Player_5 == nil and backend.calls == 3, "failed load never writes default data")

profiles, backend = host(false)
p = player(6)
data = profiles.load(p)
backend.records.Player_6.Session = { Token = "new-owner", Expires = os.time() + 100 }
data.Coins = 888
check(not profiles.save(p, false), "lost lease cancels autosave")
check(backend.records.Player_6.Coins == 0, "lost lease cannot overwrite another server")

profiles, backend = host(false)
p = player(7)
backend.beforeUpdate = function() p.Parent = nil end
profiles.load(p)
check(backend.records.Player_7.Session == nil, "disconnect racing load releases newly acquired lease")
check(profiles.get(p) == nil, "disconnect race cleans up memory")

profiles, backend = host(false)
p = player(8)
data = profiles.load(p)
data.Coins = 70
backend.failures = 2
check(profiles.save(p, false), "transient autosave recovers")
check(backend.records.Player_8.Coins == 70, "recovered autosave preserves rewards")
profiles, backend = host(false)
p = player(77)
backend.records.Player_77 = { Coins = 720, XP = 100, Wins = 0, Crossings = 0, Owned = { Mint = true }, Equipped = "Mint" }
data = profiles.load(p)
check(data.AuraEquipped == "NoAura" and data.TitleEquipped == "NoTitle" and data.Owned.Mint and data.Coins == 720, "old profiles migrate without losing coins or trails")
local byId = {} for _, definition in ipairs(Config.Cosmetics) do byId[definition.id] = definition end
Rules.purchaseCosmetic(data, byId.RiftSparks, {})
data.Wins = 5
Rules.purchaseCosmetic(data, byId.ValleySurvivor, {})
check(profiles.save(p, true), "cosmetic profile releases cleanly")
data = profiles.load(p)
check(data.Coins == 600 and data.CosmeticOwned.RiftSparks and data.AuraEquipped == "RiftSparks", "purchased aura and remaining coins survive rejoin")
check(data.TitleEquipped == "ValleySurvivor" and data.Wins == 5, "earned title survives rejoin")
data.AuraEquipped, data.CosmeticOwned.RoyalHalo = "RoyalHalo", true
profiles.save(p, true)
data = profiles.load(p)
check(data.AuraEquipped == "RoyalHalo" and not data.CosmeticOwned.RoyalHalo, "paid preference persists but stored flag cannot grant VIP")
for stage=1,5 do Rules.recordCourse(data,Config,"NeonHarbor",stage,8,false) end
Rules.recordCourse(data,Config,"NeonHarbor",3,9,true)
data.Mastery.UnlockedCourse=5
Rules.purchaseCosmetic(data,byId.HarborPhantom,{})
Rules.purchaseCosmetic(data,byId.HarborBurst,{})
local masteryTrail
for _,definition in ipairs(Config.Trails) do if definition.id=="HarborMaster" then masteryTrail=definition end end
Rules.purchase(data,masteryTrail,{})
check(profiles.save(p,true),"mastery progress releases its profile lease cleanly")
data=profiles.load(p)
check(data.Mastery.UnlockedCourse==5 and data.MedalPoints==15 and data.GoldMedals==5,"saved course unlocks and medals survive rejoin")
check(data.Mastery.Races.NeonHarbor_3.bestMs==8000 and data.Mastery.Practice.NeonHarbor_3.bestMs==9000,"race and practice bests persist independently")
check(data.Equipped=="HarborMaster" and data.SkinEquipped=="HarborPhantom" and data.VictoryEquipped=="HarborBurst","earned trail, skin and victory preferences survive rejoin")
print("PASS: " .. passed .. " actual profile-module assertions with simulated DataStore failures")
