-- Export the actual runtime GUI layout for an offline design review. This does
-- not emulate Roblox text rasterization, safe areas or native touch controls.
local fs, serde = require("@lune/fs"), require("@lune/serde")
return function(gui, width, height, path)
	local items = {}
	local function rgb(color) return { color.R*255, color.G*255, color.B*255 } end
	local function visit(parent, px, py, pw, ph, inheritedScale)
		for _, obj in ipairs(parent:GetChildren()) do
			if not obj:IsA("GuiObject") or not obj.Visible then continue end
			local uiScale = obj:FindFirstChildOfClass("UIScale")
			local scale = inheritedScale * (uiScale and uiScale.Scale or 1)
			local w = obj.Size.X.Scale*pw + obj.Size.X.Offset*scale
			local h = obj.Size.Y.Scale*ph + obj.Size.Y.Offset*scale
			local x = px + obj.Position.X.Scale*pw + obj.Position.X.Offset*inheritedScale - obj.AnchorPoint.X*w
			local y = py + obj.Position.Y.Scale*ph + obj.Position.Y.Offset*inheritedScale - obj.AnchorPoint.Y*h
			local radius, stroke = obj:FindFirstChildOfClass("UICorner"), obj:FindFirstChildOfClass("UIStroke")
			local item = { name = obj.Name, x = x, y = y, w = w, h = h,
				background = rgb(obj.BackgroundColor3), alpha = 1-obj.BackgroundTransparency,
				radius = radius and (radius.CornerRadius.Scale*math.min(w,h) + radius.CornerRadius.Offset*scale) or 0 }
			if stroke then item.stroke, item.strokeAlpha, item.strokeWidth = rgb(stroke.Color), 1-stroke.Transparency, stroke.Thickness*scale end
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				item.text, item.font, item.fontSize, item.color = obj.Text, obj.Font.Name, obj.TextSize*scale, rgb(obj.TextColor3)
				item.align = obj.TextXAlignment.Name
			end
			table.insert(items, item)
			visit(obj, x, y, w, h, scale)
		end
	end
	visit(gui, 0, 0, width, height, 1)
	fs.writeFile(path, serde.encode("json", { width = width, height = height, items = items }))
end
