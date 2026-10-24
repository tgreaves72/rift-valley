local Rules = require("../src/shared/Rules")
local Config = require("../src/shared/Config")
local passed = 0
local function check(value, message)
	assert(value, message)
	passed += 1
end

check(Rules.isGoal(122, 1, 122), "north goal boundary")
check(not Rules.isGoal(121.9, 1, 122), "north goal stays outside")
check(Rules.isGoal(-122, -1, 122), "south goal boundary")
check(not Rules.isGoal(144, -1, 122), "starting deck never clears reversed goal")
check(Rules.inArena(78, 144, 78, 144), "spawn inside arena")
check(not Rules.inArena(79, 0, 78, 144), "side bounds")
check(not Rules.inArena(0, 170, 78, 144), "end bounds")
check(Rules.canDash(24, 4, 0, 24, 4), "exact dash cost and cooldown")
check(not Rules.canDash(23, 4, 0, 24, 4), "reject low stamina")
check(not Rules.canDash(100, 3.99, 0, 24, 4), "reject early dash")
local stamina, last = Rules.stepStamina(10, true, 1, 1, 0, Config)
check(stamina == 0 and last == 1, "stamina clamps at zero")
stamina = Rules.stepStamina(90, false, 1, 3, 1, Config)
check(stamina == 100, "regen clamps at maximum")
stamina = Rules.stepStamina(50, false, 0.2, 1.5, 1, Config)
check(stamina == 50, "regen waits after exertion")
check(Rules.canTag("Runner", "Crossing", 4.2, 3.2, 3, 2), "legal contact range")
check(not Rules.canTag("Escaped", "Crossing", 1, 0, 3, 2), "safe runner protected")
check(not Rules.canTag("Runner", "Ready", 1, 0, 3, 2), "ready phase protected")
check(not Rules.canTag("Runner", "Crossing", 4.21, 0, 3, 2), "tag range")
check(not Rules.canTag("Runner", "Crossing", 1, 0, 1, 2), "spawn grace")
check(not Rules.canTag("Runner", "Crossing", 1, 3.21, 3, 2), "vertical reach")
check(Rules.level(0) == 1 and Rules.level(100) == 2 and Rules.level(400) == 3, "XP levels")
local choices = { { id = "A", turns = 4 }, { id = "B", turns = 1 }, { id = "C", turns = 1 } }
check(Rules.selectCatcher(choices, 1) == "B", "fair catcher rotation")
check(Rules.selectCatcher(choices, 2) == "C", "tie selection")
check(Rules.selectCatcher({}, 1) == nil, "empty match")
local profile = Rules.sanitizeProfile({ Coins = -3, Wins = math.huge, XP = 0 / 0, Owned = { Violet = true, Invalid = true }, Equipped = "Invalid" }, Config.Trails)
check(profile.Coins == 0 and profile.Wins == 0 and profile.XP == 0, "corrupt numbers")
check(profile.Owned.None and profile.Owned.Violet and not profile.Owned.Invalid, "cosmetic allowlist")
check(profile.Equipped == "None", "unowned equip rejected")
check(not Rules.purchase(profile, Config.Trails[2]), "insufficient coins")
profile.Coins = 200
local ok = Rules.purchase(profile, Config.Trails[2])
check(ok and profile.Coins == 20 and profile.Equipped == "Mint", "atomic purchase")
Rules.purchase(profile, Config.Trails[2])
check(profile.Coins == 20, "owned trail equip never charges twice")
check(not Rules.purchase(profile, nil), "unknown trail rejected")

-- Exercise independent onward courses and infection.
local roles = { A = "Runner", B = "Runner", C = "Catcher" }
for stage, course in ipairs(Config.Courses) do
	check(Rules.inCourse(course.x, course.z - 144, course, Config.StartZ), "course start contained " .. stage)
	check(Rules.courseFinish("Runner", "Crossing", course.x, course.z - 144, stage, Config) == nil, "entry is not finish " .. stage)
	if stage == 2 then
		check(Rules.canTag(roles.B, "Crossing", 4, 0, 10, 0), "second course legal conversion")
		roles.B = "Catcher"
	end
	check(Rules.courseFinish(roles.A, "Crossing", course.x, course.z + 122, stage, Config) == (stage == 5 and 0 or stage + 1), "finish advances or escapes " .. stage)
	check(Rules.courseFinish("Catcher", "Crossing", course.x, course.z + 122, stage, Config) == nil, "catcher cannot finish " .. stage)
	check(Rules.courseFinish("Runner", "Ready", course.x, course.z + 122, stage, Config) == nil, "ready cannot finish " .. stage)
	check(Rules.courseFinish("Runner", "Crossing", course.x + course.halfWidth + .1, course.z + 122, stage, Config) == nil, "outside course cannot finish " .. stage)
	check(Rules.courseAt(course.x, course.z, Config.Courses, Config.StartZ) == stage, "capture finds correct course " .. stage)
	if stage == 5 then roles.A = "Escaped" end
