local fs, luau, r = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Config, Rules = require("../src/shared/Config"), require("../src/shared/Rules")
local host = require("./native-host")()
local function instance(class) return host.wrap(r.Instance.new(class)) end
local p, character, root, head = instance("Player"), instance("Model"), instance("Part"), instance("Part")
character.Parent = host.workspace
root.Name, root.CFrame, root.Parent = "HumanoidRootPart", r.CFrame.new(0, 4, 0), character
head.Name, head.CFrame, head.Parent = "Head", r.CFrame.new(0, 5.5, 0), character
root.Size = r.Vector3.new(2, 2, 1)
rawset(p, "Character", character)
local env = { game = { GetService = function() return host.replicated end },
	require = function(module) return module.Name == "Config" and Config or Rules end,
	Instance = { new = instance }, Vector3 = r.Vector3, Color3 = r.Color3, CFrame = r.CFrame, UDim2 = r.UDim2, Enum = r.Enum }
local Styles = luau.load(fs.readFile("src/server/StyleService.luau"), { environment = env })()
local passed = 0
local function check(value, message) assert(value, message) passed += 1 end
local profile = Rules.sanitizeProfile({ Coins = 1000 }, Config.Trails, Config.Cosmetics)
local items = {} for _, definition in ipairs(Config.Cosmetics) do items[definition.id] = definition end
Styles.sync(p, profile, {})
check(p:GetAttribute("AuraEquipped") == "NoAura" and p:GetAttribute("TitleEquipped") == "NoTitle", "new player has empty cosmetic slots")
check(not Styles.apply(p, profile, {}, "Runner") and not character:FindFirstChild("RiftCosmetics"), "unequipped creates no extra geometry")
Rules.purchaseCosmetic(profile, items.RiftSparks, {})
Rules.purchaseCosmetic(profile, items.NightWanderer, {})
Styles.sync(p, profile, {})
local model = Styles.apply(p, profile, {}, "Runner")
check(model and model.StyleTitle.TextLabel.Text == "NIGHT WANDERER", "equipped title has real overhead lettering")
local count = 0
for _, part in ipairs(model:GetDescendants()) do
	if part:IsA("BasePart") then
		count += 1
		check(not part.Anchored and part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery, "aura cannot alter hitbox, assembly mass or interactions")
		check(part:FindFirstChildOfClass("WeldConstraint").Part0 == root, "aura follows actual avatar root")
	end
end
check(count == 6 and root.Size == r.Vector3.new(2, 2, 1), "bounded spark count and unchanged root size")
local previous = model
model = Styles.apply(p, profile, {}, "Spectator")
check(not previous.Parent and model.Parent == character, "refresh replaces and cleans previous adornments")
model = Styles.apply(p, profile, {}, "Catcher")
local parts = 0 for _, item in ipairs(model:GetDescendants()) do if item:IsA("BasePart") then parts += 1 end end
check(parts == 6 and model.StyleTitle, "catcher retains title and aura with wider costume clearance")
Styles.apply(p, profile, {}, "Captured")
check(not character:FindFirstChild("RiftCosmetics"), "capture clears title and aura before cinematic")
profile.AuraEquipped, profile.TitleEquipped = "RoyalHalo", "ValleyRoyalty"
profile.CosmeticOwned.RoyalHalo, profile.CosmeticOwned.ValleyRoyalty = true, true
Styles.sync(p, profile, {})
check(p:GetAttribute("AuraEquipped") == "NoAura" and p:GetAttribute("TitleEquipped") == "NoTitle", "fake saved paid flags never replicate as available")
check(not Styles.apply(p, profile, {}, "Runner"), "unverified VIP produces no paid geometry")
Styles.sync(p, profile, { VIP = true })
model = Styles.apply(p, profile, { VIP = true }, "Spectator")
check(p:GetAttribute("AuraEquipped") == "RoyalHalo" and model.StyleTitle.TextLabel.Text == "VALLEY ROYALTY", "verified VIP restores preferences and royal title")
count = 0 for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then count += 1 end end
check(count == 16, "royal crown stays within sixteen cosmetic parts")
profile.Crossings, profile.Wins, profile.Tags = 10, 5, 10
Styles.sync(p, profile, {})
local unlocked = p:GetAttribute("CosmeticsUnlocked")
check(unlocked:find("ValleyBloom") and unlocked:find("RiftCrown") and unlocked:find("RiftHunter") and not unlocked:find("RoyalHalo"), "milestones derive from server progress and VIP stays separate")
print("PASS: " .. passed .. " actual cosmetic service, native adornment, role cleanup and entitlement assertions")
