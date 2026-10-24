local fs, luau = require("@lune/fs"), require("@lune/luau")
local now, logs = 1000, {}
local m = luau.load(fs.readFile("src/server/PlaytestService.luau"), { environment = {
	os = { clock = function() return now end }, print = function(line) table.insert(logs, line) end,
} })()
local p = { Name = "PrivateName", UserId = 12345 }
m.join(p) m.event(p, "start", 1)
now += 20 m.event(p, "finish", 1) m.stage(p, 2)
assert(m.sample(p, { fps = 45, touch = true }), "valid performance sample")
assert(not m.sample(p, { fps = 100, touch = false }), "duplicate samples rate limited")
now += 16
assert(not m.sample(p, { fps = 0/0, touch = false }) and not m.sample(p, { fps = 300, touch = false }), "invalid sample cannot corrupt metrics")
assert(m.sample(p, { fps = 60, touch = false }), "later desktop sample accepted")
m.event(p, "fall", 2) m.event(p, "catch", 2) m.event(p, "dodge", 2)
m.event(p, "Unknown", 99) m.stage(p, 4) m.leave(p)
local report = m.report("SunsetRuins", 1)
assert(report.totals.firstFinishPlayers == 1 and report.totals.firstFinishSeconds == 20 and report.exits[4] == 1, "funnel timing and departure course retained")
assert(report.falls[2] == 1 and report.catches[2] == 1 and report.totals.dodge == 1, "server records distinct failure and dodge causes")
assert(report.touchFps == 45 and report.desktopFps == 60, "touch and desktop performance stay separate")
for _, line in ipairs(logs) do assert(not line:find(p.Name, 1, true) and not line:find(tostring(p.UserId), 1, true), "reports contain no player identity") end
print("PASS: playtest funnel, failure causes, stage exits, sample validation, device performance and anonymous reports")
