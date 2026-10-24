local r=require("@lune/roblox")
local h=require("./match-host")(1)
local p=h.players[1]
local bag=h.host.wrap(r.Instance.new("Backpack")) bag.Parent=p
local root=p.Character.HumanoidRootPart
local hum=p.Character:FindFirstChildOfClass("Humanoid")
local count=0
local function check(v,m) assert(v,m) count+=1 end
local function enemies()
	local n=0
	for _,model in ipairs(h.host.workspace.RiftLobby.VIPActivity:GetChildren()) do if model:GetAttribute("VIPArenaEnemy") then n+=1 end end
	return n
end
h.vipOwners[p]=true
root.CFrame=r.CFrame.new(157,32,224)
h.tick(.3)
check(#bag:GetChildren()==3 and enemies()==2 and h.host.replicated:GetAttribute("Phase")=="Intermission","real game grants gear and runs arena enemies while waiting in the lobby")
bag:FindFirstChild("Speed Coil").Parent=p.Character h.tick(.3)
check(hum.WalkSpeed==38 and hum.JumpPower==45,"game movement loop applies only the equipped speed coil")
p.Character:FindFirstChild("Speed Coil").Parent=bag
bag:FindFirstChild("Jump Coil").Parent=p.Character h.tick(.3)
check(hum.WalkSpeed==22 and hum.JumpPower==72,"game movement loop applies the jump coil")
root.CFrame=r.CFrame.new(101,32,224) h.tick(.3)
check(hum.WalkSpeed==22 and hum.JumpPower==45 and enemies()==0,"leaving the arena restores normal movement and retires enemies")
h.vipOwners[p]=false h.tick(.3)
check(#bag:GetChildren()==0 and not p.Character:FindFirstChildOfClass("Tool"),"real game revokes all issued gear when ownership changes")
root.CFrame=r.CFrame.new(157,32,224) h.tick(.3)
check(math.abs(root.Position.X)<16 and enemies()==0,"non-owner cannot enter the VIP activity by bypassing the lounge")
print("PASS: "..count.." actual game VIP intermission, equipment, enemies, movement and revocation assertions")
