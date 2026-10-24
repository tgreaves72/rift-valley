local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("RiftShared").Config)
local PassIds = require(ReplicatedStorage.RiftShared.PassIds)
local Remote = ReplicatedStorage:WaitForChild("RiftAction")
local palette = { ink = Color3.fromRGB(48, 35, 82), paper = Color3.fromRGB(246, 245, 255),
	muted = Color3.fromRGB(185, 177, 216), mint = Color3.fromRGB(145, 255, 214),
	violet = Color3.fromRGB(201, 173, 255), amber = Color3.fromRGB(255, 221, 137) }

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.ZIndexBehavior = "RiftHUD", false, Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local item = Instance.new("UICorner")
	item.CornerRadius, item.Parent = UDim.new(0, radius or 22), parent
end

local function label(parent, name, text, size, position, fontSize, color)
	local item = Instance.new("TextLabel")
	item.Name, item.Text, item.Size, item.Position = name, text, size, position
	item.BackgroundTransparency, item.TextColor3 = 1, color or palette.paper
	item.Font, item.TextSize = Enum.Font.FredokaOne, fontSize or 18
	if (fontSize or 18) <= 12 then item.Font = Enum.Font.GothamMedium end
	item.TextWrapped = true
	item.Parent = parent
	return item
end

local function panel(name, size, position)
	local frame = Instance.new("Frame")
	frame.Name, frame.Size, frame.Position = name, size, position
	frame.BackgroundColor3, frame.BackgroundTransparency = palette.ink, 0.12
	frame.BorderSizePixel, frame.Parent = 0, gui
	corner(frame)
	local stroke = Instance.new("UIStroke")
	stroke.Color, stroke.Transparency, stroke.Thickness, stroke.Parent = palette.violet, 0.38, 2, frame
	return frame
end

local function button(parent, text, size, position)
	local item = Instance.new("TextButton")
	item.Text, item.Size, item.Position = text, size, position
	item.Font, item.TextSize = Enum.Font.FredokaOne, 15
	item.TextColor3, item.BackgroundColor3 = palette.ink, palette.mint
	item.BorderSizePixel, item.Parent = 0, parent
	corner(item, 18)
	return item
end

local header = panel("Match", UDim2.fromOffset(340, 76), UDim2.new(0.5, -170, 0, 12))
local timer = label(header, "Timer", "...", UDim2.fromOffset(56, 52), UDim2.new(1, -66, 0, 12), 27, palette.ink)
timer.BackgroundColor3, timer.BackgroundTransparency = palette.amber, 0
corner(timer, 20)
local status = label(header, "Status", "Loading...", UDim2.new(1, -94, 0, 34), UDim2.fromOffset(18, 8), 25)
status.TextXAlignment = Enum.TextXAlignment.Left
local detail = label(header, "Detail", "", UDim2.fromOffset(60, 20), UDim2.fromOffset(157, 44), 12, palette.muted)
local courseDots = {}
for index = 1, #Config.Courses do
	local dot = Instance.new("Frame")
	dot.Name, dot.Size, dot.Position = "CourseDot" .. index, UDim2.fromOffset(14, 14), UDim2.fromOffset(20 + (index-1)*25, 47)
	dot.BackgroundColor3, dot.BorderSizePixel, dot.Parent = palette.muted, 0, header
	corner(dot, 7)
	courseDots[index] = dot
end

local resources = panel("Resources", UDim2.fromOffset(132, 46), UDim2.fromOffset(14, 14))
local coins = label(resources, "Coins", "0 Coins", UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), 18, palette.amber)

local staminaPanel = panel("Movement", UDim2.fromOffset(250, 64), UDim2.new(0.5, -125, 1, -80))
local role = label(staminaPanel, "Role", "Dash Ready!", UDim2.new(1, -24, 0, 23), UDim2.fromOffset(12, 5), 17, palette.mint)
role.TextXAlignment = Enum.TextXAlignment.Left
local track = Instance.new("Frame")
track.Name = "Stamina"
track.Size, track.Position, track.BackgroundColor3 = UDim2.new(1, -24, 0, 8), UDim2.fromOffset(12, 29), Color3.fromRGB(77, 61, 109)
track.BorderSizePixel, track.Parent = 0, staminaPanel
corner(track, 6)
local fill = Instance.new("Frame")
fill.Size, fill.BackgroundColor3, fill.BorderSizePixel, fill.Parent = UDim2.fromScale(1, 1), palette.mint, 0, track
corner(fill, 6)
local controls = label(staminaPanel, "Controls", "Q Dash  /  Shift Sprint", UDim2.new(1, -24, 0, 19), UDim2.fromOffset(12, 40), 12, palette.muted)

local leftButtons = panel("Menu", UDim2.fromOffset(130, 220), UDim2.new(0, 14, 1, -236))
local shopButton = button(leftButtons, "Shop", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 8))
shopButton.Name = "ShopButton"
local vipButton = button(leftButtons, "VIP", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 50))
vipButton.Name, vipButton.BackgroundColor3 = "VIPButton", palette.amber
local voteButton = button(leftButtons, "Maps", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 92))
voteButton.BackgroundColor3 = palette.violet
local masteryButton = button(leftButtons,"Mastery",UDim2.new(1,-16,0,34),UDim2.fromOffset(8,134))
masteryButton.Name, masteryButton.BackgroundColor3 = "MasteryButton", palette.amber
masteryButton.Activated:Connect(function() player:SetAttribute("MasteryMenuOpen",true) end)
local helpButton = button(leftButtons, "?", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 176))
helpButton.Name = "HelpButton"
helpButton.BackgroundColor3 = palette.paper
local journeyButton=button(leftButtons,"Goals",UDim2.new(1,-16,0,34),UDim2.fromOffset(8,218))
journeyButton.Name,journeyButton.BackgroundColor3="JourneyButton",palette.violet
journeyButton.Activated:Connect(function() player:SetAttribute("MasteryMenuOpen",false) player:SetAttribute("JourneyMenuOpen",not player:GetAttribute("JourneyMenuOpen")) end)
for _,item in ipairs({shopButton,vipButton,voteButton,masteryButton,helpButton}) do
	item.Activated:Connect(function() player:SetAttribute("JourneyMenuOpen",false) end)
