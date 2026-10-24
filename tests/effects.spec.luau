local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local host = require("./native-host")()
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) table.insert(self.callbacks, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local p = host.wrap(r.Instance.new("Player"))
rawset(p, "UserId", 4)
local char = host.wrap(r.Instance.new("Model"))
char.Name, char.Parent = "Victim", host.workspace
local root = host.wrap(r.Instance.new("Part"))
root.Name, root.CFrame, root.Parent = "HumanoidRootPart", r.CFrame.new(0, 3, -3), char
local body = host.wrap(r.Instance.new("Part"))
body.Name, body.Size, body.CFrame, body.Parent = "Torso", r.Vector3.new(2, 2, 1), root.CFrame, char
local humanoid = host.wrap(r.Instance.new("Humanoid"))
humanoid.Parent = char
rawset(p, "Character", char)
local camera = { CameraType = r.Enum.CameraType.Custom, CameraSubject = humanoid, FieldOfView = 72 }
rawset(host.workspace, "CurrentCamera", camera)
local time = 1000
rawset(host.workspace, "GetServerTimeNow", function() return time end)
local actor = host.wrap(r.Instance.new("Model"))
actor.Name, actor.Parent = "Actor", host.workspace
for _, name in ipairs({ "HumanoidRootPart", "Head", "Mouth", "LowerJaw", "Tongue" }) do
	local part = host.wrap(r.Instance.new("Part"))
	part.Name, part.CFrame, part.Parent = name, r.CFrame.new(0, name == "Head" and 5 or 3, 0), actor
	if name == "HumanoidRootPart" then actor.PrimaryPart = part end
end
local remote, rendered = { OnClientEvent = signal() }, signal()
local env = { game = { GetService = function(_, name)
	if name == "Players" then return { LocalPlayer = p } end
	if name == "RunService" then return { RenderStepped = rendered } end
	return { WaitForChild = function() return remote end }
end }, workspace = host.workspace, Vector3 = r.Vector3, CFrame = r.CFrame, Enum = r.Enum }
luau.load(fs.readFile("src/client/CaptureEffects.client.luau"), { environment = env })()
local mouthSize = actor.Mouth.Size
remote.OnClientEvent:Fire("Capture", { victim = p, model = actor, started = time, duration = 2.1 })
assert(host.workspace:FindFirstChild("LocalCaptureVictim") and camera.CameraType == r.Enum.CameraType.Scriptable, "capture proxy and victim camera begin")
time += 1.5
rendered:Fire()
local proxy = host.workspace:FindFirstChild("LocalCaptureVictim")
assert(proxy.Torso.Size.X < 2 and actor.Mouth.Size.Y > 4, "whole avatar shrinks into opened mouth")
time += .4
rendered:Fire()
assert(proxy.Torso.Transparency == 1, "whole avatar disappears at swallow completion")
remote.OnClientEvent:Fire("CaptureEnd", p.UserId)
assert(not host.workspace:FindFirstChild("LocalCaptureVictim") and camera.CameraType == r.Enum.CameraType.Custom and camera.FieldOfView == 72, "proxy and camera restored")
assert((actor.Mouth.Size - mouthSize).Magnitude < .00001, "mouth dimensions restored within native float precision")
print("PASS: actual capture visual, whole-avatar shrink, camera takeover and cleanup")
