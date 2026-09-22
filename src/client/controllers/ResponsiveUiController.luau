--!strict

local Players = game:GetService("Players")

local ResponsiveLayout = require(script.Parent.Parent.ui.ResponsiveLayout)

local ResponsiveUiController = {}
local stopObserving: (() -> ())? = nil
local descendantConnection: RBXScriptConnection? = nil

local DESKTOP_MODAL_SIZES = {
	InventoryPanel = Vector2.new(720, 500),
	EconomyPanel = Vector2.new(680, 500),
	QuestOffer = Vector2.new(560, 360),
	TravelConfirm = Vector2.new(520, 250),
	RespawnDialog = Vector2.new(430, 170),
}

local function frame(gui: Instance, name: string): Frame?
	local value = gui:FindFirstChild(name, true)
	return if value ~= nil and value:IsA("Frame") then value else nil
end

local function setModal(panel: Frame?, metrics: ResponsiveLayout.Metrics, desktopSize: Vector2): ()
	if panel == nil then return end
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	local size = ResponsiveLayout.modalSize(metrics, desktopSize)
	panel.Size = UDim2.fromOffset(size.X, size.Y)
	for _, child in panel:GetChildren() do
		if child:IsA("UISizeConstraint") then
			child.Enabled = metrics.mode == "Desktop"
		end
	end
end

local function applyHud(playerGui: PlayerGui, metrics: ResponsiveLayout.Metrics): ()
	local hud = playerGui:FindFirstChild("CombatHud")
	if hud ~= nil then
		local playerPanel = frame(hud, "PlayerStatusFrame")
		local target = frame(hud, "TargetFrame")
		if ResponsiveLayout.isSmallTouch(metrics) then
			if playerPanel ~= nil then
				playerPanel.AnchorPoint = Vector2.new(1, 0)
				playerPanel.Position = UDim2.new(1, -metrics.margin, 0, metrics.margin)
				playerPanel.Size = UDim2.fromOffset(math.min(220, metrics.contentSize.X * 0.48), 160)
			end
			if target ~= nil then
				target.Position = UDim2.new(0.5, 0, 0, metrics.margin)
				target.Size = UDim2.fromOffset(math.min(220, metrics.contentSize.X * 0.46), 72)
			end
		else
			if playerPanel ~= nil then
				playerPanel.AnchorPoint = Vector2.new(1, 0)
				playerPanel.Position = UDim2.new(1, -24, 0, 24)
				playerPanel.Size = UDim2.fromOffset(260, 190)
			end
			if target ~= nil then target.Position = UDim2.new(0.5, 0, 0, 24); target.Size = UDim2.fromOffset(280, 86) end
		end
	end

	local logGui = playerGui:FindFirstChild("CombatLog")
	local log = if logGui ~= nil then frame(logGui, "CombatLogFrame") else nil
	if log ~= nil and ResponsiveLayout.isSmallTouch(metrics) then
		log.Size = UDim2.fromOffset(108, 30)
		local entries = log:FindFirstChild("Entries")
		if entries ~= nil and entries:IsA("GuiObject") then entries.Visible = false end
	end

	local actionsGui = playerGui:FindFirstChild("CombatActionBar")
	if actionsGui ~= nil then
		local actions = frame(actionsGui, "PrimaryActions")
		local skills = frame(actionsGui, "SkillBar")
		if ResponsiveLayout.isSmallTouch(metrics) then
			if actions ~= nil then
				actions.Position = UDim2.new(1, -metrics.margin, 1, -120)
				actions.Size = UDim2.fromOffset(math.min(300, metrics.contentSize.X * 0.48), 142)
				local constraint = actions:FindFirstChildOfClass("UISizeConstraint")
				if constraint ~= nil then
					-- UISizeConstraint has no Enabled property. Writing it used to throw
					-- during touch startup, aborting GameplayClientRuntime after the HUD
					-- had mounted; ClientApplication then correctly cleaned the HUD up.
					constraint.MinSize = Vector2.zero
					constraint.MaxSize = Vector2.new(10000, 10000)
				end
			end
			if skills ~= nil then
				skills.Position = UDim2.new(0.5, 0, 1, -metrics.margin)
				skills.AnchorPoint = Vector2.new(0.5, 1)
				skills.Size = UDim2.fromOffset(math.min(360, metrics.contentSize.X * 0.48), 54)
			end
		end
	end
end

local function apply(metrics: ResponsiveLayout.Metrics): ()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then return end
	applyHud(playerGui, metrics)
end

function ResponsiveUiController.start(): ()
	ResponsiveUiController.stop()
	stopObserving = ResponsiveLayout.observe(apply)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	descendantConnection = playerGui.DescendantAdded:Connect(function()
		task.defer(function() apply(ResponsiveLayout.metrics(workspace.CurrentCamera)) end)
	end)
end

function ResponsiveUiController.stop(): ()
	if stopObserving ~= nil then stopObserving(); stopObserving = nil end
	if descendantConnection ~= nil then descendantConnection:Disconnect(); descendantConnection = nil end
end

return ResponsiveUiController
