-- Actual native collision footprints, support and a conservative walking search.
-- This proves supported, clear corridors; it does not emulate Roblox navmeshes,
-- actual jumping, latency or humanoid turning.
local r=require("@lune/roblox")
local Config,Rules=require("../src/shared/Config"),require("../src/shared/Rules")
local host=require("./native-host")()
local arena=host.workspace.RiftArena
local storage=host.wrap(host.model:GetService("ServerStorage"))
local count,summary=0,{}
local stationOptions,invalidStations={},{}
local function check(value,message) assert(value,message) count+=1 end
local function collect(parent,result)
	for _,part in ipairs(parent:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then table.insert(result,part) end end
end
for _,theme in ipairs(Config.Maps) do
	for stage,course in ipairs(Config.Courses) do
		local base={}
		if stage==1 then
			for _,part in ipairs(arena:GetChildren()) do if part:IsA("BasePart") and part.CanCollide then table.insert(base,part) end end
			collect(storage.RiftMaps:FindFirstChild(theme.id),base)
		else collect(arena.ChaseCourses:FindFirstChild("Course_"..stage),base) end
		local themeParts={}
		collect(storage.RiftMechanics:FindFirstChild(theme.id):FindFirstChild(tostring(stage)),themeParts)
		local phases=theme.id=="NeonHarbor" and {-5,0,5} or {0}
		for _,motion in ipairs(phases) do
			local floors,obstacles={},{}
			for _,part in ipairs(base) do
				if math.abs(part.Position.Y+part.Size.Y/2)<.01 and part.Size.Y>=3.9 then table.insert(floors,part)
				elseif part.Position.Y+part.Size.Y/2>.2 and part.Position.Y-part.Size.Y/2<6 then table.insert(obstacles,{part=part,offset=0}) end
			end
			for _,part in ipairs(themeParts) do if part.Position.Y+part.Size.Y/2>.2 and part.Position.Y-part.Size.Y/2<6 then table.insert(obstacles,{part=part,offset=part.Name=="CargoGate" and motion or 0}) end end
			local floorBounds,blockBounds={},{}
			for _,part in ipairs(floors) do table.insert(floorBounds,{x=part.Position.X,z=part.Position.Z,hx=part.Size.X/2,hz=part.Size.Z/2}) end
			for _,entry in ipairs(obstacles) do
				local part=entry.part
				local right,forward=part.CFrame.RightVector,part.CFrame.LookVector
				table.insert(blockBounds,{x=part.Position.X+entry.offset,z=part.Position.Z,rx=right.X,rz=right.Z,fx=forward.X,fz=forward.Z,hx=part.Size.X/2+1.8,hz=part.Size.Z/2+1.8})
			end
			local cache={}
			local function open(x,z)
				local key=x..":"..z
				if cache[key]~=nil then return cache[key] end
				local px,pz=x+course.x,z+course.z
				for _,corner in ipairs({{-1.6,-1.6},{1.6,-1.6},{-1.6,1.6},{1.6,1.6}}) do
					local supported=false
					for _,floor in ipairs(floorBounds) do
						if math.abs(px+corner[1]-floor.x)<=floor.hx and math.abs(pz+corner[2]-floor.z)<=floor.hz then supported=true break end
					end
					if not supported then cache[key]=false return false end
				end
				for _,obstacle in ipairs(blockBounds) do
					local dx,dz=px-obstacle.x,pz-obstacle.z
					if math.abs(dx*obstacle.rx+dz*obstacle.rz)<obstacle.hx and math.abs(dx*obstacle.fx+dz*obstacle.fz)<obstacle.hz then cache[key]=false return false end
				end
				cache[key]=true return true
			end
			local queue,head,visited={{0,-144,0}},1,{["0:-144"]=true}
			for index=1,course.bots do
				local x,z=Rules.catcherStation(stage,index)
				local key=stage..":"..index
				if not stationOptions[key] then
					stationOptions[key]={}
					for dx=-12,12,2 do for dz=-12,12,2 do table.insert(stationOptions[key],{x=x+dx,z=z+dz,distance=dx*dx+dz*dz}) end end
				end
				for i=#stationOptions[key],1,-1 do local p=stationOptions[key][i] if math.abs(p.x)>course.halfWidth-2 or not open(p.x,p.z) then table.remove(stationOptions[key],i) end end
				if not (z>-Config.StartZ and open(x,z)) then invalidStations[key]=true end
			end
			local distance
			while head<=#queue do
				local current=queue[head] head+=1
				if current[2]==124 then distance=current[3] break end
				for _,delta in ipairs({{2,0},{-2,0},{0,2},{0,-2}}) do
					local x,z=current[1]+delta[1],current[2]+delta[2]
					local key=x..":"..z
					if math.abs(x)<=course.halfWidth-2 and z>=-144 and z<=124 and not visited[key] then
						visited[key]=true
						if open(x,z) then table.insert(queue,{x,z,current[3]+2}) end
					end
				end
			end
			check(distance~=nil,"body-width supported walking path: "..theme.id.." / "..stage.." / cargo "..motion)
			table.insert(summary,{mapId=theme.id,stage=stage,cargoOffset=motion,walkingDistance=distance})
			if stage>1 then
				local straight=false
				for x=-course.halfWidth+2,course.halfWidth-2,2 do
					local clear=true
					for z=-122,122,2 do if not open(x,z) then clear=false break end end
					if clear then straight=true break end
				end
				check(not straight,"bonus course cannot be walked straight through by hugging an edge")
			end
		end
	end
end
for key in pairs(invalidStations) do
	table.sort(stationOptions[key],function(a,b) return a.distance<b.distance end)
	print("Station "..key.." nearest common clear location:",stationOptions[key][1])
end
check(next(invalidStations)==nil,"all interception stations must be clear in every biome and cargo phase")
require("@lune/fs").writeFile("assets/route-walkability.json",require("@lune/serde").encode("json",summary,true))
print("PASS: "..count.." native supported-path and no-straight-bypass checks across all themes and cargo extremes")
