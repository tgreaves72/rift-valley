local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config = require("../src/shared/Config")
local time, events, started, finished = 1000, {}, 0, 0
local allowed, dodged = true, 0
local function part(name, transparency)
	return { Name = name, Parent = true, Transparency = transparency, Anchored = false, attrs = {},
		CFrame = r.CFrame.new(0, 3, 0), Position = r.Vector3.new(0, 3, 0), AssemblyLinearVelocity = r.Vector3.zero,
		IsA = function(_, class) return class == "BasePart" end,
		SetAttribute = function(self, key, value) self.attrs[key] = value end,
	}
end
local root, body = part("HumanoidRootPart", 1), part("Torso", .2)
local victim = { UserId = 4, Parent = true, attrs = {}, Character = { GetDescendants = function() return { root, body } end }, SetAttribute = function(self, key, value) self.attrs[key] = value end }
local actorRoot = part("HumanoidRootPart", 1)
local actor = { Parent = true, attrs = {}, SetAttribute = function(self, key, value) self.attrs[key] = value end }
local remote = { FireAllClients = function(_, action, payload) table.insert(events, { action, payload }) end }
local env = {
	game = { GetService = function() return { WaitForChild = function(_, name) return name == "RiftShared" and { Config = "config" } or remote end } end },
	workspace = { GetServerTimeNow = function() return time end },
	Vector3 = r.Vector3, CFrame = r.CFrame, require = function() return Config end,
}
local captures = luau.load(fs.readFile("src/server/CaptureService.luau"), { environment = env })()
captures.init({ valid = function() return allowed and root or nil end, started = function() started += 1 end, finished = function() finished += 1 end, dodged = function() dodged += 1 end })
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
check(captures.tryGrab(victim, actor, actorRoot, nil), "visible reach begins")
check(not actorRoot.Anchored and captures.winding(actorRoot) and not root.Anchored and not captures.isVictim(victim), "readable windup permits pursuit and leaves runner free to dodge")
check(not captures.tryGrab(victim, actor, actorRoot, nil), "attacker cannot overlap grabs")
local otherRoot = part("OtherRoot", 1)
check(not captures.tryGrab(victim, actor, otherRoot, nil), "two monsters cannot wind up against the same runner")
time += .1
captures.step(time)
check(started == 0 and #events == 1 and events[1][1] == "GrabWarning", "warning broadcasts before any catch")
allowed = false
time += Config.GrabWindup
captures.step(time)
check(not actorRoot.Anchored and started == 0 and not captures.hasActive(), "dodging contact cancels cleanly")
check(dodged == 1 and captures.recovering(actorRoot), "miss triggers a dodge and recovery window")
check(math.abs(actorRoot.CFrame.Position.Z) <= Config.GrabLungeDistance+.001, "lunge travel is bounded")
time += Config.MissRecovery+.1
allowed = true
captures.tryGrab(victim, actor, actorRoot, nil)
time += Config.GrabWindup+.01
captures.step(time)
check(started == 1 and captures.isVictim(victim) and root.Anchored, "contact confirmed after windup")
check(body.Transparency == 1 and body.attrs.CaptureTransparency == .2 and victim.attrs.BeingCaptured, "visibility snapshot supports client whole-avatar visual")
check(events[#events][1] == "Capture" and events[#events][2].duration == Config.CaptureDuration, "authoritative timeline broadcast")
time += 1
captures.step(time)
check(root.CFrame.Position.Y > 5, "server lifts captured root")
time += 1.2
captures.step(time)
check(finished == 1 and body.Transparency == .2 and root.Transparency == 1, "exact visibility restored before conversion")
check(not root.Anchored and not actorRoot.Anchored and not captures.hasActive(), "completion cannot freeze either participant")
check(events[#events][1] == "CaptureEnd" and not victim.attrs.BeingCaptured, "client camera/proxy cleanup notified")
time += 1
captures.tryGrab(victim, actor, actorRoot, nil)
time += Config.GrabWindup+.01
captures.step(time)
captures.cancelAll()
check(not root.Anchored and body.Transparency == .2 and finished == 2, "round cancellation restores captured runner")
time += 1
captures.tryGrab(victim, actor, actorRoot, nil)
time += Config.GrabWindup+.01
captures.step(time)
captures.remove(victim)
check(not root.Anchored and not captures.hasActive() and finished == 3, "disconnect cancels active capture")
time += 1
captures.tryGrab(victim, actor, actorRoot, nil)
actor.Parent = nil
captures.step(time)
check(not actorRoot.Anchored and not captures.hasActive(), "removed attacker releases windup")
actor.Parent = true
local Rules = require("../src/shared/Rules")
local function trajectory(speed, side)
	time += 2
	actorRoot.CFrame, actorRoot.Position = r.CFrame.new(0, 3, 0), r.Vector3.new(0, 3, 0)
	root.Position, root.CFrame = r.Vector3.new(0, 3, -3), r.CFrame.new(0, 3, -3)
	root.AssemblyLinearVelocity = r.Vector3.new(0, 0, -speed)
	captures.init({ valid = function()
		local d = actorRoot.CFrame:PointToObjectSpace(root.Position)
		return Rules.canGrab("Runner", "Crossing", d.X, d.Y, d.Z, time, 0) and root or nil
	end, started = function() end, finished = function() end })
	assert(captures.tryGrab(victim, actor, actorRoot, nil))
	local commit=Config.GrabWindup-Config.GrabLungeSeconds+.001
	local follow = speed == 0 and 0 or math.min(29*commit,3+speed*commit-1.8)
	actorRoot.CFrame, actorRoot.Position = r.CFrame.new(0, 3, -follow), r.Vector3.new(0, 3, -follow)
	root.Position = r.Vector3.new(0, 3, -3-speed*commit)
	time += commit captures.step(time)
	root.Position = r.Vector3.new(side, 3, -3-speed*Config.GrabWindup)
	time += Config.GrabWindup-commit+.001 captures.step(time)
	local caught = captures.isVictim(victim)
	captures.cancelAll()
	return caught
end
check(trajectory(0, 0), "lunge stops short enough to catch a stationary runner without overshooting")
check(trajectory(22, 0), "ordinary forward walking is not an automatic dodge at close contact")
check(not trajectory(34, 0), "sprinting forward can escape the committed short lunge")
check(not trajectory(22, 8), "sideways movement escapes the committed attack")
time+=2
captures.init({valid=function() return root end,started=function() end,finished=function() end})
check(captures.tryGrab(victim,actor,actorRoot,nil),"start a warned grab for the authorized dash interruption")
time+=Config.GrabWindup-.05 captures.step(time)
check(actorRoot.Anchored and captures.evade(victim) and not actorRoot.Anchored and not captures.hasActive(),"dash interrupts even the committed lunge and releases the actor")
check(not captures.evade(victim),"evading without a pending attack has no effect")
time+=2 captures.tryGrab(victim,actor,actorRoot,nil)
time+=Config.GrabWindup+.01 captures.step(time)
check(captures.isVictim(victim) and not captures.evade(victim),"an already confirmed capture cannot be undone")
captures.cancelAll()
print("PASS: " .. passed .. " actual capture timeline, dodge, restoration and cancellation assertions")
