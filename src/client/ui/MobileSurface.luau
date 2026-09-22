--!strict

local ResponsiveLayout = require(script.Parent.ResponsiveLayout)

local MobileSurface = {}

export type Kind = "CompactDialog" | "MenuSheet" | "FullWorkspace"

local function removeConstraint(panel: GuiObject, name: string): ()
	local old = panel:FindFirstChild(name)
	if old ~= nil then old:Destroy() end
end

function MobileSurface.apply(panel: GuiObject, kind: Kind, metrics: ResponsiveLayout.Metrics, contentHeight: number?): ()
	removeConstraint(panel, "MobileSurfaceSize")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)

	if kind == "FullWorkspace" then
		panel.Size = UDim2.fromScale(1, 1)
		return
	end

	local maxWidth = if kind == "MenuSheet" then 460 else 560
	local maxHeightRatio = if kind == "MenuSheet" then 0.72 else 0.65
	local desiredHeight = contentHeight or (if kind == "MenuSheet" then 220 else 280)
	panel.Size = UDim2.fromOffset(
		math.min(maxWidth, metrics.usableWidth - metrics.gap * 2),
		math.min(desiredHeight, metrics.usableHeight * maxHeightRatio)
	)
end

function MobileSurface.header(parent: Instance, titleText: string): Frame
	local header = Instance.new("Frame")
	header.Name = "SurfaceHeader"
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundTransparency = 1
	header.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "SurfaceTitle"
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -72, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(239, 245, 255)
	title.TextSize = 17
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header
	return header
end

function MobileSurface.scrollingBody(parent: Instance, footerHeight: number): ScrollingFrame
	local body = Instance.new("ScrollingFrame")
	body.Name = "SurfaceBody"
	body.Position = UDim2.fromOffset(0, 56)
	body.Size = UDim2.new(1, 0, 1, -(56 + footerHeight))
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.fromOffset(0, 0)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 5
	body.Parent = parent
	return body
end

function MobileSurface.footer(parent: Instance, height: number): Frame
	local footer = Instance.new("Frame")
	footer.Name = "SurfaceFooter"
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.fromScale(0, 1)
	footer.Size = UDim2.new(1, 0, 0, height)
	footer.BackgroundTransparency = 1
	footer.Parent = parent
	return footer
end

return table.freeze(MobileSurface)
