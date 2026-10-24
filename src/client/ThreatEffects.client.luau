-- The floor outline comes from the same contact limits as the server hit test.
local Rep=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Shared=Rep:WaitForChild("RiftShared")
local Rules,Config=require(Shared.Rules),require(Shared.Config)
local Remote=Rep:WaitForChild("RiftAction")
local warnings={}
local function clear(model)
 local record=warnings[model]
 if record then record.folder:Destroy() warnings[model]=nil end
end
local function edge(parent,name,a,b,color)
 local part=Instance.new("Part")
 part.Name,part.Size=name,Vector3.new(.2,.07,(b-a).Magnitude)
 part.Material,part.Color,part.Transparency=Enum.Material.Neon,color,.15
 part.Anchored,part.CanCollide,part.CanTouch,part.CanQuery,part.CastShadow=true,false,false,false,false
 part.Parent=parent
 return {part=part,a=a,b=b}
end
local function position(record)
 local root=record.root
 local rayParams=RaycastParams.new()
 rayParams.FilterType,rayParams.FilterDescendantsInstances=Enum.RaycastFilterType.Exclude,{root.Parent}
 local ground=workspace:Raycast(root.Position+Vector3.new(0,1,0),Vector3.new(0,-12,0),rayParams)
 local height=ground and ground.Position.Y+.08 or root.Position.Y-2.8
 local forward=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
 if forward.Magnitude<.1 then return end
 local pose=CFrame.lookAt(Vector3.new(root.Position.X,height,root.Position.Z),Vector3.new(root.Position.X,height,root.Position.Z)+forward)
 for _,line in ipairs(record.edges) do
  local a,b=pose:PointToWorldSpace(line.a),pose:PointToWorldSpace(line.b)
  line.part.CFrame=CFrame.lookAt((a+b)/2,b)
 end
end
Remote.OnClientEvent:Connect(function(action,payload)
 if action=="WarningEnd" then clear(payload) return end
 if action~="GrabWarning" and action~="ChargeWarning" then return end
 if type(payload)~="table" then return end
 local model=payload.model
 local root=model and model.PrimaryPart
 local camera=workspace.CurrentCamera
 if not root or not model.Parent or (camera and (camera.CFrame.Position-root.Position).Magnitude>90) then return end
 clear(model)
 local kind=model:GetAttribute("Archetype")
 local color=action=="ChargeWarning" and Color3.fromRGB(107,226,255) or Color3.fromRGB(255,194,102)
 local folder=Instance.new("Folder")
 folder.Name,folder.Parent="RiftWarning",workspace
 local gui=Instance.new("BillboardGui")
 gui.Adornee,gui.Size,gui.StudsOffset=root,UDim2.fromOffset(42,48),Vector3.new(0,6.5,0)
 gui.MaxDistance,gui.AlwaysOnTop,gui.Parent=65,false,folder
 local label=Instance.new("TextLabel")
 label.Size,label.BackgroundTransparency,label.Text=UDim2.fromScale(1,1),1,"!"
 label.Font,label.TextSize,label.TextColor3,label.TextStrokeTransparency,label.Parent=Enum.Font.FredokaOne,40,color,.2,gui
 local highlight=Instance.new("Highlight")
 highlight.Adornee,highlight.FillColor,highlight.OutlineColor=model,color,color
 highlight.FillTransparency,highlight.OutlineTransparency,highlight.DepthMode,highlight.Parent=.88,.1,Enum.HighlightDepthMode.Occluded,folder
 local marker=Instance.new("Model") marker.Name,marker.Parent="ReachWarning",folder
 local bounds=Rules.grabBounds(kind)
 marker:SetAttribute("HalfWidth",bounds.width) marker:SetAttribute("ContactRadius",bounds.radius) marker:SetAttribute("Depth",bounds.depth)
 local polygon=Rules.grabOutline(kind)
 local edges={}
 for index,a in ipairs(polygon) do
  local b=polygon[index%#polygon+1]
  table.insert(edges,edge(marker,"ContactEdge_"..index,Vector3.new(a.x,0,a.z),Vector3.new(b.x,0,b.z),color))
 end
 if action=="ChargeWarning" then
  local reach=41*Config.ChargeDuration+bounds.depth
  for _,side in ipairs({-1,1}) do table.insert(edges,edge(marker,"ChargeRail",Vector3.new(side*bounds.width,0,0),Vector3.new(side*bounds.width,0,-reach),color)) end
  table.insert(edges,edge(marker,"ChargeEnd",Vector3.new(-bounds.width,0,-reach),Vector3.new(bounds.width,0,-reach),color))
 else
  local distance=Config.GrabLungeDistance
  for _,side in ipairs({-1,1}) do table.insert(edges,edge(marker,"LungeChevron",Vector3.new(side*.8,0,-bounds.depth-distance+1),Vector3.new(0,0,-bounds.depth-distance),color)) end
 end
 local record={folder=folder,root=root,edges=edges,untilAt=workspace:GetServerTimeNow()+math.clamp(payload.duration or .75,.1,2)}
 warnings[model]=record position(record)
 local sound=Instance.new("Sound")
 sound.SoundId,sound.Volume,sound.PlaybackSpeed="rbxasset://sounds/oof.ogg",.25,.6
 sound.RollOffMaxDistance,sound.RollOffMinDistance,sound.Parent=65,8,root
 sound:Play() Debris:AddItem(sound,2)
end)
Run.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow()
 for model,record in pairs(warnings) do
  if not model.Parent or not record.root.Parent or now>=record.untilAt then clear(model)
  else position(record) end
 end
end)