end

local notice = panel("Notice", UDim2.fromOffset(240, 40), UDim2.new(0.5, -120, 0, 100))
notice.Visible = false
notice.BackgroundTransparency = .08
local noticeOutline = notice:FindFirstChildOfClass("UIStroke")
noticeOutline.Thickness, noticeOutline.Transparency = 1, .65
local noticeDot = Instance.new("Frame")
noticeDot.Name, noticeDot.Size, noticeDot.Position = "Accent", UDim2.fromOffset(6, 6), UDim2.fromOffset(12, 17)
noticeDot.BackgroundColor3, noticeDot.BorderSizePixel, noticeDot.Parent = palette.mint, 0, notice
corner(noticeDot, 3)
local noticeText = label(notice, "Text", "", UDim2.new(1, -40, 1, -10), UDim2.fromOffset(26, 5), 15, palette.paper)
local noticeToken = 0
local quietNotices = {
	["Next Course!"] = true, ["Energy!"] = true, ["Dash Ready!"] = true,
	["Nice Dodge!"] = true, ["Shortcut Bonus!"] = true, ["You Made It!"] = true,
	["Catch the runners!"] = true, ["Gotcha!"] = true,
	["Jump to the Top!"] = true, ["Try Again!"] = true, ["Checkpoint!"] = true,
}
local function showNotice(message, duration)
	if type(message) ~= "string" or quietNotices[message] or string.match(message, "^%+%d+ Coins$") then return end
	noticeToken += 1
	local token = noticeToken
	noticeText.Text, notice.Visible = message, true
	noticeText.TextSize = #message > 36 and 13 or 15
	notice.Size = UDim2.fromOffset(240, #message > 70 and 60 or 40)
	task.delay(duration or 2, function() if token == noticeToken then notice.Visible = false end end)
end

local help = panel("Help", UDim2.fromOffset(360, 202), UDim2.new(0.5, -180, 0.5, -101))
help.Visible = false
label(help, "Heading", "Run to Finish!", UDim2.new(1, -28, 0, 40), UDim2.fromOffset(14, 20), 30, palette.mint)
label(help, "Rules", "Dodge chasers. Jump gaps!", UDim2.new(1, -36, 0, 42), UDim2.fromOffset(18, 71), 20, palette.paper)
local helpClose = button(help, "Let's Go!", UDim2.new(1, -48, 0, 42), UDim2.fromOffset(24, 137))
helpClose.Activated:Connect(function() help.Visible = false end)
helpButton.Activated:Connect(function() help.Visible = not help.Visible end)

local shop = panel("Shop", UDim2.fromOffset(460, 468), UDim2.new(0.5, -230, 0.5, -234))
shop.Visible = false
label(shop, "Title", "LEAVE YOUR MARK", UDim2.new(1, -100, 0, 34), UDim2.fromOffset(16, 12), 22, palette.mint)
local closeShop = button(shop, "CLOSE", UDim2.fromOffset(70, 30), UDim2.new(1, -86, 0, 14))
closeShop.Activated:Connect(function() shop.Visible = false end)
local trailsTab = button(shop, "TRAILS", UDim2.fromOffset(138, 32), UDim2.fromOffset(16, 53))
local cosmeticsTab = button(shop, "STYLE UNLOCKS", UDim2.fromOffset(138, 32), UDim2.fromOffset(160, 53))
cosmeticsTab.Name = "CosmeticsTab"
local passesTab = button(shop, "ROBUX PASSES", UDim2.fromOffset(138, 32), UDim2.fromOffset(304, 53))
local function scroll(parent, name, height)
	local frame = Instance.new("ScrollingFrame")
	frame.Name, frame.Size, frame.Position = name, UDim2.new(1, -24, 0, 320), UDim2.fromOffset(12, 96)
	frame.CanvasSize, frame.ScrollBarThickness = UDim2.fromOffset(0, height), 4
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.BackgroundTransparency, frame.BorderSizePixel, frame.Parent = 1, 0, parent
	return frame
end
local trailsContent = scroll(shop, "Trails", #Config.Trails * 62)
local passesContent = scroll(shop, "Passes", #Config.Passes * 116)
local cosmeticsContent = scroll(shop, "Cosmetics", #Config.Cosmetics * 78)
passesContent.Visible = false
cosmeticsContent.Visible = false
local saveLabel
local function setShopTab(passes)
	local styles = passes == "cosmetics"
	local robux = passes == true
	trailsContent.Visible, passesContent.Visible, cosmeticsContent.Visible = not robux and not styles, robux, styles
	trailsTab.BackgroundColor3, passesTab.BackgroundColor3 = trailsContent.Visible and palette.mint or palette.muted, robux and palette.amber or palette.muted
	cosmeticsTab.BackgroundColor3 = styles and palette.violet or palette.muted
	if saveLabel then saveLabel.Text = robux and "One-time Robux purchases. Everyone shares the same chase abilities." or (styles and "Earn coins or complete goals. Wear one aura and one title." or ((player:GetAttribute("SaveStatus") or "Loading profile") .. "\nCosmetic trails change appearance.")) end
end
local shopRows = {}
local statNames = { Crossings="courses completed", Wins="wins", Tags="tags", GroveMedals="Grove medals", RuinsMedals="Ruins medals", HarborMedals="Harbor medals", MedalPoints="medal points", SilverMedals="silver or gold medals", GoldMedals="gold medals" }
local function goalText(requirement)
	return tostring(player:GetAttribute(requirement.stat) or 0) .. "/" .. requirement.amount .. " " .. (statNames[requirement.stat] or string.lower(requirement.stat))
end
for index, trail in ipairs(Config.Trails) do
	local y = (index - 1) * 62
	local title = label(trailsContent, trail.id, trail.name, UDim2.fromOffset(235, 24), UDim2.fromOffset(8, y), 17, Color3.fromRGB(unpack(trail.rgb)))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local costText = trail.requirement and goalText(trail.requirement) or (trail.pass and (trail.pass == "VIP" and "Included with Valley VIP" or "Included with Prism Trail Pack") or (trail.cost == 0 and "Included" or trail.cost .. " coins"))
	local cost = label(trailsContent, trail.id .. "Cost", costText, UDim2.fromOffset(240, 18), UDim2.fromOffset(8, y + 25), 12, palette.muted)
	cost.TextXAlignment = Enum.TextXAlignment.Left
	local buy = button(trailsContent, "EQUIP", UDim2.fromOffset(118, 38), UDim2.new(1, -132, 0, y + 3))
	buy.Activated:Connect(function()
		if trail.pass and player:GetAttribute("Pass_" .. trail.pass) ~= true then setShopTab(true)
		else Remote:FireServer("Trail", trail.id) end
	end)
	shopRows[trail.id] = buy
	if trail.requirement then player:GetAttributeChangedSignal(trail.requirement.stat):Connect(function() cost.Text = goalText(trail.requirement) end) end
end
local cosmeticRows, cosmeticDescriptions = {}, {}
local function updateCosmetics()
	local unlocked = "," .. (player:GetAttribute("CosmeticsUnlocked") or "NoAura,NoTitle") .. ","
	for _, definition in ipairs(Config.Cosmetics) do
		local owned = string.find(unlocked, "," .. definition.id .. ",", 1, true) ~= nil
		local defaults = { Aura="NoAura",Title="NoTitle",Skin="DefaultSkin",Victory="DefaultVictory" }
		local equipped = (player:GetAttribute(definition.slot .. "Equipped") or defaults[definition.slot]) == definition.id
		local row = cosmeticRows[definition.id]
		local canAfford = definition.cost and (player:GetAttribute("Coins") or 0) >= definition.cost
		row.Text = equipped and "EQUIPPED" or (owned and "EQUIP" or (definition.pass and "VIEW PASS" or (definition.requirement and "LOCKED" or "UNLOCK")))
		row.Active = not equipped and (owned or definition.pass ~= nil or canAfford == true)
		row.Selectable, row.AutoButtonColor = row.Active, row.Active
		row.BackgroundColor3 = row.Active and palette.mint or palette.muted
		local text = definition.pass and "Included with Valley VIP" or (definition.cost == 0 and "Included" or tostring(definition.cost) .. " coins")
		if definition.requirement then
			local requirement = definition.requirement
			text = goalText(requirement)
			if owned then text = "Goal completed / unlocked" end
		end
		cosmeticDescriptions[definition.id].Text = text
	end
end
for index, definition in ipairs(Config.Cosmetics) do
	local y = (index - 1)*78
	local title = label(cosmeticsContent, definition.id, string.upper(definition.slot) .. " / " .. definition.name, UDim2.fromOffset(252, 27), UDim2.fromOffset(8, y), 15, Color3.fromRGB(unpack(definition.rgb)))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local description = label(cosmeticsContent, definition.id .. "Goal", "", UDim2.fromOffset(252, 35), UDim2.fromOffset(8, y+28), 12, palette.muted)
	description.TextXAlignment = Enum.TextXAlignment.Left
	local equip = button(cosmeticsContent, "LOCKED", UDim2.fromOffset(118, 38), UDim2.new(1, -132, 0, y+9))
	equip.Name = definition.id .. "Action"
	equip.Activated:Connect(function()
		if not equip.Active then return end
		if definition.pass and player:GetAttribute("Pass_" .. definition.pass) ~= true then setShopTab(true)
		else Remote:FireServer("Cosmetic", definition.id) end
	end)
	cosmeticRows[definition.id], cosmeticDescriptions[definition.id] = equip, description
end
updateCosmetics()
cosmeticsTab.Activated:Connect(function() setShopTab("cosmetics") updateCosmetics() end)
saveLabel = label(shop, "SaveStatus", "", UDim2.new(1, -36, 0, 36), UDim2.fromOffset(18, 424), 11, palette.muted)
local passRows, productInfo, priceCheckedAt = {}, {}, -100
local vote
local pendingPurchase = nil
local function updatePasses()
	for _, pass in ipairs(Config.Passes) do
		local row, info = passRows[pass.key], productInfo[pass.key]
		local owned = player:GetAttribute("Pass_" .. pass.key) == true
		local statusText = player:GetAttribute("PassStatus_" .. pass.key)
		local canBuy = PassIds[pass.key] and not RunService:IsStudio() and game.GameId ~= 0 and info and info.IsForSale and type(info.PriceInRobux) == "number" and statusText == "Ready" and not pendingPurchase and not owned
		row.Active, row.Selectable = canBuy == true, canBuy == true
		row.BackgroundColor3 = owned and palette.mint or (canBuy and palette.amber or palette.muted)
		row.Text = owned and "OWNED" or (not PassIds[pass.key] and "COMING SOON" or ((RunService:IsStudio() or game.GameId == 0) and "LIVE GAME ONLY" or (pendingPurchase == pass.key and "IN ROBLOX..." or (canBuy and (tostring(info.PriceInRobux) .. " ROBUX") or "UNAVAILABLE"))))
	end
end
for index, pass in ipairs(Config.Passes) do
	local y = (index - 1) * 116
	local tagline = label(passesContent, pass.key .. "Tagline", pass.tagline, UDim2.new(1, -16, 0, 18), UDim2.fromOffset(8, y), 11, Color3.fromRGB(unpack(pass.rgb)))
	tagline.TextXAlignment = Enum.TextXAlignment.Left
	local title = label(passesContent, pass.key, pass.name, UDim2.fromOffset(248, 26), UDim2.fromOffset(8, y + 18), 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local copy = label(passesContent, pass.key .. "Copy", pass.description, UDim2.fromOffset(282, 52), UDim2.fromOffset(8, y + 46), 12, palette.muted)
	copy.TextXAlignment, copy.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
	local buy = button(passesContent, "COMING SOON", UDim2.fromOffset(128, 40), UDim2.new(1, -136, 0, y + 33))
	passRows[pass.key] = buy
	buy.Activated:Connect(function()
		if not buy.Active or pendingPurchase or not PassIds[pass.key] then return end
		pendingPurchase = pass.key
		updatePasses()
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, PassIds[pass.key]) end)
		if not ok then pendingPurchase = nil updatePasses() showNotice("Roblox could not open this purchase. Try again later.") end
	end)
	player:GetAttributeChangedSignal("Pass_" .. pass.key):Connect(updatePasses)
	player:GetAttributeChangedSignal("PassStatus_" .. pass.key):Connect(updatePasses)
end
local function refreshPrices()
	if os.clock() - priceCheckedAt < 45 then return end
	priceCheckedAt = os.clock()
	for _, pass in ipairs(Config.Passes) do
		local id = PassIds[pass.key]
		if id and not RunService:IsStudio() and game.GameId ~= 0 then
			task.spawn(function()
				local ok, info = pcall(function() return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.GamePass) end)
				productInfo[pass.key] = ok and info or nil
				updatePasses()
			end)
		end
	end
end
local function openShop(passes)
	player:SetAttribute("MasteryMenuOpen",false)
	shop.Visible, help.Visible = true, false
	if vote then vote.Visible = false end
	setShopTab(passes)
	Remote:FireServer("RefreshPasses")
	refreshPrices()
end
local starterGoal = panel("StarterGoal", UDim2.fromOffset(200, 60), UDim2.new(.5, -100, 1, -86))
starterGoal.Visible = false
label(starterGoal, "Reward", "Rift Scout", UDim2.fromOffset(126, 26), UDim2.fromOffset(12, 5), 19, palette.mint)
local starterProgress = label(starterGoal, "Progress", "0 / 3", UDim2.fromOffset(55, 26), UDim2.fromOffset(140, 5), 17, palette.amber)
label(starterGoal, "Goal", "Finish 3 Courses", UDim2.new(1, -24, 0, 20), UDim2.fromOffset(12, 33), 12, palette.paper)
local retryButton = button(gui, "Run Again!", UDim2.fromOffset(180, 46), UDim2.new(.5, -90, 1, -142))
retryButton.Name, retryButton.Visible = "RetryButton", false
retryButton.Activated:Connect(function() Remote:FireServer("Retry") end)
local lobbyButton = button(gui, "Lobby", UDim2.fromOffset(130, 40), UDim2.new(.5, -65, 1, -86))
lobbyButton.Name, lobbyButton.Visible, lobbyButton.BackgroundColor3 = "LobbyButton", false, palette.violet
lobbyButton.Activated:Connect(function() Remote:FireServer("PauseSolo") end)
local parkourRetry = button(gui,"Retry Parkour",UDim2.fromOffset(152,42),UDim2.new(1,-166,1,-70))
parkourRetry.Name,parkourRetry.Visible,parkourRetry.BackgroundColor3 = "ParkourRetryButton",false,palette.mint
parkourRetry.Activated:Connect(function() if parkourRetry.Active then Remote:FireServer("ParkourRetry") end end)
shopButton.Activated:Connect(function() if shop.Visible then shop.Visible = false else openShop(false) end end)
vipButton.Activated:Connect(function()
	shop.Visible, help.Visible, vote.Visible = false, false, false
	player:SetAttribute("MasteryMenuOpen", false)
	Remote:FireServer("VisitVIP")
end)
trailsTab.Activated:Connect(function() setShopTab(false) end)
passesTab.Activated:Connect(function() setShopTab(true) Remote:FireServer("RefreshPasses") refreshPrices() end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, id)
	if who ~= player or not pendingPurchase or PassIds[pendingPurchase] ~= id then return end
	pendingPurchase = nil
	updatePasses()
	Remote:FireServer("RefreshPasses")
end)
updatePasses()

vote = panel("MapVote", UDim2.fromOffset(440, 334), UDim2.new(.5, -220, .5, -167))
vote.Visible = false
label(vote, "Title", "WHERE TO NEXT?", UDim2.new(1, -100, 0, 36), UDim2.fromOffset(16, 12), 23, palette.violet)
local voteClose = button(vote, "CLOSE", UDim2.fromOffset(70, 30), UDim2.new(1, -86, 0, 14))
voteClose.Activated:Connect(function() vote.Visible = false end)
local voteRows = {}
for index, map in ipairs(Config.Maps) do
	local y = 61 + (index - 1) * 77
	local title = label(vote, map.id, map.name, UDim2.fromOffset(246, 26), UDim2.fromOffset(16, y), 19, Color3.fromRGB(unpack(map.rgb)))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local desc = label(vote, map.id .. "Copy", map.description, UDim2.fromOffset(257, 36), UDim2.fromOffset(16, y + 25), 12, palette.muted)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	local select = label(vote,map.id.."Count","",UDim2.fromOffset(114,40),UDim2.new(1,-130,0,y+5),16,palette.mint)
	voteRows[map.id] = select
end
label(vote, "Hint", "Step on a lobby plate to vote!", UDim2.new(1, -32, 0, 24), UDim2.fromOffset(16, 301), 11, palette.muted)
local voteTally = panel("VoteTally", UDim2.fromOffset(210, 142), UDim2.new(1, -14, 0, 104))
voteTally.AnchorPoint, voteTally.Visible = Vector2.new(1, 0), false
label(voteTally, "Title", "Next Map", UDim2.fromOffset(186, 24), UDim2.fromOffset(12, 6), 16, palette.paper).TextXAlignment = Enum.TextXAlignment.Left
local tallyRows = {}
for index, map in ipairs(Config.Maps) do
	local row = Instance.new("Frame")
	row.Name, row.Size, row.Position = map.id, UDim2.fromOffset(186, 28), UDim2.fromOffset(12, 36+(index-1)*32)
	row.BackgroundColor3, row.BackgroundTransparency, row.BorderSizePixel, row.Parent = palette.violet, .94, 0, voteTally
	corner(row, 12)
	local title = label(row, "Title", map.name, UDim2.fromOffset(139, 28), UDim2.fromOffset(10, 0), 13, palette.muted)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local count = label(row, "Count", "0", UDim2.fromOffset(28, 28), UDim2.fromOffset(154, 0), 17, Color3.fromRGB(unpack(map.rgb)))
	local choice = Instance.new("Frame")
	choice.Name, choice.Size, choice.Position = "Choice", UDim2.fromOffset(3, 14), UDim2.fromOffset(0, 7)
	choice.BackgroundColor3, choice.BorderSizePixel, choice.Parent, choice.Visible = palette.mint, 0, row, false
	corner(choice, 2)
	tallyRows[map.id] = {row=row, title=title, count=count, choice=choice}
end
local function updateVotes()
	local enabled = ReplicatedStorage:GetAttribute("VotingOpen") == true and player:GetAttribute("Role") == "Spectator"
	for _, map in ipairs(Config.Maps) do
		local row = voteRows[map.id]
		row.Text = (player:GetAttribute("MapVote") == map.id and "✓ " or "") .. tostring(ReplicatedStorage:GetAttribute("Votes_" .. map.id) or 0).." votes"
		row.TextColor3 = enabled and Color3.fromRGB(unpack(map.rgb)) or palette.muted
		local tally = tallyRows[map.id]
		local selected = player:GetAttribute("MapVote") == map.id
		tally.count.Text = tostring(ReplicatedStorage:GetAttribute("Votes_" .. map.id) or 0)
		tally.choice.Visible = selected
		tally.row.BackgroundTransparency = selected and .82 or .94
		tally.title.TextColor3 = selected and palette.paper or palette.muted
	end
end
for _, map in ipairs(Config.Maps) do ReplicatedStorage:GetAttributeChangedSignal("Votes_" .. map.id):Connect(updateVotes) end
ReplicatedStorage:GetAttributeChangedSignal("VotingOpen"):Connect(updateVotes)
player:GetAttributeChangedSignal("MapVote"):Connect(updateVotes)
player:GetAttributeChangedSignal("Role"):Connect(updateVotes)
voteButton.Activated:Connect(function() vote.Visible = not vote.Visible shop.Visible, help.Visible = false, false updateVotes() end)
helpButton.Activated:Connect(function() if help.Visible then shop.Visible, vote.Visible = false, false end end)
updateVotes()

local goal = Instance.new("Part")
goal.Name, goal.Size, goal.Anchored, goal.CanCollide, goal.CanQuery, goal.Transparency = "LocalGoal", Vector3.new(1, 1, 1), true, false, false, 1
goal.Parent = workspace
local beacon = Instance.new("BillboardGui")
beacon.Size, beacon.StudsOffset, beacon.AlwaysOnTop, beacon.MaxDistance = UDim2.fromOffset(250, 54), Vector3.new(0, 16, 0), true, 500
beacon.Parent = goal
local goalLabel = label(beacon, "Target", "Finish!", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 27, palette.mint)
goalLabel.TextStrokeTransparency = 0.45

local sprinting = false
local dashUntil = 0
local dashDirection = Vector3.zero
local function sprint(_, inputState)
	if inputState == Enum.UserInputState.Begin then sprinting = true
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then sprinting = false end
	Remote:FireServer("Sprint", sprinting)
	return Enum.ContextActionResult.Sink
end

local function dash(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Sink end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root then
		local move = humanoid.MoveDirection
		if move.Magnitude < 0.1 then move = root.CFrame.LookVector end
		Remote:FireServer("Dash", Vector3.new(move.X, 0, move.Z).Unit)
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction("RiftSprint", sprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
ContextActionService:BindAction("RiftDash", dash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
ContextActionService:SetTitle("RiftSprint", "SPRINT")
ContextActionService:SetTitle("RiftDash", "DASH")
ContextActionService:SetPosition("RiftSprint", UDim2.new(1, -190, 1, -155))
ContextActionService:SetPosition("RiftDash", UDim2.new(1, -120, 1, -210))
UserInputService.WindowFocusReleased:Connect(function() sprinting = false Remote:FireServer("Sprint", false) end)
local function characterReady(character)
	sprinting = false dashUntil = 0 Remote:FireServer("Sprint", false)
	task.spawn(function()
		local root=character:WaitForChild("HumanoidRootPart",10)
		if not root then return end
		RunService.RenderStepped:Wait()
		if player.Character==character then Remote:FireServer("CharacterReady",character) end
	end)
end
player.CharacterAdded:Connect(characterReady)
if player.Character then characterReady(player.Character) end

local rng = Random.new()
local function burst(position, color, count)
	for _ = 1, count do
		local part = Instance.new("Part")
		part.Name, part.Size = "LocalCelebration", Vector3.new(.28, .28, .28)
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Color, part.Material, part.CFrame = color, Enum.Material.Neon, CFrame.new(position)
		part.Parent = workspace
		TweenService:Create(part, TweenInfo.new(.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(2, 9), rng:NextNumber(-7, 7))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Transparency = 1,
		}):Play()
		Debris:AddItem(part, .9)
	end
end

Remote.OnClientEvent:Connect(function(action, payload, kind)
	if action == "Notice" then showNotice(payload)
	elseif action == "MasteryResult" and type(payload) == "table" and (payload.practice or payload.stage == #Config.Courses) then
		noticeToken += 1
		notice.Visible = false
	elseif action == "ScoutUnlocked" then
		-- The equipped title and collection update without covering a running course.
		if player:GetAttribute("Role") ~= "Runner" then showNotice("Rift Scout Unlocked!", 2.5) end
	elseif action == "DashStop" then dashUntil = 0
	elseif action == "CourseClear" then burst(payload.position, palette.mint, 12)
	elseif action == "Dash" then
		dashDirection, dashUntil = payload, os.clock() + Config.DashDuration
	elseif action == "OpenPasses" then openShop(true)
	elseif action == "OpenCosmetics" then openShop("cosmetics") updateCosmetics()
	elseif action == "Confetti" then burst(payload, palette.violet, 20)
	elseif action == "Recharge" then burst(payload + Vector3.new(0, 2, 0), kind == "Stamina" and Color3.fromRGB(108, 255, 204) or Color3.fromRGB(123, 224, 255), 12)
	elseif action == "Crystal" then
		if typeof(payload) == "Instance" and payload:IsA("BasePart") and payload.Parent then
			payload.LocalTransparencyModifier = .9
			burst(payload.Position, payload.Color, 8)
		end
	elseif action == "Results" then
		if not player:GetAttribute("CoursePractice") then showNotice(payload.won and "You Win!" or "Nice Try!", 2.5) end
	end
end)

local function updateProfile()
	coins.Text = tostring(player:GetAttribute("Coins") or 0) .. " Coins"
	local owned = "," .. (player:GetAttribute("OwnedTrails") or "None") .. ","
	local equipped = player:GetAttribute("Equipped") or "None"
	for _, trail in ipairs(Config.Trails) do
		local available = string.find(owned, "," .. trail.id .. ",", 1, true) ~= nil
		shopRows[trail.id].Text = trail.id == equipped and "EQUIPPED" or (available and "EQUIP" or (trail.pass and "VIEW PASS" or (trail.requirement and "LOCKED" or "UNLOCK")))
		shopRows[trail.id].Active = trail.id ~= equipped and (not trail.requirement or available)
		shopRows[trail.id].Selectable = shopRows[trail.id].Active
	end
	updateCosmetics()
	saveLabel.Text = passesContent.Visible and "One-time Robux purchases. Everyone shares the same chase abilities." or (cosmeticsContent.Visible and ((player:GetAttribute("SaveStatus") or "Loading profile") .. "\nEarn coins or complete goals. Wear one aura + one title.") or ((player:GetAttribute("SaveStatus") or "Loading profile") .. "\nCosmetic trails change appearance."))
end
passesTab.Activated:Connect(updateProfile)
trailsTab.Activated:Connect(updateProfile)
for _, attribute in ipairs({ "Coins", "Level", "Wins", "Tags", "Crossings", "OwnedTrails", "Equipped", "SaveStatus", "CosmeticsUnlocked", "AuraEquipped", "TitleEquipped", "SkinEquipped", "VictoryEquipped", "MedalPoints", "SilverMedals", "GoldMedals", "GroveMedals", "RuinsMedals", "HarborMedals" }) do
	player:GetAttributeChangedSignal(attribute):Connect(updateProfile)
end
updateProfile()
player:GetAttributeChangedSignal("MasteryMenuOpen"):Connect(function()
	if player:GetAttribute("MasteryMenuOpen") then shop.Visible,help.Visible,vote.Visible = false,false,false end
end)
player:GetAttributeChangedSignal("MasteryRewardsOpen"):Connect(function()
	if player:GetAttribute("MasteryRewardsOpen") then player:SetAttribute("MasteryRewardsOpen",false) openShop("cosmetics") updateCosmetics() end
end)

local function updateLayout()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local width, height = camera.ViewportSize.X, camera.ViewportSize.Y
	local compact = width < 820
	header.Size = UDim2.fromOffset(compact and 306 or 340, 76)
	header.Position = UDim2.new(0.5, compact and -153 or -170, 0, 10)
	status.TextSize = compact and 22 or 25
	resources.Size = UDim2.fromOffset(132, 46)
	resources.Position = compact and UDim2.fromOffset(10, 100) or UDim2.fromOffset(14, 14)
	local mobile = UserInputService.TouchEnabled
	local tallyScale = voteTally:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	local narrowTally = width < 370
	tallyScale.Scale, tallyScale.Parent = math.min(height < 480 and .82 or 1, (width-(narrowTally and 140 or 24))/210), voteTally
	voteTally.Position = UDim2.new(1, compact and -10 or -14, 0, narrowTally and 154 or (compact and 100 or 104))
	staminaPanel.Size = UDim2.fromOffset(mobile and 230 or 250, 64)
	staminaPanel.Position = UDim2.new(0.5, mobile and -115 or -125, 1, mobile and -112 or -80)
	local short = compact and height < 480
	if short then
		leftButtons.Size, leftButtons.Position = UDim2.fromOffset(140, 152), UDim2.fromOffset(10, 158)
	elseif compact then
		leftButtons.Size, leftButtons.Position = UDim2.fromOffset(108, 262), UDim2.fromOffset(10, 158)
	else
		leftButtons.Size, leftButtons.Position = UDim2.fromOffset(130, 262), UDim2.new(0, 14, 1, -278)
	end
	for index, item in ipairs({shopButton, vipButton, voteButton, masteryButton, helpButton, journeyButton}) do
		item.Size = short and UDim2.fromOffset(59, 42) or UDim2.new(1, -16, 0, 34)
		item.Position = short and UDim2.fromOffset(8+((index-1)%2)*65, 7+math.floor((index-1)/2)*48) or UDim2.fromOffset(8, 8+(index-1)*42)
		item.TextSize = short and 12 or 15
	end
	controls.Text = mobile and "Tap Dash  /  Hold Sprint" or (UserInputService.GamepadEnabled and "B Dash  /  L3 Sprint" or "Q Dash  /  Shift Sprint")
	for _, frame in ipairs({ help, shop, vote }) do
		local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Scale = math.min(1, (width - 24) / frame.Size.X.Offset, (height - 32) / frame.Size.Y.Offset)
		scale.Parent = frame
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(0.5, 0.5)
	end
	local noticeScale = notice:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	noticeScale.Scale, noticeScale.Parent = math.min(1, (width-24)/240), notice
	notice.AnchorPoint = Vector2.new(.5, 0)
	notice.Position = compact and height < 480 and UDim2.new(.5, 0, 0, 94) or UDim2.new(.5, 0, 1, -212)
end

local watchedCamera
local cameraConnection
local function watchCamera()
	watchedCamera = workspace.CurrentCamera
	if cameraConnection then cameraConnection:Disconnect() end
	if watchedCamera then cameraConnection = watchedCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout) end
	updateLayout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

local lastRefresh = 0
local performanceTime, performanceFrames = 0, 0
local cosmeticAt = 0
local shownPhase = ""
RunService.RenderStepped:Connect(function(dt)
	performanceTime += dt
	performanceFrames += 1
	if performanceTime >= 30 then
		Remote:FireServer("Playtest", { fps = math.clamp(performanceFrames/performanceTime, 1, 240), touch = UserInputService.TouchEnabled })
		performanceTime, performanceFrames = 0, 0
	end
	local phase = ReplicatedStorage:GetAttribute("Phase") or "Starting"
	local currentRole = player:GetAttribute("Role") or "Spectator"
	local training = player:GetAttribute("CoursePractice") == true
	local lesson=player:GetAttribute("TutorialActive")==true
	local journey=player:GetAttribute("JourneyMenuOpen")==true
	if journey or lesson then shop.Visible,help.Visible,vote.Visible=false,false,false player:SetAttribute("MasteryMenuOpen",false) end
	local now = workspace:GetServerTimeNow()
	local seconds = math.max(0, math.ceil((ReplicatedStorage:GetAttribute("Deadline") or now) - now))
	timer.Text = training and string.format("%.1f",player:GetAttribute("PracticeFinalTime") or math.max(0,now-(player:GetAttribute("PracticeStartedAt") or now))) or (phase == "Starting" and "..." or tostring(seconds))
	timer.TextSize = training and 20 or 27
	local labels = { Starting = "Loading...", Intermission = "Next Run!", Ready = "Get Ready!", Crossing = "Run to Finish!", Results = "Nice Run!" }
	status.Text = labels[phase] or "Get Ready!"
	local wave = player:GetAttribute("CourseStage") or 0
	local course = Config.Courses[wave]
	local racing = training or ((phase == "Crossing" or phase == "Ready") and wave > 0)
	status.Position = UDim2.fromOffset(18, racing and 8 or 20)
	detail.Text = racing and tostring(wave) .. " / " .. #Config.Courses or ""
	for index, dot in ipairs(courseDots) do
		dot.Visible = racing
		dot.BackgroundColor3 = index < wave and palette.mint or (index == wave and palette.amber or palette.muted)
		dot.BackgroundTransparency = index > wave and .6 or 0
	end
	local inLobby = currentRole == "Spectator" or currentRole == "Escaped"
	leftButtons.Visible = inLobby and not lesson
	parkourRetry.Visible = inLobby and not training and player:GetAttribute("ParkourRetryAvailable")==true
		and not shop.Visible and not help.Visible and not vote.Visible and not player:GetAttribute("MasteryMenuOpen") and not journey and not lesson
	parkourRetry.Active,parkourRetry.Selectable = not player:GetAttribute("ParkourRetryPending"),not player:GetAttribute("ParkourRetryPending")
	parkourRetry.Text = player:GetAttribute("ParkourRetryPending") and "Respawning..." or "Retry Parkour"
	voteTally.Visible = inLobby and not training and phase == "Intermission" and ReplicatedStorage:GetAttribute("VotingOpen") == true
		and not shop.Visible and not help.Visible and not vote.Visible and not player:GetAttribute("MasteryMenuOpen") and not journey and not lesson
	staminaPanel.Visible = lesson or training or ((phase == "Crossing" or phase == "Ready") and (currentRole == "Runner" or currentRole == "Catcher")) or (inLobby and player:GetAttribute("ParkourActive") == true)
	starterGoal.Visible = inLobby and phase ~= "Results" and not player:GetAttribute("ParkourActive") and (player:GetAttribute("Crossings") or 0) < 3 and not shop.Visible and not help.Visible and not vote.Visible and not player:GetAttribute("MasteryMenuOpen") and not journey and not lesson
	starterProgress.Text = tostring(math.min(3, player:GetAttribute("Crossings") or 0)) .. " / 3"
	retryButton.Visible = not training and ((phase == "Results" and ReplicatedStorage:GetAttribute("Practice") == true) or (phase == "Intermission" and player:GetAttribute("SoloPaused") == true))
	retryButton.Text = player:GetAttribute("SoloPaused") and "Play!" or "Run Again!"
	lobbyButton.Visible = not training and phase == "Results" and ReplicatedStorage:GetAttribute("Practice") == true and not player:GetAttribute("SoloPaused")
	voteButton.Text = "Maps"
	local readyIn = math.max(0, (player:GetAttribute("DashReadyAt") or 0) - now)
	role.Text = readyIn > 0 and string.format("Dash %.1fs", readyIn) or "Dash Ready!"
	role.TextColor3 = currentRole == "Catcher" and palette.violet or palette.mint
	if phase == "Crossing" then
		if currentRole == "Catcher" then status.Text = "Catch Runners!"
		elseif currentRole == "Escaped" then status.Text = "You Made It!"
		elseif currentRole == "Captured" then status.Text = "Gotcha!"
		elseif currentRole == "Spectator" then status.Text = "Next Run Soon!" end
	end
	if currentRole == "Captured" then role.Text = "Gotcha!" role.TextColor3 = palette.violet end
	if lesson then status.Text=({"Jump!","Sprint!","Dash!"})[player:GetAttribute("TutorialStep") or 1] timer.Text="★" end
	if training then status.Text = player:GetAttribute("PracticeFinished") and "Nice Practice!" or (now < (player:GetAttribute("PracticeStartedAt") or 0) and "Get Ready!" or "Practice Run!") end
	if inLobby and player:GetAttribute("ParkourActive") then
		role.Text = "Parkour " .. tostring(player:GetAttribute("ParkourCheckpoint") or 0) .. " / " .. tostring(Config.ParkourSteps)
		local elapsed = now - (player:GetAttribute("ParkourStartedAt") or now)
		local best = player:GetAttribute("ParkourBest")
		controls.Text = string.format("%.1fs%s", elapsed, best and string.format("  /  Best %.1fs", best) or "")
	else
		controls.Text = UserInputService.TouchEnabled and "Tap Dash  /  Hold Sprint" or (UserInputService.GamepadEnabled and "B Dash  /  L3 Sprint" or "Q Dash  /  Shift Sprint")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if currentRole == "Runner" and phase == "Crossing" and wave == 1 and root then
			if not player:GetAttribute("SprintLearned") and root.Position.Z < -95 then
				controls.Text = UserInputService.TouchEnabled and "Hold Sprint!" or (UserInputService.GamepadEnabled and "Press L3 to Sprint!" or "Hold Shift to Sprint!")
			elseif not player:GetAttribute("DashLearned") and root.Position.Z > -110 and root.Position.Z < -45 then
				controls.Text = UserInputService.TouchEnabled and "Tap Dash!" or (UserInputService.GamepadEnabled and "Press B to Dash!" or "Press Q to Dash!")
			end
		end
	end
	if currentRole == "Runner" and (player:GetAttribute("SafeUntil") or 0) > now then role.Text = "Safe Landing" end
	if player:GetAttribute("RouteBoost") then role.Text = "Speed Boost!" end
	local stamina = player:GetAttribute("Stamina") or 100
	fill.Size = UDim2.fromScale(stamina / Config.StaminaMax, 1)
	fill.BackgroundColor3 = stamina < 25 and palette.amber or palette.mint
	ContextActionService:SetTitle("RiftDash", readyIn > 0 and string.format("%.1f", readyIn) or "DASH")
	beacon.Enabled = training or ((phase == "Crossing" or phase == "Ready") and currentRole == "Runner")
	goal.Position = Vector3.new(course and course.x or 0, 2+(training and (player:GetAttribute("PracticeOffsetY") or 0) or 0), (course and course.z or 0) + Config.StartZ)
	goalLabel.Text = "Finish!"
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		local desired = os.clock() < dashUntil and 88 or (sprinting and (training or phase == "Crossing") and stamina > 0 and 80 or 72)
		camera.FieldOfView += (desired - camera.FieldOfView) * math.min(1, dt * 7)
	end
	if os.clock() < dashUntil and (lesson or training or phase == "Crossing") and (lesson or training or currentRole == "Runner" or currentRole == "Catcher") and not player:GetAttribute("BeingCaptured") then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then root.AssemblyLinearVelocity = dashDirection * Config.DashSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0) end
	end
	if os.clock() - lastRefresh > 0.8 then
		lastRefresh = os.clock()
		Remote:FireServer("Sprint", sprinting)
	end
	if phase ~= shownPhase then
		shownPhase = phase
		if phase == "Ready" and not training then
			shop.Visible, help.Visible, vote.Visible = false, false, false
			notice.Visible, noticeToken = false, noticeToken+1
		end
		if phase == "Crossing" then
			TweenService:Create(header, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(57, 44, 91) }):Play()
		else
			TweenService:Create(header, TweenInfo.new(0.2), { BackgroundColor3 = palette.ink }):Play()
		end
	end
	if os.clock() - cosmeticAt >= .1 then
		cosmeticAt = os.clock()
		for _, other in ipairs(Players:GetPlayers()) do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			local trail = root and root:FindFirstChild("RiftTrail")
			if trail and trail:GetAttribute("PaletteId") then
				for _, definition in ipairs(Config.Trails) do
					if definition.id == trail:GetAttribute("PaletteId") and definition.colors then
						local keys = {}
						for index = 1, #definition.colors do
							local offset = cosmeticAt * .5 + index - 1
							local a = 1 + math.floor(offset) % #definition.colors
							local b = 1 + a % #definition.colors
							local color = Color3.fromRGB(unpack(definition.colors[a])):Lerp(Color3.fromRGB(unpack(definition.colors[b])), offset % 1)
							table.insert(keys, ColorSequenceKeypoint.new((index - 1) / (#definition.colors - 1), color))
						end
						trail.Color = ColorSequence.new(keys)
					end
				end
			end
		end
	end
end)

