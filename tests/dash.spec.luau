local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config = require("../src/shared/Config")
local host = require("./native-host")()
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) table.insert(self.callbacks, fn) return {} end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local now, pre, sim = 1000, signal(), signal()
local function instance(class) return host.wrap(r.Instance.new(class)) end
local p, char, root = instance("Player"), instance("Model"), instance("Part")
p.Name, p.Parent = "Dasher", host.wrap(host.model:GetService("Players"))
char.Parent = host.workspace
root.Name, root.CFrame, root.Parent = "HumanoidRootPart", r.CFrame.new(0, 4, 0), char
rawset(p, "Character", char)
p:SetAttribute("Role", "Runner")
local motors, originals = {}, {}
for _, name in ipairs({ "RootJoint", "Left Shoulder", "Right Shoulder", "Neck" }) do
	local child, motor = instance("Part"), instance("Motor6D")
	child.Name, child.CFrame, child.Parent = name .. "Body", root.CFrame, char
	motor.Name, motor.Part0, motor.Part1, motor.Parent = name, root, child, root
	motor.C0 = name == "RootJoint" and r.CFrame.Angles(-math.pi/2, 0, math.pi) or r.CFrame.identity
	motor.Transform = r.CFrame.Angles(.04, 0, 0)
	table.insert(motors, motor)
	originals[motor] = motor.Transform
end
-- Same property contract as upgraded avatars, controlled independently of DOM support.
local constraint = { Name = "Waist", Parent = char, Attachment0 = { WorldCFrame = root.CFrame }, Transform = r.CFrame.identity,
	IsA = function(_, name) return name == "AnimationConstraint" end }
originals[constraint] = constraint.Transform
local descendants = char.GetDescendants
rawset(char, "GetDescendants", function(self)
	local result = descendants(self) table.insert(result, constraint) return result
end)
rawset(host.workspace, "GetServerTimeNow", function() return now end)
rawset(host.workspace, "CurrentCamera", { CFrame = r.CFrame.new(0, 10, 10) })
local env = {
	game = { GetService = function(_, name)
		if name == "RunService" then return { PreAnimation = pre, PreSimulation = sim } end
		return host.replicated
	end }, workspace = host.workspace, require = function() return Config end, Instance = { new = instance },
	Vector3 = r.Vector3, Color3 = r.Color3, CFrame = r.CFrame, Enum = r.Enum,
	ColorSequence = r.ColorSequence, NumberSequence = r.NumberSequence, NumberSequenceKeypoint = r.NumberSequenceKeypoint,
}
luau.load(fs.readFile("src/client/DashEffects.client.luau"), { environment = env })()
local event = host.replicated.RiftAction.OnClientEvent
event:Fire("DashFX", { player = p, direction = r.Vector3.new(0, 0, 1), started = now })
local ribbons, streaks = 0, 0
for _, part in ipairs(root:GetChildren()) do if part:IsA("Trail") then ribbons += 1 check(part.Enabled and part.Lifetime > 0, "wind trail starts") end end
for _, part in ipairs(host.workspace:GetChildren()) do if part.Name == "DashGust" then streaks += 1 check(not part.CanCollide and not part.CanQuery and not part.CanTouch, "gust cannot affect hits or movement") end end
check(ribbons == 6 and streaks == 6, "six wind ribbons and six speed streaks")
now += .06 pre:Fire() sim:Fire()
check(motors[1].Transform ~= originals[motors[1]] and constraint.Transform ~= originals[constraint], "R6 and upgraded avatar joints both pose")
local posed = motors[1].Transform
pre:Fire()
for joint, original in pairs(originals) do check(joint.Transform == original, "restore before Animator") end
sim:Fire()
check(motors[1].Transform == posed, "repeating a frame never accumulates offset")
pre:Fire()
local newAnimation = r.CFrame.Angles(.12, .04, 0)
motors[1].Transform = newAnimation
newAnimation = motors[1].Transform
sim:Fire()
pre:Fire()
check(motors[1].Transform == newAnimation, "latest Animator pose survives restoration")
sim:Fire()
event:Fire("DashCancel", p)
check(motors[1].Transform == newAnimation and not root:FindFirstChild("DashWind") and not host.workspace:FindFirstChild("DashGust"), "teleport cancellation restores poses and deletes wind")
event:Fire("DashFX", { player = p, direction = r.Vector3.new(0, 0, 1), started = now })
now += .1 pre:Fire() sim:Fire()
p:SetAttribute("BeingCaptured", true)
sim:Fire()
check(not root:FindFirstChild("DashWind") and not host.workspace:FindFirstChild("DashGust"), "capture stops wind immediately")
p:SetAttribute("BeingCaptured", false)
event:Fire("DashFX", { player = p, direction = r.Vector3.new(0, 0, 1), started = now })
now += Config.DashDuration + .4 pre:Fire() sim:Fire()
check(not root:FindFirstChild("DashWind") and not host.workspace:FindFirstChild("DashGust"), "natural completion releases all effects")
event:Fire("DashFX", { player = p, direction = r.Vector3.new(0, 0, 1), started = now - 1 })
check(not root:FindFirstChild("DashWind"), "stale events do not replay")
print("PASS: " .. passed .. " actual dash animation, wind, avatar joint compatibility and cleanup assertions")
