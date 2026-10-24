-- Only server-created map mechanics can change collision or grant route boosts.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("RiftShared")
local Config, Rules = require(Shared.Config), require(Shared.Rules)
local Arena = workspace:WaitForChild("RiftArena")
local Templates = game:GetService("ServerStorage"):WaitForChild("RiftMechanics")
local function createService(targetArena)
local Arena = targetArena
local Courses = {}
local active, records, pickups = Arena:FindFirstChild("ActiveMechanics"), {}, {}

function Courses.activate(mapId)
	Courses.bind(Templates:WaitForChild(mapId):Clone())
end

function Courses.bind(model)
	if active then active:Destroy() end
	active = model
	active.Name, active.Parent = "ActiveMechanics", Arena
	records, pickups = {}, {}
	for _, group in ipairs(active:GetChildren()) do
		local stage = tonumber(group.Name)
		for _, part in ipairs(group:GetChildren()) do
			if not part:IsA("BasePart") then continue end
			if part.Name == "BonusCrystal" then
				pickups[stage] = pickups[stage] or {}
				table.insert(pickups[stage], { part = part, kind = "BonusCrystal" })
			elseif part.Name == "GroveBridge" or part.Name == "CrumbleTile" or part.Name == "CargoGate" then
				table.insert(records, { part = part, stage = stage, home = part.CFrame, color = part.Color, state = "Solid", phase = part.Position.Z*.07 })
			end
		end
	end
end

function Courses.interactions(stage) return pickups[stage] or {} end

function Courses.step(now, running)
	for _, record in ipairs(records) do
		local part = record.part
		if part.Name == "CargoGate" then
			part.CFrame = record.home + Vector3.new(running and math.sin(now*.7+record.phase)*5 or 0, 0, 0)
		elseif part.Name == "CrumbleTile" then
			if not running then
				record.state, part.CanCollide, part.Transparency, part.Color = "Solid", true, 0, record.color
			elseif record.state == "Warning" then
				part.Color = Color3.fromRGB(255, math.floor(150+80*math.abs(math.sin(now*12))), 89)
				if now >= record.at then
					record.state, record.at, part.CanCollide, part.Transparency = "Gone", now+3, false, .9
				end
			elseif record.state == "Gone" and now >= record.at then
				record.state, part.CanCollide, part.Transparency, part.Color = "Solid", true, 0, record.color
			end
		end
	end
end

function Courses.contact(position, stage, grounded, now)
	local boost = false
	for _, record in ipairs(records) do
		if record.stage == stage and Rules.onSurface(position, record.part, grounded) then
			if record.part.Name == "GroveBridge" then boost = true
			elseif record.part.Name == "CrumbleTile" and record.state == "Solid" then
				record.state, record.at = "Warning", now+1.1
			end
		end
	end
	return boost
end

return Courses
end

local Courses = createService(Arena)
Courses.new = createService
return Courses
