local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local host = require("./native-host")()
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) table.insert(self.callbacks, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local p, pg = host.wrap(r.Instance.new("Player")), host.wrap(r.Instance.new("PlayerGui"))
pg.Name, pg.Parent = "PlayerGui", p
p:SetAttribute("Role", "Spectator")
local target = host.workspace.RiftLobby.VIPInterior.StyleMirror
local root = { Position = target.Position }
rawset(p, "Character", { FindFirstChild = function() return root end })
local frames = signal()
local clicked = 0
local prompt = target:FindFirstChildOfClass("ProximityPrompt")
rawset(prompt, "InputHoldBegin", function() clicked += 1 end)
rawset(prompt, "InputHoldEnd", function() end)
local env = {
	workspace = host.workspace,
	game = { GetService = function(_, name)
		if name == "Players" then return { LocalPlayer = p } end
		if name == "RunService" then return { RenderStepped = frames } end
		return { TouchEnabled = true, GamepadEnabled = false }
	end },
	Instance = { new = function(class) return host.wrap(r.Instance.new(class)) end },
	UDim = r.UDim, UDim2 = r.UDim2, Enum = r.Enum, Color3 = r.Color3, Vector3 = r.Vector3,
	task = { defer = function(fn, ...) fn(...) end },
}
luau.load(fs.readFile("src/client/HoverIcons.client.luau"), { environment = env })()
frames:Fire()
local vendorGui,count=nil,0
for _,gui in ipairs(pg:GetChildren()) do
    count+=1
    assert(not gui.Adornee.HoverIcon:FindFirstChild("Kind"),"resource buffs never create a billboard or label")
    assert(not gui.Adornee.HoverIcon:FindFirstChild("NativeVisual"), "native shop/VIP sculptures never create a flat glyph button")
    if gui.Adornee==target then vendorGui=gui end
end
assert(count==2 and vendorGui.Active and vendorGui.Enabled,"only wardrobe and lounge exit retain hover buttons; activities have solid 3D emblems")
local button
for _, obj in ipairs(vendorGui:GetChildren()) do if obj:IsA("TextButton") then button = obj end end
button.Activated:Fire()
assert(clicked == 1 and button.Active, "nearby tap invokes instant prompt")
root.Position = r.Vector3.new(0, 32, 224)
frames:Fire()
assert(not button.Active, "distant icons cannot invoke interactions")
root.Position = target.Position
p:SetAttribute("Role", "Runner")
frames:Fire()
assert(not button.Active, "arena roles cannot use lobby interactions")
print("PASS: actual hovering icon UI, touch input, distance and role gating")
