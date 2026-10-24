-- Run only in the isolated Studio copy. Probe public audio availability without
-- changing the production player, permission settings or music configuration.
assert(game:GetService("RunService"):IsStudio())
local Rep=game:GetService("ReplicatedStorage")
local Ids=require(Rep:WaitForChild("RiftShared").MusicIds)
local Http=game:GetService("HttpService")
local Sounds=game:GetService("SoundService")
for key,id in pairs(Ids) do
	task.spawn(function()
		local sound=Instance.new("Sound")
		sound.Name,sound.SoundId,sound.Volume="AudioProbe_"..key,"rbxassetid://"..id,0
		sound.Parent=Sounds sound:Play()
		local began=os.clock()
		repeat task.wait(.2) until sound.IsLoaded or os.clock()-began>15
		print("[RiftAudioEngine] "..Http:JSONEncode({key=key,id=id,loaded=sound.IsLoaded,length=sound.TimeLength,playing=sound.IsPlaying,testRevision=2,version=require(Rep.RiftShared.Config).Version}))
		sound:Destroy()
	end)
end
