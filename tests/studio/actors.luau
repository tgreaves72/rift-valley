-- Plain R6 actor for controlled engine movement tests, with no external assets.
return function(name, position)
	local model = Instance.new("Model") model.Name = name
	local function part(label,size,p,collide)
		local value=Instance.new("Part")
		value.Name,value.Size,value.CFrame=label,size,CFrame.new(p)
		value.CanCollide,value.CollisionGroup=collide,"RiftCharacters"
		value.Color=Color3.fromRGB(145,255,214)
		value.Parent=model
		return value
	end
	local root=part("HumanoidRootPart",Vector3.new(2,2,1),Vector3.new(0,3,0),false)
	root.Transparency=1
	local torso=part("Torso",Vector3.new(2,2,1),Vector3.new(0,3,0),true)
	local head=part("Head",Vector3.new(2,1,1),Vector3.new(0,4.5,0),true)
	local left=part("Left Leg",Vector3.new(1,2,1),Vector3.new(-.5,1,0),false)
	local right=part("Right Leg",Vector3.new(1,2,1),Vector3.new(.5,1,0),false)
	local la=part("Left Arm",Vector3.new(1,2,1),Vector3.new(-1.5,3,0),false)
	local ra=part("Right Arm",Vector3.new(1,2,1),Vector3.new(1.5,3,0),false)
	local function motor(label,a,b,c0,c1)
		local joint=Instance.new("Motor6D")
		joint.Name,joint.Part0,joint.Part1=label,a,b
		joint.C0,joint.C1=c0,c1 joint.Parent=a
	end
	motor("RootJoint",root,torso,CFrame.identity,CFrame.identity)
	motor("Neck",torso,head,CFrame.new(0,1,0),CFrame.new(0,-.5,0))
	motor("Left Hip",torso,left,CFrame.new(-.5,-1,0),CFrame.new(0,1,0))
	motor("Right Hip",torso,right,CFrame.new(.5,-1,0),CFrame.new(0,1,0))
	motor("Left Shoulder",torso,la,CFrame.new(-1.5,0,0),CFrame.identity)
	motor("Right Shoulder",torso,ra,CFrame.new(1.5,0,0),CFrame.identity)
	local humanoid=Instance.new("Humanoid")
	humanoid.WalkSpeed,humanoid.JumpPower,humanoid.UseJumpPower=22,45,true
	humanoid.Parent=model model.PrimaryPart=root model.Parent=workspace
	model:PivotTo(CFrame.new(position)) root:SetNetworkOwner(nil)
	return model,root,humanoid
end