end
check(roles.A == "Escaped" and roles.B == "Catcher", "survivor and converted roles stay distinct")
local allocation = Rules.chaserAllocation({ 1, 1, 1, 1, 1 }, Config.Courses, 12)
local total = 0
for stage, count in ipairs(allocation) do total += count check(count >= 1 and count <= Config.Courses[stage].bots, "split pack keeps a chaser in each course") end
check(total == 12 and allocation[5] == 6, "split group respects budget and final escalation")
allocation = Rules.chaserAllocation({ 0, 0, 0, 0, 1 }, Config.Courses, 12)
check(allocation[1] == 0 and allocation[5] == 6, "empty course retires NPCs, final course gets six")
for stage = 1, 5 do
	local counts = {} counts[stage] = 1
	check(Rules.chaserAllocation(counts, Config.Courses, 12)[stage] == stage + 1, "solo chasers escalate " .. stage)
end
check(Rules.chooseMap(Config.Maps, { a = "SunsetRuins", b = "SunsetRuins", c = "CrystalGrove" }, "SunsetRuins", 1) == "SunsetRuins", "majority wins even if previous map")
check(Rules.chooseMap(Config.Maps, {}, "CrystalGrove", 1) == "SunsetRuins", "no-vote rotation avoids previous map")
check(Rules.chooseMap(Config.Maps, { a = "CrystalGrove", b = "NeonHarbor" }, "CrystalGrove", 1) == "NeonHarbor", "ties avoid previous map")
check(Rules.chooseMap(Config.Maps, { a = "Invalid" }, nil, 3) == "NeonHarbor", "invalid votes never select absent map")
check(Rules.interactionAllowed("Runner", "Crossing", true, 5, 4), "runner pickup range")
check(Rules.interactionAllowed("Catcher", "Crossing", true, 5, 4), "catchers can recharge")
check(not Rules.interactionAllowed("Runner", "Ready", true, 1, 1), "no pre-round pickup")
check(not Rules.interactionAllowed("Spectator", "Crossing", false, 1, 1), "spectator interaction denied")
check(not Rules.interactionAllowed("Runner", "Crossing", true, 5.6, 1), "distance rejected")
check(not Rules.interactionAllowed("Runner", "Crossing", true, 1, 6.1), "height rejected")
check(Rules.rewardCoins(12, {}) == 12 and Rules.rewardCoins(12, { DoubleCoins = true }) == 24, "double coins affects reward only")
profile = Rules.sanitizeProfile({ Coins = 400, Owned = { Gold = true, Aurora = true, Mint = true }, Equipped = "Aurora" }, Config.Trails)
check(not profile.Owned.Gold and not profile.Owned.Aurora and profile.Owned.Mint, "premium ownership never trusted from profile")
check(profile.Equipped == "Aurora", "premium preference persists without storing entitlement")
check(not Rules.purchase(profile, Config.Trails[5], {}), "premium trail denied without pass")
check(not Rules.purchase(profile, Config.Trails[6], { VIP = true }), "wrong pass denied")
check(Rules.purchase(profile, Config.Trails[5], { VIP = true }) and profile.Coins == 400, "VIP equips gold without coins")
check(Rules.purchase(profile, Config.Trails[6], { StylePack = true }) and profile.Equipped == "Aurora", "style pack grants correct trail")
check(Rules.initialCatcherCount(2, 8) == 1 and Rules.initialCatcherCount(15, 8) == 1, "small match starts with one catcher")
check(Rules.initialCatcherCount(16, 8) == 2 and Rules.initialCatcherCount(30, 8) == 3, "catchers scale with larger lobbies")
check(Rules.initialCatcherCount(1, 8) == 0, "solo practice uses bots instead of a human catcher")
check(Rules.canGrab("Runner", "Crossing", 0, 0, -4, 3, 2), "front reach contact")
check(not Rules.canGrab("Runner", "Crossing", 0, 0, 1, 3, 2), "no catch from behind")
check(not Rules.canGrab("Runner", "Crossing", 3.2, 0, -1, 3, 2), "side reach bound")
check(not Rules.canGrab("Runner", "Crossing", 0, 4, -1, 3, 2), "jump above hands avoids grab")
check(not Rules.canGrab("Runner", "Crossing", 3, 0, -4, 3, 2), "diagonal radius prevents distant catch")
local items = {}
for _, definition in ipairs(Config.Cosmetics) do items[definition.id] = definition end
profile = Rules.sanitizeProfile({ Coins = 600, CosmeticOwned = { RoyalHalo = true, RiftCrown = true, Unknown = true }, AuraEquipped = "RiftCrown", TitleEquipped = "Unknown" }, Config.Trails, Config.Cosmetics)
check(profile.AuraEquipped == "NoAura" and profile.TitleEquipped == "NoTitle", "locked/unknown cosmetic preferences rejected")
check(not profile.CosmeticOwned.RoyalHalo and not profile.CosmeticOwned.RiftCrown and not profile.CosmeticOwned.Unknown, "paid, goal and unknown ownership flags not trusted")
check(Rules.purchaseCosmetic(profile, items.RiftSparks, {}) and profile.Coins == 480 and profile.AuraEquipped == "RiftSparks", "coin cosmetic purchase and equip are atomic")
check(Rules.purchaseCosmetic(profile, items.RiftSparks, {}) and profile.Coins == 480, "equipping a purchased cosmetic never charges again")
check(Rules.purchaseCosmetic(profile, items.MoonHalo, {}) and profile.Coins == 0 and profile.AuraEquipped == "MoonHalo", "second aura replaces the slot")
check(not Rules.purchaseCosmetic(profile, items.NightWanderer, {}) and profile.Coins == 0, "unaffordable title rejected without spending")
check(not Rules.purchaseCosmetic(profile, items.RiftCrown, {}) and profile.AuraEquipped == "MoonHalo", "milestone cannot be bought around")
profile.Wins = 5
check(Rules.purchaseCosmetic(profile, items.RiftCrown, {}) and profile.AuraEquipped == "RiftCrown" and profile.Coins == 0, "five wins unlock crown without a charge")
check(Rules.purchaseCosmetic(profile, items.ValleySurvivor, {}) and profile.TitleEquipped == "ValleySurvivor" and profile.AuraEquipped == "RiftCrown", "title and aura equip independently")
check(not Rules.purchaseCosmetic(profile, items.ValleyBloom, {}), "course goal remains locked until ten")
profile.Crossings = 10
check(Rules.purchaseCosmetic(profile, items.ValleyBloom, {}) and profile.AuraEquipped == "ValleyBloom", "ten crossings unlock bloom")
check(not Rules.purchaseCosmetic(profile, items.RiftHunter, {}), "hunter title requires tags")
profile.Tags = 10
check(Rules.purchaseCosmetic(profile, items.RiftHunter, {}) and profile.TitleEquipped == "RiftHunter", "tag goal unlocks hunter title")
check(not Rules.purchaseCosmetic(profile, items.RoyalHalo, {}) and not Rules.purchaseCosmetic(profile, items.ValleyRoyalty, {}), "VIP cosmetics require verified entitlement")
check(Rules.purchaseCosmetic(profile, items.RoyalHalo, { VIP = true }) and not profile.CosmeticOwned.RoyalHalo, "VIP equips without storing entitlement")
check(Rules.purchaseCosmetic(profile, items.ValleyRoyalty, { VIP = true }) and profile.TitleEquipped == "ValleyRoyalty", "VIP title equips with entitlement")
profile = Rules.sanitizeProfile(profile, Config.Trails, Config.Cosmetics)
check(profile.AuraEquipped == "RoyalHalo" and profile.CosmeticOwned.RiftSparks and not profile.CosmeticOwned.RoyalHalo, "save preserves paid preference and actual coin ownership")
check(not Rules.cosmeticAvailable(profile, items.RoyalHalo, {}), "saved paid preference cannot grant access")
check(Rules.purchaseCosmetic(profile, items.NoAura, {}) and profile.AuraEquipped == "NoAura", "free unequip works")
check(not Rules.purchaseCosmetic(profile, nil, {}), "unknown cosmetic rejected")
check(Rules.botKind(1, 2) == "Bruiser" and Rules.botKind(2, 4) == "Bruiser", "early courses introduce bruisers only")
check(Rules.botKind(3, 2) == "Stalker" and Rules.botKind(3, 1) == "Bruiser", "later courses mix distinct archetypes")
check(Rules.botSpeed("Bruiser", 1) > Config.WalkSpeed and Rules.botSpeed("Bruiser",1) < Config.SprintSpeed, "opening pursuit catches walking but permits sprint escapes")
for stage = 2, 5 do
	check(Rules.botSpeed("Bruiser", stage) >= Config.WalkSpeed+8 and Rules.botSpeed("Bruiser",stage) < Config.SprintSpeed, "later bruisers close a walking runner's lead")
	check(Rules.botSpeed("Stalker", stage) >= Rules.botSpeed("Bruiser",stage) and Rules.botSpeed("Stalker", stage) < Config.SprintSpeed, "stalkers pressure tired runners while sprint can pull ahead")
end
check(not Rules.canGrab("Runner", "Crossing", 2.5, 0, -2, 3, 2, "Stalker") and Rules.canGrab("Runner", "Crossing", 2.5, 0, -2, 3, 2, "Bruiser"), "stalker has a narrower grab than the bruiser")
print("PASS: " .. passed .. " rule and match assertions")
