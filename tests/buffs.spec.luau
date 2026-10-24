local fs,luau,r=require("@lune/fs"),require("@lune/luau"),require("@lune/roblox")
local host=require("./native-host")()
local count,models,preview=0,{},{}
local function check(value,message) assert(value,message) count+=1 end
for _,obj in ipairs(host.workspace:GetDescendants()) do
	if obj:IsA("Model") and obj.Name=="BuffVisual" then
		table.insert(models,obj)
		local kind=obj.Parent.HoverIcon.Kind.Value
		check(obj.PrimaryPart and obj.PrimaryPart.Parent==obj,"visual pivot points to its own cloned core")
		check(obj.PrimaryPart.BuffGlow.Brightness>1 and obj.PrimaryPart.BuffGlow.Range<=12 and not obj.PrimaryPart.BuffGlow.Shadows,"native buff emits bounded visible glow in edit mode")
		local parts,cells,arrows=0,0,0
		local geometry={}
		for _,part in ipairs(obj:GetDescendants()) do
			check(not part:IsA("BillboardGui") and not part:IsA("SurfaceGui") and not part:IsA("TextLabel"),"buff is entirely 3D geometry without labels")
			if part:IsA("BasePart") then
				parts+=1
				check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,"buff cannot alter collisions, navigation or collection range")
				if part.Name=="EnergyCell" then cells+=1 end
				if part.Name=="DashChevron" then arrows+=1 end
				if part.Transparency<1 then
					local vertices={}
					for _,z in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,x in ipairs({-1,1}) do
						local point=part.CFrame:PointToWorldSpace(r.Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))-obj.PrimaryPart.Position
						table.insert(vertices,{point.X,point.Y,point.Z})
					end end end
					table.insert(geometry,{name=part.Name,vertices=vertices,color={part.Color.R*255,part.Color.G*255,part.Color.B*255},neon=part.Material==r.Enum.Material.Neon})
				end
			end
		end
		check(parts<=26 and (kind=="Stamina" and cells==6 or kind=="Dash" and arrows==4),"bounded solid battery and double-chevron silhouettes")
		preview[kind]=geometry
	end
end
check(#models==12,"all twelve live resource pickups have native 3D models")
fs.writeFile("assets/buff-models-geometry.json",require("@lune/serde").encode("json",preview,true))
local votes,voteGeometry={},{}
for _,id in ipairs({"CrystalGrove","SunsetRuins","NeonHarbor"}) do
	local plate=host.workspace.RiftLobby:FindFirstChild("Vote_"..id)
	local model=plate:FindFirstChild("MapVoteVisual")
	check(model and model.PrimaryPart and model.PrimaryPart.Parent==model and model.MapId.Value==id,"map icon has its own pivot and map identity")
	check(model.PrimaryPart.VoteGlow.Range==14 and not model.PrimaryPart.VoteGlow.Shadows,"map icon emits a bounded local glow")
	check(plate.MapName.Adornee==model.PrimaryPart and plate.MapName.Title.Text==({CrystalGrove="Crystal Grove",SunsetRuins="Sunset Ruins",NeonHarbor="Neon Harbor"})[id] and plate.MapName.Title.FontFace.Family=="rbxasset://fonts/families/FredokaOne.json","each named map has a small pole-free label attached to its emblem")
	local geometry,parts={},0
	for _,part in ipairs(model:GetDescendants()) do
		check(not part:IsA("BillboardGui") and not part:IsA("SurfaceGui") and not part:IsA("TextLabel"),"map vote emblems use real geometry without sign text")
		if part:IsA("BasePart") then
			parts+=1
			check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,"map emblem cannot block a player or affect plate contact")
			if part.Transparency<1 then
				local vertices={}
				for _,z in ipairs({-1,1}) do for _,y in ipairs({-1,1}) do for _,x in ipairs({-1,1}) do
					local point=part.CFrame:PointToWorldSpace(r.Vector3.new(x*part.Size.X/2,y*part.Size.Y/2,z*part.Size.Z/2))-model.PrimaryPart.Position
					table.insert(vertices,{point.X,point.Y,point.Z})
				end end end
				table.insert(geometry,{name=part.Name,class=part.ClassName,vertices=vertices,color={part.Color.R*255,part.Color.G*255,part.Color.B*255},neon=part.Material==r.Enum.Material.Neon})
			end
		end
	end
	check(parts<=30 and model.PrimaryPart.Position.Y-plate.Position.Y>8,"compact floating map icons sit above the plate")
	voteGeometry[id]=geometry
	table.insert(votes,{model=model,plate=plate,base=plate.CFrame})
end
for _,part in ipairs(host.workspace.RiftLobby:GetDescendants()) do
	if part:IsA("TextLabel") then check(not part.Text:find("STEP TO VOTE",1,true),"old map-vote boards are removed") end
end
fs.writeFile("assets/map-vote-icons-geometry.json",require("@lune/serde").encode("json",voteGeometry,true))
local p=host.wrap(r.Instance.new("Player"))
local near=models[1]
local root={Position=near.PrimaryPart.Position}
rawset(p,"Character",{FindFirstChild=function() return root end})
local now=1000
local rendered={Connect=function(self,fn) self.fn=fn end}
rawset(host.workspace,"GetServerTimeNow",function() return now end)
local env={workspace=host.workspace,CFrame=r.CFrame,Vector3=r.Vector3,task={defer=function(fn,...) fn(...) end},
	game={GetService=function(_,name) return name=="Players" and {LocalPlayer=p} or (name=="ReplicatedStorage" and host.replicated or {RenderStepped=rendered}) end}}
