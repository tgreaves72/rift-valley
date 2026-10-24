-- Observe actual catcher physics in a separate Studio copy; never changes actors.
local Run,Rep=game:GetService("RunService"),game:GetService("ReplicatedStorage")
assert(Run:IsStudio())
local Http=game:GetService("HttpService")
local Config=require(Rep:WaitForChild("RiftShared").Config)
local tracked={}
Run.Heartbeat:Connect(function()
	if Rep:GetAttribute("Phase")~="Crossing" then return end
	local now=workspace:GetServerTimeNow()
	for _,model in ipairs(workspace:GetChildren()) do
		local stage=model:IsA("Model") and model:GetAttribute("CourseStage")
		if not stage or not string.match(model.Name,"^Rift Stalker ") then continue end
		local root=model:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		local record=tracked[model]
		if not record then
			record={at=now,position=root.Position}
			tracked[model]=record
		end
		if record.done then continue end
		local delta=root.Position-record.position
		local moved=Vector3.new(delta.X,0,delta.Z).Magnitude
		if moved>.5 or now-record.at>2 then
			record.done=true
			print("[RiftStartupEngine] "..Http:JSONEncode({version=Config.Version,testRevision=2,map=Rep:GetAttribute("MapId"),stage=stage,
				bot=model.Name,firstMoveSeconds=now-record.at,moved=moved,passed=moved>.5 and now-record.at<1}))
		end
	end
	for model in pairs(tracked) do if not model.Parent then tracked[model]=nil end end
end)
