local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)
-- A local, unpublished place cannot even create a DataStore handle.
-- Acquire it only inside the guarded live load path, after the Studio check.
local Store = nil
local Profiles = {}
local entries = {}
local leaseSeconds = 180

local function key(player) return "Player_" .. player.UserId end

function Profiles.load(player)
	local token = HttpService:GenerateGUID(false)
	local entry = { data = Rules.sanitizeProfile(nil, Config.Trails, Config.Cosmetics), token = token, writable = false, busy = false }
	entries[player] = entry
	if RunService:IsStudio() or game.GameId == 0 then
		player:SetAttribute("SaveStatus", "Studio session")
		entry.writable = false
		return entry.data
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			if not Store then Store = DataStoreService:GetDataStore(Config.DataStoreName) end
			return Store:UpdateAsync(key(player), function(old)
				old = type(old) == "table" and old or {}
				local lock = old.Session
				if type(lock) == "table" and lock.Token ~= token and type(lock.Expires) == "number" and lock.Expires > os.time() then
					return nil
				end
				local data = Rules.sanitizeProfile(old, Config.Trails, Config.Cosmetics)
				data.Session = { Token = token, Expires = os.time() + leaseSeconds }
				return data
			end)
		end)
		if ok and result and result.Session and result.Session.Token == token then
			entry.data = Rules.sanitizeProfile(result, Config.Trails, Config.Cosmetics)
			entry.writable = true
			if not player.Parent then
				-- A disconnect can race a yielding load. Release a lease acquired after removal.
				entries[player] = entry
				Profiles.save(player, true)
				return entry.data
			end
			player:SetAttribute("SaveStatus", "Saved")
			return entry.data
		end
		if ok and result == nil then break end
		task.wait(attempt)
	end
	-- Keep the stored profile untouched if loading fails or another server owns it.
	player:SetAttribute("SaveStatus", "Session only: profile unavailable")
	return entry.data
end

function Profiles.get(player)
	local entry = entries[player]
	return entry and entry.data
end

function Profiles.save(player, release)
	local entry = entries[player]
	if not entry then return true end
	if entry.busy then
		local deadline = os.clock() + 12
		repeat task.wait(0.1) until not entry.busy or os.clock() > deadline
		if entry.busy then return false end
	end
	if not entry.writable then
		if release then entries[player] = nil end
		return true
	end
	entry.busy = true
	local snapshot = Rules.sanitizeProfile(entry.data, Config.Trails, Config.Cosmetics)
	local success = false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return Store:UpdateAsync(key(player), function(old)
				if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Token ~= entry.token then return nil end
				local nextData = table.clone(snapshot)
				if not release then
					nextData.Session = { Token = entry.token, Expires = os.time() + leaseSeconds }
				end
				return nextData
			end)
		end)
		if ok and result then success = true break end
		if ok and result == nil then
			entry.writable = false
			break
		end
		task.wait(attempt)
	end
	entry.busy = false
	if player.Parent then player:SetAttribute("SaveStatus", success and "Saved" or "Save delayed") end
	if release then entries[player] = nil end
	return success
end

return Profiles
