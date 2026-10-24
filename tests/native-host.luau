-- Scene-backed adapter for startup and world tests. Events/time are controlled;
-- map cloning, hierarchy and serialized geometry use the actual place data.
local fs, roblox = require("@lune/fs"), require("@lune/roblox")
return function()
	local model = roblox.deserializePlace(fs.readFile("dist/RiftValley.rbxlx"))
	local proxies, attrs, events = {}, {}, {}
	local function signal()
		local signal = { callbacks = {} }
		function signal:Connect(fn) table.insert(self.callbacks, fn) return { Disconnect = function() end } end
		function signal:Fire(...) for _, fn in ipairs(self.callbacks) do fn(...) end end
		return signal
	end
	local wrap
	local function unwrap(value) return type(value) == "table" and rawget(value, "native") or value end
	wrap = function(obj)
		if proxies[obj] then return proxies[obj] end
		local proxy = { native = obj }
		proxies[obj] = proxy
		return setmetatable(proxy, {
			__index = function(_, key)
				if key == "ScaleTo" then return function(_, scale)
					attrs[obj] = attrs[obj] or {}
					local ratio = scale / (attrs[obj].testScale or 1)
					local pivot = obj.PrimaryPart.CFrame
					for _, child in ipairs(obj:GetDescendants()) do
						if child:IsA("BasePart") then
							local relative = pivot:ToObjectSpace(child.CFrame)
							child.Size *= ratio
							child.CFrame = pivot * (relative - relative.Position + relative.Position*ratio)
						end
					end
					attrs[obj].testScale = scale
				end end
				if key == "PivotTo" then return function(_, frame)
					local pivot = obj.PrimaryPart and obj.PrimaryPart.CFrame or obj.WorldPivot
					local delta = frame * pivot:Inverse()
					for _, child in ipairs(obj:GetDescendants()) do if child:IsA("BasePart") then child.CFrame = delta * child.CFrame end end
				end end
				if key == "WaitForChild" then return function(_, name) local child = obj:FindFirstChild(name) assert(child, "Missing native child: " .. name) return wrap(child) end end
				if key == "SetAttribute" then return function(_, name, value) attrs[obj] = attrs[obj] or {} attrs[obj][name] = value end end
				if key == "GetAttribute" then return function(_, name) return attrs[obj] and attrs[obj][name] end end
				if key == "GetPropertyChangedSignal" or key == "GetAttributeChangedSignal" then
					return function(_, name)
						events[obj] = events[obj] or {}
						local eventKey = key .. name
						if not events[obj][eventKey] then events[obj][eventKey] = signal() end
						return events[obj][eventKey]
					end
				end
				if key == "Triggered" or key == "Activated" or key == "CharacterAdded" or key == "ChildAdded" or key == "DescendantAdded" or key == "OnClientEvent" or key == "OnServerEvent" or key == "PlayerAdded" or key == "PlayerRemoving" or key == "Heartbeat" or key == "PromptGamePassPurchaseFinished" then
					events[obj] = events[obj] or {}
					if not events[obj][key] then events[obj][key] = signal() end
					return events[obj][key]
				end
				if key == "Position" and obj:IsA("BasePart") then return obj.CFrame.Position end
				local value = obj[key]
				if typeof(value) == "Instance" then return wrap(value) end
				if type(value) == "function" then
					return function(_, ...)
						local args = { ... }
						for i, arg in ipairs(args) do args[i] = unwrap(arg) end
						local result = value(obj, table.unpack(args))
						if typeof(result) == "Instance" then return wrap(result) end
						if type(result) == "table" then for i, child in ipairs(result) do if typeof(child) == "Instance" then result[i] = wrap(child) end end end
						return result
					end
				end
				return value
			end,
			__newindex = function(_, key, value)
				if key == "Adornee" then rawset(proxy, key, value) return end
				if key == "Position" and obj:IsA("BasePart") then obj.CFrame = obj.CFrame - obj.CFrame.Position + value return end
				obj[key] = unwrap(value)
			end,
		})
	end
	return { model = model, wrap = wrap, workspace = wrap(model:GetService("Workspace")), replicated = wrap(model:GetService("ReplicatedStorage")) }
end
