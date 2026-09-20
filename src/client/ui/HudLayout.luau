--!strict

local HudLayout = {}

HudLayout.CornerMargin = 24
HudLayout.PanelBackground = Color3.fromRGB(20, 22, 29)
HudLayout.PanelTransparency = 0.18
HudLayout.PanelStrokeColor = Color3.fromRGB(72, 77, 91)
HudLayout.PanelStrokeTransparency = 0.2
HudLayout.InnerPadding = 8
HudLayout.RowGap = 5

HudLayout.PlayerStatusSize = Vector2.new(260, 190)
HudLayout.ActionBarSize = Vector2.new(360, 150)
HudLayout.SkillBarSize = Vector2.new(600, 58)
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

function HudLayout.makeCloseButton(parent: Instance, zIndex: number?): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Close"
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, -10, 0, 10)
	button.Size = UDim2.fromOffset(32, 30)
	button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
	button.BackgroundTransparency = 0.05
	button.BorderSizePixel = 0
	button.Text = "×"
	button.TextColor3 = Color3.fromRGB(240, 240, 244)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 19
	button.ZIndex = zIndex or 20
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = HudLayout.PanelStrokeColor
	stroke.Transparency = 0.18
	stroke.Thickness = 1
	stroke.Parent = button

	return button
end

return table.freeze(HudLayout)
