-- Aggregate local playtest evidence. Reports contain no names or user IDs and
-- stay in server Output. Human playtests still supply the actual observations.
local Metrics = {}
local people = {}
local totals, falls, catches, exits = {}, {}, {}, {}
local allowed = { join = true, start = true, finish = true, fall = true, catch = true, dodge = true, dash = true, retry = true, complete = true }
local fpsSum, fpsSamples, touchSamples, touchFps = 0, 0, 0, 0
function Metrics.join(player) people[player] = { joined = os.clock(), stage = 0, sampledAt = -100 } Metrics.event(player, "join", 0) end
function Metrics.stage(player, stage) if people[player] then people[player].stage = stage end end
function Metrics.event(player, name, stage)
	if not allowed[name] then return end
	totals[name] = (totals[name] or 0)+1
	local person = people[player]
	if person then person.stage = stage or person.stage end
	if name == "fall" then falls[stage] = (falls[stage] or 0)+1 end
	if name == "catch" then catches[stage] = (catches[stage] or 0)+1 end
	if name == "finish" and stage == 1 and person and not person.firstFinish then
		person.firstFinish = os.clock()-person.joined
		totals.firstFinishSeconds = (totals.firstFinishSeconds or 0)+person.firstFinish
		totals.firstFinishPlayers = (totals.firstFinishPlayers or 0)+1
	end
end
function Metrics.sample(player, payload)
	local person = people[player]
	if not person or type(payload) ~= "table" or os.clock()-person.sampledAt < 15 then return false end
	local fps = payload.fps
	if type(fps) ~= "number" or fps ~= fps or fps < 1 or fps > 240 or type(payload.touch) ~= "boolean" then return false end
	person.sampledAt = os.clock()
	fpsSum, fpsSamples = fpsSum+fps, fpsSamples+1
	if payload.touch then touchSamples += 1 touchFps += fps end
	return true
end
function Metrics.leave(player)
	local person = people[player]
	if person then exits[person.stage] = (exits[person.stage] or 0)+1 people[player] = nil end
end
function Metrics.snapshot() return { totals = table.clone(totals), falls = table.clone(falls), catches = table.clone(catches), exits = table.clone(exits), fps = fpsSamples > 0 and fpsSum/fpsSamples or 0, samples = fpsSamples, touchSamples = touchSamples,
	touchFps = touchSamples > 0 and touchFps/touchSamples or 0, desktopFps = fpsSamples > touchSamples and (fpsSum-touchFps)/(fpsSamples-touchSamples) or 0 } end
function Metrics.report(mapId, round)
	local report = Metrics.snapshot()
	local stages = {}
	for stage = 0, 5 do table.insert(stages, string.format("%d:falls=%d,catches=%d,exits=%d", stage, falls[stage] or 0, catches[stage] or 0, exits[stage] or 0)) end
	print(string.format("[RiftPlaytest] map=%s round=%d starts=%d finishes=%d escapes=%d retries=%d dodges=%d fps=%.1f samples=%d touch=%d", tostring(mapId), round, totals.start or 0, totals.finish or 0, totals.complete or 0, totals.retry or 0, totals.dodge or 0, report.fps, fpsSamples, touchSamples))
	print("[RiftPlaytest] " .. table.concat(stages, " | "))
	print(string.format("[RiftPlaytest] first-course=%.1fs first-finishes=%d touch-fps=%.1f desktop-fps=%.1f (client-reported samples)", (totals.firstFinishSeconds or 0)/math.max(1, totals.firstFinishPlayers or 0), totals.firstFinishPlayers or 0, report.touchFps, report.desktopFps))
	return report
end
return Metrics
