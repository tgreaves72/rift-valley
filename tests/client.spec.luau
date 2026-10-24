-- Execute the actual client UI against scene-backed instances and controlled services.
local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local host = require("./native-host")()
local Config, Ids = require("../src/shared/Config"), require("../src/shared/PassIds")
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn) table.insert(self.callbacks, fn) return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
	return s
end
local p = host.wrap(r.Instance.new("Player"))
local pg = host.wrap(r.Instance.new("PlayerGui"))
pg.Name, pg.Parent = "PlayerGui", p
rawset(p, "Character", nil)
local remote = host.replicated.RiftAction
rawset(remote, "FireServer", function() end)
local rendered, scheduled = signal(), {}
local camera = { ViewportSize = r.Vector2.new(1280, 720), FieldOfView = 72, GetPropertyChangedSignal = function() return signal() end }
rawset(host.workspace, "CurrentCamera", camera)
rawset(host.workspace, "GetServerTimeNow", function() return 1000 end)
local services = {
	Players = { LocalPlayer = p, GetPlayers = function() return {} end }, ReplicatedStorage = host.replicated,
	RunService = { IsStudio = function() return true end, RenderStepped = rendered },
	ContextActionService = { BindAction = function() end, SetTitle = function() end, SetPosition = function() end },
	UserInputService = { TouchEnabled = false, GamepadEnabled = false, WindowFocusReleased = signal() },
	TweenService = { Create = function() return { Play = function() end } end },
	MarketplaceService = { PromptGamePassPurchaseFinished = signal() }, Debris = { AddItem = function() end },
}
local env = {
	game = { GameId = 0, GetService = function(_, name) assert(services[name], name) return services[name] end },
	workspace = host.workspace, Instance = { new = function(class) return host.wrap(r.Instance.new(class)) end },
	Vector2 = r.Vector2, Vector3 = r.Vector3, Color3 = r.Color3, UDim = r.UDim, UDim2 = r.UDim2, CFrame = r.CFrame, Enum = r.Enum,
	Random = { new = function() return {} end },
	TweenInfo = { new = function() return {} end },
	require = function(module) return module.Name == "Config" and Config or Ids end,
	task = { delay = function(_, fn) table.insert(scheduled, fn) end, spawn = function(fn, ...) fn(...) end },
}
luau.load(fs.readFile("src/client/Controller.client.luau"), { environment = env })()
local gui = pg.RiftHUD
assert(gui.Match.Status.Text == "Loading..." and gui.Match.Status.Font == r.Enum.Font.FredokaOne, "bubbly HUD initializes")
assert(not gui.Help.Visible and #scheduled == 0, "rules never interrupt play automatically")
assert(gui.Help.Heading.Text == "Run to Finish!" and gui.Help.Rules.Text == "Dodge chasers. Jump gaps!", "help contains only basic rules")
assert(gui.Shop.Passes.VIPTagline and gui.Shop.Trails.Aurora, "real pass cards and premium trail rows exist")
local buttons = 0
for _, child in ipairs(gui.Shop.Passes:GetChildren()) do
	if child:IsA("TextButton") then
		buttons += 1
		local expected = Ids[Config.Passes[buttons].key] and "LIVE GAME ONLY" or "COMING SOON"
		assert(child.Text == expected and not child.Active, "Studio cannot open purchases, including configured passes")
	end
end
assert(buttons == 3 and gui.MapVote.CrystalGrove, "three passes and map vote UI")
host.replicated:SetAttribute("Phase", "Intermission")
host.replicated:SetAttribute("MapName", "Crystal Grove")
host.replicated:SetAttribute("Deadline", 1015)
p:SetAttribute("Role", "Spectator")
host.replicated:SetAttribute("VotingOpen", true)
rendered:Fire(.016)
local vipRequests = 0
rawset(remote, "FireServer", function(_, action) if action == "VisitVIP" then vipRequests += 1 end end)
gui.Menu.VIPButton.Activated:Fire()
assert(vipRequests == 1 and not gui.Shop.Visible, "VIP sidebar requests server authorization without opening or granting lounge locally")
remote.OnClientEvent:Fire("OpenPasses")
assert(gui.Shop.Visible and gui.Shop.Passes.Visible, "non-owner VIP response opens the pass catalog")
gui.Menu.ShopButton.Activated:Fire()
assert(gui.VoteTally.Visible and gui.VoteTally.CrystalGrove.Count.Text == "0", "shared voting opens a quiet side tally")
for id, votes in pairs({CrystalGrove=3,SunsetRuins=5,NeonHarbor=2}) do
	host.replicated:SetAttribute("Votes_"..id, votes)
	host.replicated:GetAttributeChangedSignal("Votes_"..id):Fire()
end
p:SetAttribute("MapVote", "SunsetRuins") p:GetAttributeChangedSignal("MapVote"):Fire()
assert(gui.VoteTally.CrystalGrove.Count.Text == "3" and gui.VoteTally.SunsetRuins.Count.Text == "5" and gui.VoteTally.NeonHarbor.Count.Text == "2", "replicated totals update every map without opening the menu")
assert(gui.VoteTally.SunsetRuins.Choice.Visible and not gui.VoteTally.CrystalGrove.Choice.Visible, "side tally distinguishes the player's current vote")
host.replicated:SetAttribute("VotingOpen", false) rendered:Fire(.016)
assert(not gui.VoteTally.Visible, "closed voting hides the side tally")
host.replicated:SetAttribute("VotingOpen", true) rendered:Fire(.016)
assert(gui.Match.Timer.Text == "15" and gui.Match.Status.Text == "Next Run!" and gui.Match.Detail.Text == "", "minimal countdown without repeated map copy")
assert(gui.StarterGoal.Visible and gui.StarterGoal.Progress.Text == "0 / 3", "lobby shows the attainable first cosmetic goal")
local retryRequests=0
rawset(remote,"FireServer",function(_,action) if action=="ParkourRetry" then retryRequests+=1 end end)
p:SetAttribute("ParkourRetryAvailable",true) rendered:Fire(.016)
assert(gui.ParkourRetryButton.Visible and gui.ParkourRetryButton.Text=="Retry Parkour","a fall offers one compact retry action")
gui.ParkourRetryButton.Activated:Fire()
assert(retryRequests==1,"retry requests a server teleport instead of moving the avatar locally")
p:SetAttribute("ParkourRetryPending",true) rendered:Fire(.016)
assert(not gui.ParkourRetryButton.Active and gui.ParkourRetryButton.Text=="Respawning...","retry queued during death explains the wait")
p:SetAttribute("ParkourRetryPending",false) p:SetAttribute("ParkourRetryAvailable",false) rendered:Fire(.016)
host.replicated:SetAttribute("Phase", "Results")
host.replicated:SetAttribute("Practice", true)
rendered:Fire(.016)
assert(gui.RetryButton.Visible and gui.LobbyButton.Visible and not gui.StarterGoal.Visible, "solo results offer replay and a lobby break")
p:SetAttribute("SoloPaused", true)
host.replicated:SetAttribute("Phase", "Intermission")
rendered:Fire(.016)
assert(gui.RetryButton.Visible and gui.RetryButton.Text == "Play!" and not gui.LobbyButton.Visible, "paused solo lobby has a clear resume button")
p:SetAttribute("SoloPaused", false)
host.replicated:SetAttribute("Practice", false)
p:SetAttribute("ParkourActive", true)
p:SetAttribute("ParkourCheckpoint", 3)
p:SetAttribute("ParkourStartedAt", 996)
rendered:Fire(.016)
assert(gui.Movement.Role.Text == "Parkour 3 / 24" and gui.Movement.Controls.Text:find("4.0s"), "extended parkour progress and server timer shown")
p:SetAttribute("ParkourActive", false)
rendered:Fire(.016)
assert(gui.Movement.Role.Text == "Dash Ready!" and gui.Movement.Controls.Text:find("Shift"), "parkour exit restores short controls")
camera.ViewportSize = r.Vector2.new(568, 320)
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
assert(gui.Shop:FindFirstChildOfClass("UIScale").Scale < .65, "shop scales to short touch screens")
remote.OnClientEvent:Fire("OpenPasses")
assert(gui.Shop.Visible and gui.Shop.Passes.Visible and not gui.Shop.Trails.Visible, "vendor opens passes tab")
host.replicated:SetAttribute("Phase", "Ready")
p:SetAttribute("Role", "Runner")
rendered:Fire(.016)
assert(not gui.Shop.Visible and not gui.MapVote.Visible and not gui.Menu.Visible, "chase clears obstructing menus")
assert(not gui.VoteTally.Visible, "race start clears the lobby tally")
host.replicated:SetAttribute("Phase", "Crossing")
p:SetAttribute("CourseStage", 1)
local trainingRoot = { Position = r.Vector3.new(0, 4, -140) }
rawset(p, "Character", { FindFirstChild = function() return trainingRoot end })
rendered:Fire(.016)
assert(gui.Movement.Controls.Text == "Hold Shift to Sprint!", "first encounter teaches sprint in context")
p:SetAttribute("SprintLearned", true)
trainingRoot.Position = r.Vector3.new(0, 4, -90)
rendered:Fire(.016)
assert(gui.Movement.Controls.Text == "Press Q to Dash!", "next encounter teaches dash in context")
p:SetAttribute("DashLearned", true)
rawset(p, "Character", nil)
p:SetAttribute("CourseStage", 3)
host.replicated:SetAttribute("Phase", "Crossing")
host.replicated:SetAttribute("Chasers_3", 4)
rendered:Fire(.016)
assert(gui.Match.Detail.Text == "3 / 5" and gui.Match.Status.Text == "Run to Finish!", "chase HUD uses short objective and course count")
for _, message in ipairs({"Next Course!", "Energy!", "Dash Ready!", "Nice Dodge!", "Shortcut Bonus!", "+8 Coins", "Checkpoint!"}) do
	remote.OnClientEvent:Fire("Notice", message)
end
remote.OnClientEvent:Fire("ScoutUnlocked")
assert(not gui.Notice.Visible, "bonus transitions, pickups and in-run unlocks never cover the route")
remote.OnClientEvent:Fire("Notice", "Reach this course in a run first!")
assert(gui.Notice.Visible and gui.Notice.Text.Text == "Reach this course in a run first!", "action failures still reach the player")
assert(gui.Notice.Size.X.Offset == 240 and gui.Notice.Size.Y.Offset == 40 and gui.Notice.Text.TextSize <= 15, "important notices use the compact capsule")
scheduled[#scheduled]()
assert(not gui.Notice.Visible, "compact notice dismisses normally")
assert(gui.Match.CourseDot1.BackgroundColor3 ~= gui.Match.CourseDot3.BackgroundColor3 and gui.Match.CourseDot4.BackgroundTransparency > .5, "course dots distinguish completed, current and remaining")
assert((host.workspace.LocalGoal.Position - r.Vector3.new(-230, 2, 144)).Magnitude < .001, "goal beacon follows current course")
local exportHud = require("./hud-preview")
camera.ViewportSize = r.Vector2.new(1280, 720)
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
assert(not gui.Menu.Visible, "resizing during a chase does not reopen menus")
exportHud(gui, 1280, 720, "assets/hud-desktop-layout.json")
camera.ViewportSize = r.Vector2.new(390, 844)
services.UserInputService.TouchEnabled = true
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
rendered:Fire(.016)
assert(gui.Match.Size.X.Offset <= 366 and gui.Match.Position.X.Offset == -153, "objective fits a portrait phone")
assert(gui.Movement.Controls.Text == "Tap Dash  /  Hold Sprint", "phone shows touch controls")
exportHud(gui, 390, 844, "assets/hud-phone-layout.json")
p:SetAttribute("Role", "Spectator")
host.replicated:SetAttribute("Phase", "Intermission")
rendered:Fire(.016)
exportHud(gui, 390, 844, "assets/hud-lobby-layout.json")
assert(gui.VoteTally.Visible and 390+gui.VoteTally.Position.X.Offset-gui.VoteTally.Size.X.Offset > gui.Resources.Position.X.Offset+gui.Resources.Size.X.Offset, "portrait tally clears the coins and lobby menu")
camera.ViewportSize = r.Vector2.new(1280, 720)
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
exportHud(gui, 1280, 720, "assets/hud-vote-desktop-layout.json")
camera.ViewportSize = r.Vector2.new(568, 320)
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
assert(gui.VoteTally:FindFirstChildOfClass("UIScale").Scale <= .82, "landscape tally leaves room for touch controls")
assert(gui.Menu.Position.Y.Offset+gui.Menu.Size.Y.Offset <= 320, "all five side buttons fit a short landscape phone")
assert(gui.Menu.VIPButton.Size.Y.Offset >= 42 and gui.Menu.VIPButton.Position.X.Offset > gui.Menu.ShopButton.Position.X.Offset, "landscape keeps shop and VIP as separate touch targets")
exportHud(gui, 568, 320, "assets/hud-vote-landscape-layout.json")
camera.ViewportSize = r.Vector2.new(320, 568)
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
local tallyWidth = gui.VoteTally.Size.X.Offset*gui.VoteTally:FindFirstChildOfClass("UIScale").Scale
assert(320+gui.VoteTally.Position.X.Offset-tallyWidth > gui.Menu.Position.X.Offset+gui.Menu.Size.X.Offset and gui.VoteTally.Position.Y.Offset >= gui.Resources.Position.Y.Offset+gui.Resources.Size.Y.Offset, "small-phone tally clears both coins and menu")
assert(gui.Menu.HelpButton.Position.Y.Offset+gui.Menu.HelpButton.Size.Y.Offset <= gui.Menu.Size.Y.Offset, "portrait menu includes all five buttons")
exportHud(gui, 320, 568, "assets/hud-vote-smallphone-layout.json")
camera.ViewportSize = r.Vector2.new(390, 844)
host.workspace:GetPropertyChangedSignal("CurrentCamera"):Fire()
gui.Menu.HelpButton.Activated:Fire()
rendered:Fire(.016)
assert(gui.Help.Visible, "short rules remain available on request")
assert(not gui.VoteTally.Visible, "opened menus keep the tally out of the way")
exportHud(gui, 390, 844, "assets/hud-help-layout.json")
gui.Menu.HelpButton.Activated:Fire()
p:SetAttribute("Role", "Runner")
host.replicated:SetAttribute("Phase", "Crossing")
p:SetAttribute("Role", "Escaped")
rendered:Fire(.016)
assert(gui.Match.Status.Text == "You Made It!", "final escape shows short safe completion")
assert(gui.Menu.Visible, "escaped players can use the lobby while the remaining runners play")
local cosmeticRequests = {}
rawset(remote, "FireServer", function(_, action, id) if action == "Cosmetic" then table.insert(cosmeticRequests, id) end end)
remote.OnClientEvent:Fire("OpenCosmetics")
assert(gui.Shop.Visible and gui.Shop.Cosmetics.Visible and not gui.Shop.Trails.Visible and not gui.Shop.Passes.Visible, "wardrobe opens earned collection")
assert(not gui.Shop.Cosmetics.RiftSparksAction.Active and gui.Shop.Cosmetics.RiftSparksGoal.Text == "120 coins", "coin requirement is clear when unaffordable")
p:SetAttribute("Coins", 120) p:GetAttributeChangedSignal("Coins"):Fire()
gui.Shop.Cosmetics.RiftSparksAction.Activated:Fire()
assert(#cosmeticRequests == 1 and cosmeticRequests[1] == "RiftSparks" and p:GetAttribute("Coins") == 120, "explicit cosmetic request never grants or spends on client")
p:SetAttribute("CosmeticsUnlocked", "NoAura,NoTitle,RiftSparks")
p:SetAttribute("AuraEquipped", "RiftSparks")
p:GetAttributeChangedSignal("CosmeticsUnlocked"):Fire()
assert(gui.Shop.Cosmetics.RiftSparksAction.Text == "EQUIPPED" and not gui.Shop.Cosmetics.RiftSparksAction.Active, "server confirmation updates equipped row")
p:SetAttribute("Crossings", 2) p:GetAttributeChangedSignal("Crossings"):Fire()
assert(gui.Shop.Cosmetics.CrystalScoutGoal.Text == "2/3 courses completed" and not gui.Shop.Cosmetics.CrystalScoutAction.Active, "goal row shows progress while locked")
p:SetAttribute("CosmeticsUnlocked", "NoAura,NoTitle,RiftSparks,CrystalScout")
p:GetAttributeChangedSignal("CosmeticsUnlocked"):Fire()
assert(gui.Shop.Cosmetics.CrystalScoutAction.Text == "EQUIP" and gui.Shop.Cosmetics.CrystalScoutAction.Active, "goal completion unlocks equip action")
gui.Shop.Cosmetics.RoyalHaloAction.Activated:Fire()
assert(gui.Shop.Passes.Visible and #cosmeticRequests == 1, "locked VIP item routes to passes without granting cosmetics")
-- A second isolated UI execution uses configured IDs and controlled price responses.
gui:Destroy()
services.MarketplaceService.PromptGamePassPurchaseFinished = signal()
for _, pass in ipairs(Config.Passes) do
	p:GetAttributeChangedSignal("Pass_" .. pass.key).callbacks = {}
	p:GetAttributeChangedSignal("PassStatus_" .. pass.key).callbacks = {}
end
local testIds, prompted, apiCalls = next(Ids) and Ids or { VIP = 101, DoubleCoins = 102, StylePack = 103 }, {}, 0
env.game.GameId = 1
services.RunService.IsStudio = function() return false end
services.MarketplaceService.GetProductInfoAsync = function(_, id, kind)
	apiCalls += 1
	assert(kind == r.Enum.InfoType.GamePass)
	if id == testIds.StylePack then error("price API unavailable") end
	return { IsForSale = true, PriceInRobux = id == testIds.VIP and 87 or 132 }
end
services.MarketplaceService.PromptGamePassPurchase = function(_, _, id) table.insert(prompted, id) end
for _, pass in ipairs(Config.Passes) do p:SetAttribute("Pass_" .. pass.key, false) p:SetAttribute("PassStatus_" .. pass.key, "Ready") end
env.require = function(module) return module.Name == "Config" and Config or testIds end
luau.load(fs.readFile("src/client/Controller.client.luau"), { environment = env })()
gui = pg.RiftHUD
gui.Menu.ShopButton.Activated:Fire()
assert(apiCalls == 3 and gui.Shop.Visible, "opening shop fetches client prices once")
local liveButtons = {}
for _, child in ipairs(gui.Shop.Passes:GetChildren()) do if child:IsA("TextButton") then table.insert(liveButtons, child) end end
assert(liveButtons[1].Text == "87 ROBUX" and liveButtons[2].Text == "132 ROBUX", "shop uses returned personalized prices, never launch suggestions")
assert(not liveButtons[3].Active and liveButtons[3].Text == "UNAVAILABLE", "price failures disable purchase")
assert(#prompted == 0, "opening shop never automatically prompts")
liveButtons[1].Activated:Fire()
assert(#prompted == 1 and prompted[1] == testIds.VIP and not liveButtons[2].Active, "explicit button opens the configured pass and locks duplicates")
services.MarketplaceService.PromptGamePassPurchaseFinished:Fire(p, testIds.VIP, false)
assert(liveButtons[1].Active and p:GetAttribute("Pass_VIP") == false, "cancelled purchase restores button without granting")
p:SetAttribute("Pass_VIP", true)
p:GetAttributeChangedSignal("Pass_VIP"):Fire()
assert(liveButtons[1].Text == "OWNED" and not liveButtons[1].Active, "verified owner cannot repurchase")
print("PASS: actual client UI, compact layout, chase HUD, cosmetic goals/equipping, personalized prices and cancellation")
