--!strict

local UserInputService = game:GetService("UserInputService")

local ResponsiveLayout = {}

export type Mode = "Desktop" | "TouchLarge" | "MobilePortrait" | "MobileLandscape"
export type Metrics = {
	mode: Mode,
	viewport: Vector2,
	usableWidth: number,
	usableHeight: number,
	layoutClass: Mode,
	touchTarget: number,
	gap: number,
	margin: number,
	contentSize: Vector2,
	isTouch: boolean,
}

ResponsiveLayout.PhoneShortSide = 520
ResponsiveLayout.TouchLargeShortSide = 700
ResponsiveLayout.DesktopMargin = 24
ResponsiveLayout.TouchMargin = 10
ResponsiveLayout.MinimumTouchTarget = 44

function ResponsiveLayout.resolve(viewport: Vector2, isTouch: boolean): Mode
	if not isTouch then return "Desktop" end
	local shortSide = math.min(viewport.X, viewport.Y)
	if shortSide >= ResponsiveLayout.TouchLargeShortSide then return "TouchLarge" end
	if viewport.Y > viewport.X then return "MobilePortrait" end
	return "MobileLandscape"
end

function ResponsiveLayout.metrics(camera: Camera?): Metrics
	local viewport = if camera ~= nil then camera.ViewportSize else Vector2.new(1280, 720)
	local isTouch = UserInputService.TouchEnabled
	local mode = ResponsiveLayout.resolve(viewport, isTouch)
	local margin = if mode == "Desktop" then ResponsiveLayout.DesktopMargin else ResponsiveLayout.TouchMargin
	return {
		mode = mode,
		viewport = viewport,
		usableWidth = viewport.X,
		usableHeight = viewport.Y,
		layoutClass = mode,
		touchTarget = ResponsiveLayout.MinimumTouchTarget,
		gap = margin,
		margin = margin,
		contentSize = Vector2.new(
			math.max(0, viewport.X - margin * 2),
			math.max(0, viewport.Y - margin * 2)
		),
		isTouch = isTouch,
	}
end

function ResponsiveLayout.isSmallTouch(metrics: Metrics): boolean
	return metrics.mode == "MobilePortrait" or metrics.mode == "MobileLandscape"
end

function ResponsiveLayout.modalSize(metrics: Metrics, desktopSize: Vector2): Vector2
	return Vector2.new(
		math.min(desktopSize.X, metrics.contentSize.X),
		math.min(desktopSize.Y, metrics.contentSize.Y)
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
