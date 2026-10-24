local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Config, Rules = require(Shared.Config), require(Shared.Rules)
local Styles = {}

function Styles.sync(player, profile, entitlements)
	local unlocked, equipped = {}, { Aura = "NoAura", Title = "NoTitle", Skin = "DefaultSkin", Victory = "DefaultVictory" }
	for _, definition in ipairs(Config.Cosmetics) do
		if Rules.cosmeticAvailable(profile, definition, entitlements) then
			table.insert(unlocked, definition.id)
			if profile[definition.slot .. "Equipped"] == definition.id then equipped[definition.slot] = definition.id end
		end
	end
	player:SetAttribute("CosmeticsUnlocked", table.concat(unlocked, ","))
	for slot, id in pairs(equipped) do player:SetAttribute(slot .. "Equipped", id) end
end

local function ornament(model, root, name, size, offset, color, wedge)
	local part = Instance.new(wedge and "WedgePart" or "Part")
	part.Name, part.Size, part.CFrame = name, size, root.CFrame * offset
	part.Color, part.Material, part.Transparency = color, Enum.Material.Neon, .15
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow, part.Massless = false, false, false, false, true
	part.CollisionGroup = "RiftCharacters"
	part.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = root, part, part
end

function Styles.apply(player, profile, entitlements, role)
	local character = player.Character
	if not character then return end
	local old = character:FindFirstChild("RiftCosmetics")
	if old then old:Destroy() end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not profile or role == "Captured" then return end
	local aura, title
	for _, definition in ipairs(Config.Cosmetics) do
		if Rules.cosmeticAvailable(profile, definition, entitlements) then
			if definition.slot == "Aura" and profile.AuraEquipped == definition.id and definition.shape then aura = definition end
			if definition.slot == "Title" and profile.TitleEquipped == definition.id and definition.text then title = definition end
		end
	end
	if not aura and not title then return end
	local model = Instance.new("Model")
	model.Name = "RiftCosmetics"
	if aura then
		local color = Color3.fromRGB(unpack(aura.rgb))
		local count = aura.shape == "Sparks" and 6 or (aura.shape == "Bloom" and 8 or 12)
		local radius = aura.shape == "Sparks" and 2.2 or (aura.shape == "Bloom" and 2.5 or 1.25)
		local y = aura.shape == "Sparks" and -.3 or (aura.shape == "Bloom" and -2.5 or 3)
		if role == "Catcher" then
			if aura.shape == "Sparks" or aura.shape == "Bloom" then radius += .8 else y += .8 end
		end
		for index = 1, count do
			local angle = index*math.pi*2/count
			local halo = aura.shape == "Halo" or aura.shape == "Crown"
			local size = halo and Vector3.new(.62, .12, .18) or Vector3.new(.3, .65, .3)
			local offset = CFrame.new(math.cos(angle)*radius, y + (halo and 0 or index%2*.3), math.sin(angle)*radius) * CFrame.Angles(0, -angle-math.pi/2, 0)
			ornament(model, root, aura.id, size, offset, color, not halo)
			if aura.shape == "Crown" and index%3 == 0 then
				ornament(model, root, "CrownPoint", Vector3.new(.35, .65, .35), CFrame.new(math.cos(angle)*radius, y+.35, math.sin(angle)*radius), color, true)
			end
		end
	end
	if title then
		local creature = character:FindFirstChild("RiftCatcherCreature")
		local head = creature and creature:FindFirstChild("Head") or character:FindFirstChild("Head") or root
		local badge = Instance.new("BillboardGui")
		badge.Name, badge.Adornee, badge.Size = "StyleTitle", head, UDim2.fromOffset(230, 28)
		badge.StudsOffset, badge.MaxDistance, badge.AlwaysOnTop = Vector3.new(0, 4.4, 0), 65, false
		local text = Instance.new("TextLabel")
		text.Size, text.BackgroundTransparency, text.Text = UDim2.fromScale(1, 1), 1, title.text
		text.Font, text.TextSize, text.TextColor3 = Enum.Font.GothamBold, 12, Color3.fromRGB(unpack(title.rgb))
		text.TextStrokeTransparency, text.Parent = .45, badge
		badge.Parent = model
	end
	model.Parent = character
	return model
end

return Styles
