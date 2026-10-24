local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Config = require(Shared.Config)
local Ids = require(Shared.PassIds)
local Passes = {}
local entries = {}
local changed, notice

function Passes.owns(player, key)
	local entry = entries[player]
	return entry ~= nil and entry.owned[key] == true
end

function Passes.entitlements(player)
	local entry = entries[player]
	return entry and entry.owned or {}
end

local function check(player, key)
	local entry = entries[player]
	local id = Ids[key]
	if not entry or entry.busy[key] or type(id) ~= "number" or id <= 0 or RunService:IsStudio() or game.GameId == 0 then return end
	entry.busy[key] = true
	local ok, owned = false, false
	for attempt = 1, 3 do
		ok, owned = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id) end)
		if ok or entries[player] ~= entry then break end
		task.wait(attempt)
	end
	entry.busy[key] = nil
	if entries[player] ~= entry or not player.Parent then return end
	if ok then
		local newlyOwned = owned == true and entry.owned[key] ~= true
		entry.owned[key] = owned == true
		player:SetAttribute("Pass_" .. key, owned == true)
		player:SetAttribute("PassStatus_" .. key, "Ready")
		if changed then changed(player) end
		if newlyOwned and notice then notice(player, "Game pass activated! Your perks are ready.") end
	else
		player:SetAttribute("PassStatus_" .. key, "Check unavailable")
		if notice then notice(player, "Could not check game passes. Reopen Passes to retry.") end
	end
end

function Passes.load(player)
	entries[player] = { owned = {}, busy = {}, refreshedAt = -100 }
	for _, pass in ipairs(Config.Passes) do
		player:SetAttribute("Pass_" .. pass.key, false)
		player:SetAttribute("PassStatus_" .. pass.key, Ids[pass.key] and "Checking" or "Not configured")
		if Ids[pass.key] and (RunService:IsStudio() or game.GameId == 0) then player:SetAttribute("PassStatus_" .. pass.key, "Live game only") end
	end
	task.spawn(function() for _, pass in ipairs(Config.Passes) do check(player, pass.key) end end)
end

function Passes.refresh(player)
	local entry = entries[player]
	if not entry or os.clock() - entry.refreshedAt < 10 then return end
	entry.refreshedAt = os.clock()
	task.spawn(function() for _, pass in ipairs(Config.Passes) do check(player, pass.key) end end)
end

function Passes.remove(player)
	entries[player] = nil
end

function Passes.init(onChanged, onNotice)
	changed, notice = onChanged, onNotice
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
		if purchased ~= true or not entries[player] then return end
		for _, pass in ipairs(Config.Passes) do
			if Ids[pass.key] == id then task.spawn(check, player, pass.key) return end
		end
	end)
end

return Passes
