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
				playerPanel.Position = UDim2.new(1, -(metrics.safeBottomRight.X + metrics.margin), 0, metrics.safeTopLeft.Y + metrics.margin)
				playerPanel.Size = UDim2.fromOffset(math.min(210, metrics.contentSize.X * 0.32), 120)
			end
			if target ~= nil then
				target.Position = UDim2.new(0.5, 0, 0, metrics.safeTopLeft.Y + metrics.margin)
				target.Size = UDim2.fromOffset(math.min(210, metrics.contentSize.X * 0.32), 54)
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
				actions.Position = UDim2.new(1, -(metrics.safeBottomRight.X + metrics.margin), 1, -(metrics.safeBottomRight.Y + metrics.margin))
				actions.Size = UDim2.fromOffset(math.min(240, metrics.contentSize.X * 0.30), 112)
				local constraint = actions:FindFirstChildOfClass("UISizeConstraint")
				if constraint ~= nil then constraint.Enabled = false end
			end
			if skills ~= nil then
				skills.Position = UDim2.new(0.5, 0, 1, -(metrics.safeBottomRight.Y + metrics.margin))
				skills.AnchorPoint = Vector2.new(0.5, 1)
				skills.Size = UDim2.fromOffset(math.min(300, metrics.contentSize.X * 0.38), 54)
			end
		end
	end
end

local function applyModals(playerGui: PlayerGui, metrics: ResponsiveLayout.Metrics): ()
	for name, desktopSize in DESKTOP_MODAL_SIZES do
		setModal(frame(playerGui, name), metrics, desktopSize)
	end
	setModal(frame(playerGui, "DialogueShell"), metrics, Vector2.new(620, 360))
	setModal(frame(playerGui, "QuestJournal"), metrics, Vector2.new(760, 650))
	setModal(frame(playerGui, "WorldMap"), metrics, Vector2.new(900, 650))

	local economy = frame(playerGui, "EconomyPanel")
	local sell = if economy ~= nil then frame(economy, "SellWorkspace") else nil
	if sell ~= nil then
		local inventory = sell:FindFirstChild("SellInventory")
		local cart = sell:FindFirstChild("SellCart")
		if ResponsiveLayout.isSmallTouch(metrics) then
			sell.Size = UDim2.new(1, -12, 1, -8)
			if inventory ~= nil and inventory:IsA("ScrollingFrame") then inventory.Position = UDim2.fromOffset(0, 28); inventory.Size = UDim2.new(0.5, -5, 1, -36) end
			if cart ~= nil and cart:IsA("ScrollingFrame") then cart.Position = UDim2.new(0.5, 5, 0, 28); cart.Size = UDim2.new(0.5, -5, 1, -112) end
			local total = sell:FindFirstChild("SellTotal")
			if total ~= nil and total:IsA("GuiObject") then total.Position = UDim2.new(0.5, 9, 1, -80); total.Size = UDim2.new(0.5, -13, 0, 30) end
			local confirm = sell:FindFirstChild("SellConfirm")
			if confirm ~= nil and confirm:IsA("GuiObject") then confirm.Position = UDim2.new(0.5, 5, 1, -46); confirm.Size = UDim2.new(0.5, -5, 0, ResponsiveLayout.MinimumTouchTarget) end
		else
			if inventory ~= nil and inventory:IsA("ScrollingFrame") then inventory.Position = UDim2.fromOffset(0, 28); inventory.Size = UDim2.new(0.49, 0, 1, -74) end
			if cart ~= nil and cart:IsA("ScrollingFrame") then cart.Position = UDim2.new(0.51, 0, 0, 28); cart.Size = UDim2.new(0.49, 0, 1, -74) end
		end
	end

	local inventory = frame(playerGui, "InventoryPanel")
	if inventory ~= nil and ResponsiveLayout.isSmallTouch(metrics) then
		local list = inventory:FindFirstChild("InventoryList")
		local equipment = inventory:FindFirstChild("EquipmentList")
		local details = inventory:FindFirstChild("Details", true)
		local status = inventory:FindFirstChild("Status", true)
		local portrait = metrics.mode == "MobilePortrait"
		if list ~= nil and list:IsA("ScrollingFrame") then
			list.Position = UDim2.fromOffset(16, 112)
			list.Size = if portrait then UDim2.new(1, -32, 0, 290) else UDim2.new(0.54, -20, 1, -128)
		end
		if equipment ~= nil and equipment:IsA("Frame") then
			equipment.Position = if portrait then UDim2.fromOffset(16, 430) else UDim2.new(0.56, 0, 0, 72)
			equipment.Size = if portrait then UDim2.new(1, -32, 0, 224) else UDim2.new(0.44, -16, 0, 190)
		end
		if details ~= nil and details:IsA("GuiObject") then
			details.Position = if portrait then UDim2.fromOffset(16, 654) else UDim2.new(0.56, 0, 0, 230)
			details.Size = if portrait then UDim2.new(1, -32, 0, 78) else UDim2.new(0.44, -16, 0, 70)
		end
		if status ~= nil and status:IsA("GuiObject") then status.Position = UDim2.new(0.56, 0, 1, -66) end
		local actionNames = { "Equip", "Unequip", "Use", "QuickSlot", "Discard" }
		for index, name in actionNames do
			local action = inventory:FindFirstChild(name)
			if action ~= nil and action:IsA("GuiObject") then
				action.Position = UDim2.new(0, 16 + (index - 1) * 0, 1, -46)
				action.Size = UDim2.new(0.19, -6, 0, ResponsiveLayout.MinimumTouchTarget)
				action.Position = UDim2.new((index - 1) * 0.2, 8, 1, -52)
			end
		end
	end
end

local function apply(metrics: ResponsiveLayout.Metrics): ()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then return end
	applyHud(playerGui, metrics)
	applyModals(playerGui, metrics)
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
