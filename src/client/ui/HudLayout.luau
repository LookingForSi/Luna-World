--!strict

local HudLayout = {}

HudLayout.CornerMargin = 24
HudLayout.PanelBackground = Color3.fromRGB(20, 22, 29)
HudLayout.PanelTransparency = 0.18
HudLayout.PanelStrokeColor = Color3.fromRGB(72, 77, 91)
HudLayout.PanelStrokeTransparency = 0.2
HudLayout.InnerPadding = 8
HudLayout.RowGap = 5

HudLayout.PlayerStatusSize = Vector2.new(300, 178)
HudLayout.ActionBarSize = Vector2.new(414, 142)
HudLayout.CombatLogSize = Vector2.new(500, 190)

function HudLayout.applyPanelStyle(frame: Frame): ()
	frame.BackgroundColor3 = HudLayout.PanelBackground
	frame.BackgroundTransparency = HudLayout.PanelTransparency
	frame.BorderSizePixel = 0

	local stroke = Instance.new("UIStroke")
	stroke.Name = "PanelStroke"
	stroke.Color = HudLayout.PanelStrokeColor
	stroke.Transparency = HudLayout.PanelStrokeTransparency
	stroke.Thickness = 1
	stroke.Parent = frame
end

return table.freeze(HudLayout)
