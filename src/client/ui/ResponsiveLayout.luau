--!strict

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local ResponsiveLayout = {}

export type Mode = "Desktop" | "TouchLarge" | "MobilePortrait" | "MobileLandscape"
export type LayoutClass = "Desktop" | "CompactLandscape" | "RegularLandscape" | "ExpandedLandscape" | "PortraitFallback"
export type Metrics = {
	mode: Mode,
	layoutClass: LayoutClass,
	viewport: Vector2,
	safeTopLeft: Vector2,
	safeBottomRight: Vector2,
	margin: number,
	edge: number,
	gap: number,
	contentSize: Vector2,
	isTouch: boolean,
	uiScale: number,
	touchTarget: number,
}

-- Device detection is intentionally coarse. Product layout decisions are made
-- from the actual safe viewport below, not from a phone/tablet model name.
ResponsiveLayout.PhoneShortSide = 520
ResponsiveLayout.TouchLargeShortSide = 700
ResponsiveLayout.DesktopMargin = 24
ResponsiveLayout.TouchMargin = 10
ResponsiveLayout.MinimumTouchTarget = 44
ResponsiveLayout.MaximumTouchTarget = 56

local function clamp(value: number, minimum: number, maximum: number): number
	return math.clamp(value, minimum, maximum)
end

function ResponsiveLayout.resolve(viewport: Vector2, isTouch: boolean): Mode
	if not isTouch then return "Desktop" end
	local shortSide = math.min(viewport.X, viewport.Y)
	if shortSide >= ResponsiveLayout.TouchLargeShortSide then return "TouchLarge" end
	if viewport.Y > viewport.X then return "MobilePortrait" end
	return "MobileLandscape"
end

local function classify(content: Vector2, isTouch: boolean, mode: Mode): LayoutClass
	if not isTouch then return "Desktop" end
	if mode == "MobilePortrait" then return "PortraitFallback" end
	-- Width and height both matter. A tablet in split-screen can therefore fall
	-- back to Regular/Compact without pretending to be a different device.
	if content.Y <= 430 or content.X <= 900 then return "CompactLandscape" end
	if content.Y <= 650 or content.X <= 1200 then return "RegularLandscape" end
	return "ExpandedLandscape"
end

local function fluidScale(content: Vector2, isTouch: boolean, layoutClass: LayoutClass): number
	if not isTouch or layoutClass == "Desktop" then return 1 end
	-- 900x412 is only a normalization reference, not a target resolution.
	-- Clamp prevents a small phone from becoming untappable and a tablet from
	-- inflating the whole HUD like a scaled screenshot.
	local scale = math.min(content.X / 900, content.Y / 412)
	return clamp(scale, 0.90, 1.15)
end

function ResponsiveLayout.metrics(camera: Camera?): Metrics
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local topLeft, bottomRight = GuiService:GetGuiInset()
	local isTouch = UserInputService.TouchEnabled
	local mode = ResponsiveLayout.resolve(viewport, isTouch)

	local rawSafe = Vector2.new(
		math.max(0, viewport.X - topLeft.X - bottomRight.X),
		math.max(0, viewport.Y - topLeft.Y - bottomRight.Y)
	)
	local layoutClass = classify(rawSafe, isTouch, mode)
	local shortSide = math.min(rawSafe.X, rawSafe.Y)
	local edge = if layoutClass == "Desktop"
		then ResponsiveLayout.DesktopMargin
		else clamp(math.round(shortSide * 0.018), 6, 16)
	local gap = if layoutClass == "Desktop"
		then 8
		else clamp(math.round(shortSide * 0.012), 4, 12)
	local uiScale = fluidScale(rawSafe, isTouch, layoutClass)
	local touchTarget = if isTouch
		then clamp(math.round(shortSide * 0.118), ResponsiveLayout.MinimumTouchTarget, ResponsiveLayout.MaximumTouchTarget)
		else ResponsiveLayout.MinimumTouchTarget

	return {
		mode = mode,
		layoutClass = layoutClass,
		viewport = viewport,
		safeTopLeft = topLeft,
		safeBottomRight = bottomRight,
		margin = edge, -- compatibility alias for older callers
		edge = edge,
		gap = gap,
		contentSize = Vector2.new(
			math.max(0, rawSafe.X - edge * 2),
			math.max(0, rawSafe.Y - edge * 2)
		),
		isTouch = isTouch,
		uiScale = uiScale,
		touchTarget = touchTarget,
	}
end

function ResponsiveLayout.isSmallTouch(metrics: Metrics): boolean
	return metrics.layoutClass == "CompactLandscape"
		or metrics.layoutClass == "RegularLandscape"
		or metrics.layoutClass == "PortraitFallback"
end

function ResponsiveLayout.isLandscapeTouch(metrics: Metrics): boolean
	return metrics.isTouch and metrics.viewport.X >= metrics.viewport.Y
