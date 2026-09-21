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
			child.Enabled = metrics.layoutClass == "Desktop"
		end
	end
end

local function applyHud(playerGui: PlayerGui, metrics: ResponsiveLayout.Metrics): ()
	local touchLayout = metrics.isTouch
	local rightInset = metrics.safeBottomRight.X + metrics.edge
	local topInset = metrics.safeTopLeft.Y + metrics.edge
	local bottomInset = metrics.safeBottomRight.Y + metrics.edge
	local leftInset = metrics.safeTopLeft.X + metrics.edge

	local hud = playerGui:FindFirstChild("CombatHud")
	if hud ~= nil then
		local playerPanel = frame(hud, "PlayerStatusFrame")
		local target = frame(hud, "TargetFrame")
		if touchLayout then
			if playerPanel ~= nil then
				local size = ResponsiveLayout.playerStatusSize(metrics)
				playerPanel.AnchorPoint = Vector2.new(1, 0)
				playerPanel.Position = UDim2.new(1, -rightInset, 0, topInset)
				playerPanel.Size = UDim2.fromOffset(size.X, size.Y)
			end
			if target ~= nil then
				local size = ResponsiveLayout.targetSize(metrics)
				target.AnchorPoint = Vector2.new(0.5, 0)
				target.Position = UDim2.new(0.5, 0, 0, topInset)
				target.Size = UDim2.fromOffset(size.X, size.Y)
			end
		else
			if playerPanel ~= nil then
				playerPanel.AnchorPoint = Vector2.new(1, 0)
				playerPanel.Position = UDim2.new(1, -24, 0, 24)
				playerPanel.Size = UDim2.fromOffset(260, 190)
			end
			if target ~= nil then
				target.AnchorPoint = Vector2.new(0.5, 0)
				target.Position = UDim2.new(0.5, 0, 0, 24)
				target.Size = UDim2.fromOffset(280, 86)
			end
		end
	end

	local logGui = playerGui:FindFirstChild("CombatLog")
	local log = if logGui ~= nil then frame(logGui, "CombatLogFrame") else nil
	if log ~= nil and touchLayout then
		local collapsed = ResponsiveLayout.combatLogCollapsedSize(metrics)
		log.AnchorPoint = Vector2.new(0, 1)
		-- Leave a proportional thumb-zone allowance instead of a hardcoded
		-- device-specific offset. The log still reads as bottom-left.
		log.Position = UDim2.new(0, leftInset, 1, -(bottomInset + metrics.touchTarget * 1.15))
		if log.Size.Y.Offset <= metrics.touchTarget + 2 then
			log.Size = UDim2.fromOffset(collapsed.X, collapsed.Y)
		end
	end

	local actionsGui = playerGui:FindFirstChild("CombatActionBar")
	if actionsGui ~= nil then
		local actions = frame(actionsGui, "PrimaryActions")
		local skills = frame(actionsGui, "SkillBar")
		if touchLayout then
			if actions ~= nil then
				local size = ResponsiveLayout.primaryActionsSize(metrics)
				actions.AnchorPoint = Vector2.new(1, 1)
				actions.Position = UDim2.new(1, -rightInset, 1, -bottomInset)
				actions.Size = UDim2.fromOffset(size.X, size.Y)
				local constraint = actions:FindFirstChildOfClass("UISizeConstraint")
				if constraint ~= nil then constraint.Enabled = false end
			end
			if skills ~= nil then
				local size = ResponsiveLayout.skillBarSize(metrics, 6)
				skills.AnchorPoint = Vector2.new(0.5, 1)
				skills.Position = UDim2.new(0.5, 0, 1, -bottomInset)
				skills.Size = UDim2.fromOffset(size.X, size.Y)
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

	local touchLayout = metrics.isTouch
	local gap = metrics.gap
	local touchTarget = metrics.touchTarget

	local economy = frame(playerGui, "EconomyPanel")
	local sell = if economy ~= nil then frame(economy, "SellWorkspace") else nil
	if sell ~= nil then
		local inventory = sell:FindFirstChild("SellInventory")
		local cart = sell:FindFirstChild("SellCart")
		if touchLayout then
			local header = ResponsiveLayout.scaled(metrics, 28, 24, 34)
			local footer = touchTarget + gap * 2 + ResponsiveLayout.scaled(metrics, 30, 26, 36)
			sell.Size = UDim2.new(1, -gap * 2, 1, -gap)
			if inventory ~= nil and inventory:IsA("ScrollingFrame") then
				inventory.Position = UDim2.fromOffset(0, header)
				inventory.Size = UDim2.new(0.5, -gap, 1, -(header + gap))
			end
			if cart ~= nil and cart:IsA("ScrollingFrame") then
				cart.Position = UDim2.new(0.5, gap, 0, header)
				cart.Size = UDim2.new(0.5, -gap, 1, -(header + footer))
			end
			local total = sell:FindFirstChild("SellTotal")
			if total ~= nil and total:IsA("GuiObject") then
				total.Position = UDim2.new(0.5, gap, 1, -(footer - gap))
				total.Size = UDim2.new(0.5, -gap * 2, 0, ResponsiveLayout.scaled(metrics, 30, 26, 36))
			end
			local confirm = sell:FindFirstChild("SellConfirm")
			if confirm ~= nil and confirm:IsA("GuiObject") then
				confirm.Position = UDim2.new(0.5, gap, 1, -touchTarget)
				confirm.Size = UDim2.new(0.5, -gap, 0, touchTarget)
			end
		else
			if inventory ~= nil and inventory:IsA("ScrollingFrame") then
				inventory.Position = UDim2.fromOffset(0, 28)
				inventory.Size = UDim2.new(0.49, 0, 1, -74)
			end
			if cart ~= nil and cart:IsA("ScrollingFrame") then
				cart.Position = UDim2.new(0.51, 0, 0, 28)
				cart.Size = UDim2.new(0.49, 0, 1, -74)
			end
		end
	end

	local inventory = frame(playerGui, "InventoryPanel")
	if inventory ~= nil and touchLayout then
		local list = inventory:FindFirstChild("InventoryList")
		local equipment = inventory:FindFirstChild("EquipmentList")
		local details = inventory:FindFirstChild("Details", true)
		local status = inventory:FindFirstChild("Status", true)
		local portrait = metrics.layoutClass == "PortraitFallback"
		local headerY = ResponsiveLayout.scaled(metrics, 72, 60, 84)
		local footerY = touchTarget + gap * 2
		if list ~= nil and list:IsA("ScrollingFrame") then
			list.Position = UDim2.fromOffset(gap * 2, headerY)
			list.Size = if portrait
				then UDim2.new(1, -gap * 4, 0.52, -headerY / 2)
				else UDim2.new(0.54, -gap * 2, 1, -(headerY + footerY))
		end
		if equipment ~= nil and equipment:IsA("Frame") then
			equipment.Position = if portrait
				then UDim2.new(0, gap * 2, 0.56, gap)
				else UDim2.new(0.56, 0, 0, headerY)
			equipment.Size = if portrait
				then UDim2.new(1, -gap * 4, 0.25, -gap)
				else UDim2.new(0.44, -gap * 2, 0.48, -gap)
		end
		if details ~= nil and details:IsA("GuiObject") then
			details.Position = if portrait
				then UDim2.new(0, gap * 2, 0.82, 0)
				else UDim2.new(0.56, 0, 0.52, gap)
			details.Size = if portrait
				then UDim2.new(1, -gap * 4, 0.12, -gap)
				else UDim2.new(0.44, -gap * 2, 0.20, 0)
		end
		if status ~= nil and status:IsA("GuiObject") then
			status.Position = UDim2.new(0.56, 0, 1, -(footerY + gap))
		end
		local actionNames = { "Equip", "Unequip", "Use", "QuickSlot", "Discard" }
		for index, name in actionNames do
			local action = inventory:FindFirstChild(name)
			if action ~= nil and action:IsA("GuiObject") then
				action.Size = UDim2.new(0.2, -gap, 0, touchTarget)
				action.Position = UDim2.new((index - 1) * 0.2, gap / 2, 1, -(touchTarget + gap))
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
