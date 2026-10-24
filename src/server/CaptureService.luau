local Replicated = game:GetService("ReplicatedStorage")
local Config = require(Replicated:WaitForChild("RiftShared").Config)
local Remote = Replicated:WaitForChild("RiftAction")
local Capture = {}
local records, victims, cooldowns = {}, {}, setmetatable({}, { __mode = "k" })
local attempts = {}
local handlers

local function anchor(root)
	local original = root.Anchored
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	return original
end

local function cleanup(record, completed)
	records[record.actorRoot] = nil
	attempts[record.victim] = nil
	if record.actorRoot.Parent then record.actorRoot.Anchored = record.actorAnchored end
	if record.actorRoot.Parent and not record.actorAnchored and not record.actorPlayer then pcall(function() record.actorRoot:SetNetworkOwner(nil) end) end
	local now = workspace:GetServerTimeNow()
	Remote:FireAllClients("WarningEnd",record.model)
	if record.model.Parent then
		record.model:SetAttribute("GrabStage", nil)
		record.model:SetAttribute("RecoverUntil", now + (record.captured and .7 or Config.MissRecovery))
	end
	cooldowns[record.actorRoot] = now + (record.captured and .7 or Config.MissRecovery)
	if not record.captured then
		if completed and handlers.dodged then handlers.dodged(record.victim) end
		return
	end
	victims[record.victim] = nil
	for part, value in pairs(record.visibility) do
		if part.Parent then part.Transparency = value part:SetAttribute("CaptureTransparency", nil) end
	end
	if record.victimRoot.Parent then record.victimRoot.Anchored = record.victimAnchored end
	record.victim:SetAttribute("BeingCaptured", false)
	Remote:FireAllClients("CaptureEnd", record.victim.UserId)
	handlers.finished(record.victim, completed)
end

function Capture.init(callbacks) handlers = callbacks end
function Capture.busy(root) return records[root] ~= nil end
function Capture.winding(root) local record = records[root] return record ~= nil and not record.captured and not record.lungeFrame end
function Capture.recovering(root) return workspace:GetServerTimeNow() < (cooldowns[root] or 0) end
function Capture.hasActive() return next(records) ~= nil end
function Capture.isVictim(player) return victims[player] ~= nil end

function Capture.evade(player)
	local record=attempts[player]
	if not record or record.captured then return false end
	cleanup(record,true)
	return true
end

function Capture.tryGrab(victim, actorModel, actorRoot, actorPlayer)
	local now = workspace:GetServerTimeNow()
	if records[actorRoot] or attempts[victim] or victims[victim] or now < (cooldowns[actorRoot] or 0) then return false end
	local root = handlers.valid(victim, actorRoot, actorPlayer)
	if not root or not actorModel or not actorModel.Parent then return false end
	local record = { victim = victim, model = actorModel, actorRoot = actorRoot, actorPlayer = actorPlayer,
		victimRoot = root, began = now, captured = false, actorFrame = actorRoot.CFrame, actorAnchored = actorRoot.Anchored }
	records[actorRoot] = record
	attempts[victim] = record
	actorModel:SetAttribute("GrabStage", "Reach")
	actorModel:SetAttribute("GrabStartedAt", now)
	Remote:FireAllClients("GrabWarning", { victim = victim, model = actorModel, duration = Config.GrabWindup })
	return true
end

function Capture.step(now)
	for actorRoot, record in pairs(records) do
		if not actorRoot.Parent or not record.model.Parent or not record.victim.Parent or not record.victimRoot.Parent then cleanup(record, false) continue end
		if not record.captured then
			-- Pursue during the readable reach, then commit to a short fixed lunge.
			local lungeSeconds = math.min(Config.GrabLungeSeconds,Config.GrabWindup)
			local lunge = math.clamp((now-record.began-Config.GrabWindup+lungeSeconds)/lungeSeconds, 0, 1)
			if lunge > 0 then
				if not record.lungeFrame then
					record.lungeFrame = actorRoot.CFrame
					local ahead = (record.victimRoot.Position-actorRoot.Position):Dot(actorRoot.CFrame.LookVector)
					local forwardSpeed = math.max(0, record.victimRoot.AssemblyLinearVelocity:Dot(actorRoot.CFrame.LookVector))
					record.lungeDistance = math.clamp(ahead-1.8+forwardSpeed*lungeSeconds, 0, Config.GrabLungeDistance)
					anchor(actorRoot)
				end
				local target = record.lungeFrame + record.lungeFrame.LookVector * (lunge * record.lungeDistance)
				if not handlers.canLunge or handlers.canLunge(actorRoot.Position, target.Position) then actorRoot.CFrame = target end
			end
			if now - record.began < Config.GrabWindup then continue end
			local root = handlers.valid(record.victim, actorRoot, record.actorPlayer)
			if not root or victims[record.victim] then cleanup(record, true) continue end
			record.captured, record.started = true, now
			record.victimRoot, record.victimAnchored = root, anchor(root)
			victims[record.victim] = record
			record.visibility = {}
			for _, part in ipairs(record.victim.Character:GetDescendants()) do
				if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
					record.visibility[part] = part.Transparency
					part:SetAttribute("CaptureTransparency", part.Transparency)
					part.Transparency = 1
				end
			end
			record.model:SetAttribute("GrabStage", "Consume")
			record.model:SetAttribute("GrabStartedAt", now)
			record.victim:SetAttribute("BeingCaptured", true)
			handlers.started(record.victim, record.actorPlayer)
			Remote:FireAllClients("Capture", { victim = record.victim, model = record.model, started = now, duration = Config.CaptureDuration })
		end
		local elapsed = now - record.started
		local lift = math.clamp(elapsed / 1.05, 0, 1)
		record.victimRoot.CFrame = actorRoot.CFrame * CFrame.new(0, 2.5 * lift, -3 + .9 * lift)
		if elapsed >= Config.CaptureDuration then cleanup(record, true) end
	end
end

function Capture.cancelAll()
	local list = {}
	for _, record in pairs(records) do table.insert(list, record) end
	for _, record in ipairs(list) do cleanup(record, false) end
end
function Capture.remove(player)
	local list = {}
	for _, record in pairs(records) do if record.victim == player or record.actorPlayer == player then table.insert(list, record) end end
	for _, record in ipairs(list) do cleanup(record, false) end
end
function Capture.cancelActor(root)
	local record = records[root]
	if record then cleanup(record, false) end
end
return Capture