end

function ResponsiveLayout.isExpandedTouch(metrics: Metrics): boolean
	return metrics.layoutClass == "ExpandedLandscape"
end

function ResponsiveLayout.fluidWidth(metrics: Metrics, ratio: number, minimum: number, maximum: number): number
	return clamp(metrics.contentSize.X * ratio, minimum, maximum)
end

function ResponsiveLayout.fluidHeight(metrics: Metrics, ratio: number, minimum: number, maximum: number): number
	return clamp(metrics.contentSize.Y * ratio, minimum, maximum)
end

function ResponsiveLayout.scaled(metrics: Metrics, base: number, minimum: number, maximum: number): number
	return clamp(base * metrics.uiScale, minimum, maximum)
end

function ResponsiveLayout.playerStatusSize(metrics: Metrics): Vector2
	return Vector2.new(
		ResponsiveLayout.fluidWidth(metrics, 0.22, 184, 248),
		ResponsiveLayout.fluidHeight(metrics, 0.30, 108, 132)
	)
end

function ResponsiveLayout.targetSize(metrics: Metrics): Vector2
	return Vector2.new(
		ResponsiveLayout.fluidWidth(metrics, 0.24, 190, 270),
		ResponsiveLayout.fluidHeight(metrics, 0.14, 50, 66)
	)
end

function ResponsiveLayout.primaryActionsSize(metrics: Metrics): Vector2
	return Vector2.new(
		ResponsiveLayout.fluidWidth(metrics, 0.27, 210, 280),
		ResponsiveLayout.fluidHeight(metrics, 0.28, 104, 132)
	)
end

function ResponsiveLayout.skillCellSize(metrics: Metrics): number
	return clamp(metrics.contentSize.Y * 0.12, metrics.touchTarget, 54)
end

function ResponsiveLayout.skillBarSize(metrics: Metrics, slotCount: number): Vector2
	local cell = ResponsiveLayout.skillCellSize(metrics)
	local innerGap = math.max(4, metrics.gap)
	local width = cell * slotCount + innerGap * math.max(0, slotCount - 1) + 10
	return Vector2.new(math.min(width, metrics.contentSize.X * 0.52), cell + 10)
end

function ResponsiveLayout.combatLogCollapsedSize(metrics: Metrics): Vector2
	return Vector2.new(
		ResponsiveLayout.fluidWidth(metrics, 0.13, 104, 132),
		metrics.touchTarget
	)
end

function ResponsiveLayout.combatLogExpandedSize(metrics: Metrics): Vector2
	return Vector2.new(
		ResponsiveLayout.fluidWidth(metrics, 0.35, 240, 320),
		ResponsiveLayout.fluidHeight(metrics, 0.34, 112, 160)
	)
end

function ResponsiveLayout.lobbyRosterWidth(metrics: Metrics): number
	return ResponsiveLayout.fluidWidth(metrics, 0.31, 230, 380)
end

function ResponsiveLayout.modalSize(metrics: Metrics, desktopSize: Vector2): Vector2
	if metrics.layoutClass == "Desktop" then
		return Vector2.new(
			math.min(desktopSize.X, metrics.contentSize.X),
			math.min(desktopSize.Y, metrics.contentSize.Y)
		)
	end

	local widthFraction = if metrics.layoutClass == "CompactLandscape" then 0.92
		elseif metrics.layoutClass == "RegularLandscape" then 0.88
		elseif metrics.layoutClass == "ExpandedLandscape" then 0.78
		else 0.94
	local heightFraction = if metrics.layoutClass == "CompactLandscape" then 0.90
		elseif metrics.layoutClass == "RegularLandscape" then 0.88
		elseif metrics.layoutClass == "ExpandedLandscape" then 0.82
		else 0.92

	return Vector2.new(
		math.min(desktopSize.X, metrics.contentSize.X * widthFraction),
		math.min(desktopSize.Y, metrics.contentSize.Y * heightFraction)
	)
end

-- Re-runs on camera replacement, viewport resize, orientation changes and input-mode changes.
function ResponsiveLayout.observe(callback: (Metrics) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}
	local cameraConnection: RBXScriptConnection? = nil
	local stopped = false

	local function update(): ()
		if not stopped then callback(ResponsiveLayout.metrics(workspace.CurrentCamera)) end
	end
	local function bindCamera(): ()
		if cameraConnection ~= nil then cameraConnection:Disconnect() end
		local camera = workspace.CurrentCamera
		cameraConnection = if camera ~= nil then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update) else nil
		update()
	end

	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
	table.insert(connections, UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(update))
	table.insert(connections, UserInputService.LastInputTypeChanged:Connect(update))
	bindCamera()

	return function()
		stopped = true
		if cameraConnection ~= nil then cameraConnection:Disconnect() end
		for _, connection in connections do connection:Disconnect() end
	end
end

return table.freeze(ResponsiveLayout)