luau.load(fs.readFile("src/client/BuffEffects.client.luau"),{environment=env})()
local base=near.PrimaryPart.Position
rendered.fn()
now+=.1 rendered.fn()
check((near.PrimaryPart.Position-base).Magnitude<=.301,"visual animation bobs around a fixed anchor")
check(near.PrimaryPart.CFrame.LookVector:Dot(r.Vector3.new(0,0,-1))>.999,"resource icons keep a fixed orientation")
check(near.Parent.Position==base,"animation never moves the authoritative collection point")
local kind=near.Parent.HoverIcon.Kind.Value
p:SetAttribute(kind.."BuffReadyAt",now+7)
now+=.1 rendered.fn()
check(math.abs(near.PrimaryPart.BuffGlow.Brightness-.2)<.001,"consumed resource dims during its per-player cooldown")
now+=7.1 rendered.fn()
check(near.PrimaryPart.BuffGlow.Brightness>1,"ready resource restores its glow")
local distant
for _,model in ipairs(models) do if (model.PrimaryPart.Position-root.Position).Magnitude>100 then distant=model break end end
local distantFrame=distant.PrimaryPart.CFrame
now+=.1 rendered.fn()
check(distant.PrimaryPart.CFrame==distantFrame,"distant buffs do not receive animation updates")
local emblem=votes[1]
local iconBase=emblem.model.PrimaryPart.CFrame
root.Position=iconBase.Position
p:SetAttribute("MapVote","CrystalGrove")
p:SetAttribute("StaminaBuffReadyAt",now+7)
now+=.1 rendered.fn()
check(emblem.model.PrimaryPart.VoteGlow.Brightness==2.25,"chosen map emblem brightens for the voting player")
check((emblem.model.PrimaryPart.Position-iconBase.Position).Magnitude<=.301 and emblem.plate.CFrame==emblem.base,"map symbol gently bobs without moving its pressure plate")
check(emblem.model.PrimaryPart.CFrame.LookVector:Dot(iconBase.LookVector)>.9999,"map emblems never rotate")
for _,part in ipairs(emblem.model:GetDescendants()) do
	if part:IsA("BasePart") and part.Transparency<1 then check(part.LocalTransparencyModifier==0,"resource cooldowns cannot dim map-vote icons") end
end
local coins,coinPreview={},nil
for _,obj in ipairs(host.workspace:GetDescendants()) do
	if obj:IsA("Model") and obj.Name=="CoinVisual" then
		table.insert(coins,obj)
		check(obj.PrimaryPart and obj.PrimaryPart.Parent==obj and obj.PrimaryPart.CoinGlow.Range==9,"native coin retains its own lit pivot")
		local geometry,parts,cylinders={},0,0
		for _,part in ipairs(obj:GetDescendants()) do
			check(not part:IsA("BillboardGui") and not part:IsA("TextLabel"),"coin uses solid geometry without a floating text label")
			if part:IsA("BasePart") then
				parts+=1
				check(not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Anchored,"coin is decorative and cannot alter movement or collection distance")
				if part:IsA("Part") and part.Shape==r.Enum.PartType.Cylinder then cylinders+=1 end
				if part.Transparency<1 then
					table.insert(geometry,{name=part.Name,size={part.Size.X,part.Size.Y,part.Size.Z},cylinder=part:IsA("Part") and part.Shape==r.Enum.PartType.Cylinder,
						frame={part.CFrame:GetComponents()},origin={obj.PrimaryPart.Position.X,obj.PrimaryPart.Position.Y,obj.PrimaryPart.Position.Z},color={part.Color.R*255,part.Color.G*255,part.Color.B*255}})
				end
			end
		end
		check(parts==14 and cylinders==5,"coin has bounded geometry with round edge and faces")
		coinPreview=coinPreview or geometry
	end
end
check(#coins==18,"all eight regular and ten bonus pickups have visible 3D coins")
fs.writeFile("assets/coin-model-geometry.json",require("@lune/serde").encode("json",coinPreview,true))
local coin=coins[1]
local coinFrame,anchorFrame=coin.PrimaryPart.CFrame,coin.Parent.CFrame
root.Position=coinFrame.Position now+=.1 rendered.fn()
check(coin.PrimaryPart.CFrame.LookVector:Dot(coinFrame.LookVector)>.9999 and coin.Parent.CFrame==anchorFrame,"coins stay upright and leave server collection anchors stationary")
host.replicated.RiftAction.OnClientEvent:Fire("Crystal",coin.Parent)
for _,part in ipairs(coin:GetDescendants()) do
	if part:IsA("BasePart") and part.Transparency<1 then check(part.LocalTransparencyModifier==1,"confirmed coin pickup hides every visible coin part locally") end
end
check(not coin.PrimaryPart.CoinGlow.Enabled and coins[2].PrimaryPart.CoinGlow.Enabled,"collected coin extinguishes only its own light")
print("PASS: "..count.." native 3D buff geometry, glow, noncollision, animation and cooldown assertions")
