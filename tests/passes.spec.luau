-- Actual pass module, with controlled Roblox ownership responses.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local Config = require("../src/shared/Config")
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local function player(id)
	return { UserId = id, Parent = true, attributes = {}, SetAttribute = function(self, key, value) self.attributes[key] = value end }
end
local function host(ids, studio, gameId)
	local callback
	local backend = { calls = 0, owned = {}, fail = false, changes = 0 }
	local services = {
		RunService = { IsStudio = function() return studio end },
		ReplicatedStorage = { WaitForChild = function() return { Config = "config", PassIds = "ids" } end },
		MarketplaceService = {
			PromptGamePassPurchaseFinished = { Connect = function(_, fn) callback = fn end },
			UserOwnsGamePassAsync = function(_, _, id)
				backend.calls += 1
				if backend.duringCheck then local fn = backend.duringCheck backend.duringCheck = nil fn() end
				if backend.fail then error("temporary ownership API failure") end
				return backend.owned[id] == true
			end,
		},
	}
	local env = {
		game = { GameId = gameId, GetService = function(_, name) return services[name] end },
		require = function(name) return name == "config" and Config or ids end,
		task = { spawn = function(fn, ...) fn(...) end, wait = function() end },
	}
	local module = luau.load(fs.readFile("src/server/PassService.luau"), { environment = env })()
	module.init(function() backend.changes += 1 end, function() end)
	backend.purchase = function(...) callback(...) end
	return module, backend
end
local ids = { VIP = 101, DoubleCoins = 102, StylePack = 103 }
local passes, backend = host({}, false, 1)
local p = player(1)
passes.load(p)
check(backend.calls == 0 and not passes.owns(p, "VIP"), "unconfigured IDs never call APIs or grant perks")
passes, backend = host(ids, true, 1)
passes.load(p)
check(backend.calls == 0 and p.attributes.PassStatus_VIP == "Live game only", "Studio never simulates purchases")
passes, backend = host(ids, false, 0)
passes.load(p)
check(backend.calls == 0, "unpublished game never calls ownership API")
passes, backend = host(ids, false, 1)
backend.owned[101] = true
passes.load(p)
check(backend.calls == 3 and passes.owns(p, "VIP"), "join verifies three real pass IDs")
check(not passes.owns(p, "DoubleCoins") and p.attributes.Pass_VIP == true, "only verified entitlements replicated")
backend.purchase(p, 102, false)
check(not passes.owns(p, "DoubleCoins") and backend.calls == 3, "cancelled purchase never grants")
backend.purchase(p, 102, true)
check(not passes.owns(p, "DoubleCoins"), "purchase event alone cannot grant without ownership")
backend.owned[102] = true
backend.purchase(p, 102, true)
check(passes.owns(p, "DoubleCoins") and p.attributes.Pass_DoubleCoins == true, "verified purchase activates immediately")
local before = backend.calls
backend.purchase(p, 999, true)
check(backend.calls == before, "unknown pass cannot trigger checks")
backend.fail = true
passes.refresh(p)
check(passes.owns(p, "VIP") and p.attributes.PassStatus_VIP == "Check unavailable", "transient failure preserves verified entitlement")
before = backend.calls
passes.refresh(p)
check(backend.calls == before, "refresh rate limit")
passes.remove(p)
check(not passes.owns(p, "VIP"), "remove clears session entitlement")
backend.purchase(p, 103, true)
check(backend.calls == before, "departed player purchase ignored")
passes, backend = host(ids, false, 1)
backend.fail = true
passes.load(p)
check(backend.calls == 9 and not passes.owns(p, "VIP"), "three retries per pass fail closed")
passes, backend = host(ids, false, 1)
backend.owned[101] = true
backend.duringCheck = function() passes.remove(p) end
passes.load(p)
check(not passes.owns(p, "VIP"), "late ownership response cannot resurrect departed session")
print("PASS: " .. passed .. " actual game-pass module assertions")
