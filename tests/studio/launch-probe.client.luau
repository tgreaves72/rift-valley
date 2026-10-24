-- Passive observations in local test copies. Never changes gameplay or grants perks.
local Run = game:GetService("RunService")
assert(Run:IsStudio())
local Rep, Players = game:GetService("ReplicatedStorage"), game:GetService("Players")
local Http, Sounds = game:GetService("HttpService"), game:GetService("SoundService")
local Log = game:GetService("LogService")
local player = Players.LocalPlayer
local run = Rep:WaitForChild("EngineMPRun").Value
local frames, elapsed, slowFrames = 0, 0, 0
local errors, observed = {}, {}
local function report(kind, data)
	print("[RiftLaunchEngine] " .. Http:JSONEncode({run=run,event=kind,slot=player:GetAttribute("EngineSlot"),data=data}))
end
Log.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and #errors < 20 then
		table.insert(errors, string.sub(message, 1, 500))
	end
end)
Run.RenderStepped:Connect(function(dt)
	frames += 1 elapsed += dt
	if dt > 1/30 then slowFrames += 1 end
	if elapsed >= 20 then
		report("PERFORMANCE", {fps=frames/elapsed,frames=frames,slowFrames=slowFrames,
			phase=Rep:GetAttribute("Phase"),map=Rep:GetAttribute("MapId"),
			viewport={workspace.CurrentCamera.ViewportSize.X,workspace.CurrentCamera.ViewportSize.Y}})
		frames,elapsed,slowFrames=0,0,0
	end
end)
task.spawn(function()
	while Rep:GetAttribute("EngineMPPhase") ~= "Complete" do
		for _,sound in ipairs(Sounds:GetChildren()) do
			if sound:IsA("Sound") and string.match(sound.Name,"^RiftScore_") and sound.IsLoaded
				and sound.IsPlaying and sound.TimePosition > 1 and not observed[sound.Name] then
				observed[sound.Name]=true
				report("MUSIC",{name=sound.Name,id=sound.SoundId,loaded=sound.IsLoaded,playing=sound.IsPlaying,
					length=sound.TimeLength,position=sound.TimePosition,volume=sound.Volume,looped=sound.Looped})
			end
		end
		task.wait(1)
	end
	report("ERRORS",{count=#errors,messages=errors})
end)
