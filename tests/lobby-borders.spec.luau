local r=require("@lune/roblox")
local host=require("./native-host")()
local barriers=host.workspace.RiftLobby.SpawnBarriers
local count=0
local function check(value,message) assert(value,message) count+=1 end
local function blocked(x,y,z)
	for _,p in ipairs(barriers:GetChildren()) do
		local delta=p.CFrame:PointToObjectSpace(r.Vector3.new(x,y,z))
		if p.CanCollide and math.abs(delta.X)<=p.Size.X/2+.001 and math.abs(delta.Y)<=p.Size.Y/2+.001 and math.abs(delta.Z)<=p.Size.Z/2+.001 then return true end
	end
	return false
end
for _,y in ipairs({32,56,84}) do
	for z=192,274,2 do
		check(blocked(53,y,z),"public east edge has a gap")
		if z<220 or z>236 then check(blocked(-53,y,z),"public west edge has a gap") end
	end
	for x=-52,52,2 do check(blocked(x,y,190),"public front edge has a gap") end
	for z=276,372,2 do
		check(blocked(-73,y,z) and blocked(73,y,z),"plaza side has a gap")
	end
	for x=-72,72,2 do check(blocked(x,y,374),"plaza rear has a gap") end
	for z=194,254,2 do check(blocked(219,y,z),"VIP activity outer edge has a gap") end
	for x=146,218,2 do check(blocked(x,y,192) and blocked(x,y,256),"VIP activity front/rear gap") end
	check(not blocked(-53,y,228),"dedicated parkour doorway must remain open")
	check(not blocked(-144,y,228) and not blocked(-105,y,274),"parkour must allow real falls on its outer edges")
end
for _,point in ipairs({r.Vector3.new(0,90,232),r.Vector3.new(0,90,324),r.Vector3.new(101,90,224),r.Vector3.new(182,90,224)}) do
	check(blocked(point.X,point.Y,point.Z),"protected lobby roof coverage")
end
check(not blocked(-105,90,228),"parkour stays outside the protected lobby roof")
-- The new doorway and furniture leave a full walking route to the activity.
for x=105,152,1 do
	for _,p in ipairs(host.workspace.RiftLobby:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			local q=p.CFrame:PointToObjectSpace(r.Vector3.new(x,31.5,224))
			check(not (math.abs(q.X)<p.Size.X/2+.8 and math.abs(q.Y)<p.Size.Y/2+1.2 and math.abs(q.Z)<p.Size.Z/2+.8),"VIP activity doorway blocked by "..p.Name)
		end
	end
end
print("PASS: "..count.." native lobby perimeter, roof, parkour opening and VIP doorway assertions")
