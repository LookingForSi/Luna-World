--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local HudLayout = require(script.Parent.HudLayout)
local ResponsiveLayout = require(script.Parent.ResponsiveLayout)

local InventoryUi = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local root: Frame? = nil
local modalBlocker: TextButton? = nil
local inventoryList: ScrollingFrame? = nil
local equipmentList: ScrollingFrame? = nil
local detailsLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local lunaLabel: TextLabel? = nil
local capacityLabel: TextLabel? = nil
local equipButton: TextButton? = nil
local unequipButton: TextButton? = nil
local useButton: TextButton? = nil
local discardButton: TextButton? = nil
local quickSlotButton: TextButton? = nil
local filterButtons: { [string]: TextButton } = {}
local activeFilter = "All"
local closeConnection: RBXScriptConnection? = nil
local actionConnections: { RBXScriptConnection } = {}
local currentSnapshot: any = nil
local selectedKind: "Inventory" | "Equipment"? = nil
local selectedIdentifier: string? = nil
local callbacks: any = nil
local stopResponsive: (() -> ())? = nil
local currentMetrics: ResponsiveLayout.Metrics? = nil

local SLOT_LABELS = {
	Weapon = "Оружие",
	Head = "Голова",
	Chest = "Корпус",
	Gloves = "Перчатки",
	Boots = "Сапоги",
	Accessory = "Аксессуар",
}

local STAT_LABELS = {
	maxHealth = "HP",
	maxResource = "Ресурс",
	physicalAttack = "Физ. атака",
	magicAttack = "Маг. атака",
	physicalDefense = "Защита",
	criticalChance = "Крит",
	attackSpeedMultiplier = "Скорость атаки",
}

local FILTER_ORDER = { "All", "Consumables", "Equipment", "Materials" }

local FILTER_LABELS = {
	All = "ВСЕ",
	Consumables = "ЗЕЛЬЯ",
	Equipment = "ВЕЩИ",
	Materials = "РЕСУРСЫ",
}

local function matchesFilter(definition: any): boolean
	if activeFilter == "All" then return true end
	if definition == nil then return false end
	if activeFilter == "Consumables" then
		local effect = definition.consumableEffect
		return definition.category == "Consumable"
			and effect ~= nil
			and (effect.kind == "HealHP" or effect.kind == "RestoreResource")
	end
	if activeFilter == "Materials" then return definition.category == "Material" end
	if activeFilter == "Equipment" then
		-- "Вещи" contains wearable/weapon gear plus utility consumables such as
		-- return scrolls; actual HP/resource potions stay under "Зелья".
		return definition.category == "Weapon"
			or definition.category == "Armor"
			or definition.category == "Accessory"
			or (definition.category == "Consumable" and definition.consumableEffect ~= nil
				and definition.consumableEffect.kind == "ReturnToSettlement")
	end
	return true
end

local function updateFilterButtons(): ()
	for filterId, button in filterButtons do
		button.BackgroundColor3 = if filterId == activeFilter
			then Color3.fromRGB(78, 94, 54)
			else Color3.fromRGB(42, 45, 56)
	end
end

local function makeLabel(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = Color3.fromRGB(232, 233, 238)
	label.TextSize = textSize or 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, name: string, text: string, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(240, 240, 244)
	button.TextSize = 13
	button.Parent = parent
	return button
end

local function formatModifier(field: string, value: number): string
	if field == "criticalChance" then
		return string.format("%s %+g%%", STAT_LABELS[field] or field, value * 100)
	end
	if field == "attackSpeedMultiplier" then
		return string.format("%s %+g%%", STAT_LABELS[field] or field, value * 100)
	end
	return string.format("%s %+g", STAT_LABELS[field] or field, value)
end

local function findInventoryEntry(instanceId: string): any?
	if currentSnapshot == nil or typeof(currentSnapshot.inventory) ~= "table" then return nil end
	for _, entry in currentSnapshot.inventory do
		if typeof(entry) == "table" and entry.instanceId == instanceId then return entry end
	end
	return nil
end

local function selectedEntry(): (any?, string?)
	if currentSnapshot == nil or selectedIdentifier == nil then return nil, nil end
	if selectedKind == "Inventory" then
		return findInventoryEntry(selectedIdentifier), nil
	end
	if selectedKind == "Equipment" and typeof(currentSnapshot.equipment) == "table" then
		return currentSnapshot.equipment[selectedIdentifier], selectedIdentifier
	end
	return nil, nil
end

local function updateDetails(): ()
	local entry, slot = selectedEntry()
	local details = detailsLabel
	local equip = equipButton
	local unequip = unequipButton
	local use = useButton
	local discard = discardButton
	local quick = quickSlotButton
	if details == nil or equip == nil or unequip == nil or use == nil or discard == nil or quick == nil then return end

	equip.Visible = false
	unequip.Visible = false
	use.Visible = false
	discard.Visible = false
	quick.Visible = false

	if entry == nil or typeof(entry.itemId) ~= "string" then
		details.Text = "Выберите предмет."
		return
	end

	local definition = ItemDefinitions[entry.itemId]
	if definition == nil then
		details.Text = "Неизвестный предмет."
		return
	end

	local lines = {
		definition.displayName,
		string.format("%s · %s · требуется LV %d", definition.grade, definition.rarity, definition.requiredLevel),
	}
	if typeof(entry.quantity) == "number" and entry.quantity > 1 then
		table.insert(lines, string.format("Количество: %d", entry.quantity))
	end
	if slot ~= nil then table.insert(lines, "Экипировано: " .. (SLOT_LABELS[slot] or slot)) end

	for field, value in definition.statModifiers do
		if typeof(value) == "number" and value ~= 0 then
			table.insert(lines, formatModifier(field, value))
		end
	end
	if definition.consumableEffect ~= nil then
		local effectName = if definition.consumableEffect.kind == "HealHP" then "Восстановление HP" else if definition.consumableEffect.kind == "RestoreResource" then "Восстановление ресурса" else "Возвращение в Luna Village"
		table.insert(lines, if definition.consumableEffect.kind == "ReturnToSettlement" then effectName else string.format("%s: %g", effectName, definition.consumableEffect.amount))
	end

	details.Text = table.concat(lines, "\n")
	if selectedKind == "Equipment" then
		unequip.Visible = true
	else
		equip.Visible = definition.equipmentSlot ~= nil
		use.Visible = definition.category == "Consumable"
		quick.Visible = definition.category == "Consumable"
		discard.Visible = true
	end
end

local function select(kind: "Inventory" | "Equipment", identifier: string): ()
	selectedKind = kind
	selectedIdentifier = identifier
	updateDetails()
end

local function rebuildInventory(): ()
	local list = inventoryList
	if list == nil then return end
	for _, child in list:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end

	local entries = if currentSnapshot ~= nil and typeof(currentSnapshot.inventory) == "table"
		then currentSnapshot.inventory
		else {}
	local visibleEntries = {}
	for _, entry in entries do
		if typeof(entry) == "table" and typeof(entry.itemId) == "string" then
			local definition = ItemDefinitions[entry.itemId]
			if matchesFilter(definition) then table.insert(visibleEntries, entry) end
		end
	end

	local visibleSlots = if activeFilter == "All"
		then InventoryConfig.Capacity
		else math.max(5, #visibleEntries)
	for slotIndex = 1, visibleSlots do
		local entry = if activeFilter == "All" then entries[slotIndex] else visibleEntries[slotIndex]
		local text = ""
		if typeof(entry) == "table" and typeof(entry.itemId) == "string" then
			local definition = ItemDefinitions[entry.itemId]
			local displayName = if definition ~= nil then definition.displayName else entry.itemId
			local quantity = if typeof(entry.quantity) == "number" and entry.quantity > 1
				then "\n×" .. tostring(entry.quantity)
				else ""
			text = displayName .. quantity
		end

		local slotSize = if currentMetrics ~= nil and (currentMetrics :: ResponsiveLayout.Metrics).isTouch
			then ResponsiveLayout.scaled(currentMetrics :: ResponsiveLayout.Metrics, 62, 56, 72)
			else 66
		local button = makeButton(
			list,
			"Slot" .. tostring(slotIndex),
			text,
			UDim2.fromOffset(0, 0),
			UDim2.fromOffset(slotSize, slotSize)
		)
		button.LayoutOrder = slotIndex
		button.TextWrapped = true
		button.TextSize = 10
		button.BackgroundColor3 = if text == "" then Color3.fromRGB(31, 33, 41) else Color3.fromRGB(42, 45, 56)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(76, 81, 95)
		stroke.Transparency = if text == "" then 0.35 else 0.15
		stroke.Thickness = 1
		stroke.Parent = button

		if typeof(entry) == "table" and typeof(entry.instanceId) == "string" then
			button.Activated:Connect(function()
				select("Inventory", entry.instanceId)
			end)
		else
			button.Active = false
		end
	end
end

local function rebuildEquipment(): ()
	local container = equipmentList
	if container == nil then return end
	for _, child in container:GetChildren() do child:Destroy() end

	local metrics = currentMetrics
	local touch = metrics ~= nil and (metrics :: ResponsiveLayout.Metrics).isTouch
	local rowHeight = if touch then (metrics :: ResponsiveLayout.Metrics).touchTarget else 34
	local rowGap = if touch then math.max(3, (metrics :: ResponsiveLayout.Metrics).gap / 2) else 4

	for index, slot in InventoryConfig.EquipmentSlots do
		local entry = if currentSnapshot ~= nil and typeof(currentSnapshot.equipment) == "table"
			then currentSnapshot.equipment[slot]
			else nil
		local displayName = "—"
		if typeof(entry) == "table" and typeof(entry.itemId) == "string" then
			local definition = ItemDefinitions[entry.itemId]
			displayName = if definition ~= nil then definition.displayName else entry.itemId
		end
		local button = makeButton(
			container,
			slot,
			string.format("%s: %s", SLOT_LABELS[slot] or slot, displayName),
			UDim2.fromOffset(0, (index - 1) * (rowHeight + rowGap)),
			UDim2.new(1, -4, 0, rowHeight)
		)
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextSize = 11
		if typeof(entry) == "table" then
			button.Activated:Connect(function()
				select("Equipment", slot)
			end)
		end
	end
end

local function updateHeader(): ()
	if currentSnapshot == nil then return end
	if lunaLabel ~= nil then
		lunaLabel.Text = "Luna: " .. tostring(currentSnapshot.luna or 0)
	end
	if capacityLabel ~= nil then
		capacityLabel.Text = string.format("%d / %d", currentSnapshot.used or 0, currentSnapshot.capacity or InventoryConfig.Capacity)
	end
end

local function rebuild(): ()
	updateHeader()
	updateFilterButtons()
	rebuildInventory()
	rebuildEquipment()
	local entry = selectedEntry()
	if entry == nil then
		selectedKind = nil
		selectedIdentifier = nil
	end
	updateDetails()
end

function InventoryUi.setSnapshot(snapshot: any): ()
	currentSnapshot = snapshot
	rebuild()
end

function InventoryUi.showResult(result: any): ()
	if statusLabel == nil or typeof(result) ~= "table" then return end
	if result.ok == true then
		statusLabel.Text = "Готово."
		statusLabel.TextColor3 = Color3.fromRGB(168, 206, 155)
	else
		local reasons = {
			ProfileNotReady = "Профиль ещё загружается.",
			NotOwned = "Предмет вам не принадлежит.",
			WrongArchetype = "Предмет не подходит классу.",
			LevelTooLow = "Недостаточный уровень.",
			InventoryFull = "Инвентарь заполнен.",
			Cooldown = "Предмет ещё на перезарядке.",
			Dead = "Нельзя использовать после смерти.",
			NoEffect = "Сейчас предмет не даст эффекта.",
			NotConsumable = "Этот предмет нельзя использовать.",
			EmptySlot = "Слот пуст.",
			InvalidSlot = "Некорректный слот.",
			DropUnavailable = "Не удалось положить предмет на землю.",
		}
		statusLabel.Text = reasons[result.reason] or "Действие отклонено."
		statusLabel.TextColor3 = Color3.fromRGB(222, 145, 145)
	end
end

local function setPanelOpen(open: boolean): ()
	if root ~= nil then root.Visible = open end
	if modalBlocker ~= nil then modalBlocker.Visible = open end
end

function InventoryUi.toggle(): ()
	if root ~= nil then setPanelOpen(not root.Visible) end
end

function InventoryUi.start(actionCallbacks: any): ()
	InventoryUi.stop()
	callbacks = actionCallbacks

	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	-- The full-screen input blocker is a sibling of InventoryPanel. In Sibling
	-- mode the panel's whole subtree stays above that blocker instead of child
	-- labels/buttons (default ZIndex=1) falling behind it.
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local blocker = Instance.new("TextButton")
	blocker.Name = "ModalBlocker"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundColor3 = Color3.new(0, 0, 0)
	-- Keep the blocker only as an input shield. The previous 55% black overlay
	-- made both the world and low-ZIndex inventory contents look unreadably dim.
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Active = true
	blocker.Modal = true
	blocker.Visible = false
	blocker.ZIndex = 1
	blocker.Parent = gui
	modalBlocker = blocker

	local panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 500)
	HudLayout.applyPanelStyle(panel)
	-- Inventory is a reading-heavy screen; keep it effectively opaque even though
	-- the shared HUD panels intentionally use translucency.
	panel.BackgroundTransparency = 0.03
	panel.Visible = false
	panel.ZIndex = 2
	panel.Parent = gui
	root = panel

	makeLabel(panel, "ИНВЕНТАРЬ", UDim2.fromOffset(16, 8), UDim2.fromOffset(220, 28), 17)
	lunaLabel = makeLabel(panel, "Luna: 0", UDim2.fromOffset(250, 8), UDim2.fromOffset(170, 28), 13)
	capacityLabel = makeLabel(panel, "0 / 40", UDim2.fromOffset(430, 8), UDim2.fromOffset(90, 28), 13)

	local close = HudLayout.makeCloseButton(panel, 12)
	closeConnection = close.Activated:Connect(function() setPanelOpen(false) end)

	local divider = Instance.new("Frame")
	divider.Position = UDim2.fromOffset(16, 44)
	divider.Size = UDim2.new(1, -32, 0, 1)
	divider.BackgroundColor3 = Color3.fromRGB(72, 77, 91)
	divider.BorderSizePixel = 0
	divider.Parent = panel

	local invTitle = makeLabel(panel, "Сумка", UDim2.fromOffset(16, 52), UDim2.fromOffset(380, 24), 13)
	invTitle.Font = Enum.Font.GothamBold
	local equippedTitle = makeLabel(panel, "Экипировка", UDim2.fromOffset(410, 52), UDim2.fromOffset(290, 24), 13)
	equippedTitle.Font = Enum.Font.GothamBold

	for index, filterId in FILTER_ORDER do
		local selectedFilter = filterId
		local button = makeButton(
			panel,
			"Filter" .. selectedFilter,
			FILTER_LABELS[selectedFilter],
			UDim2.fromOffset(16 + (index - 1) * 94, 78),
			UDim2.fromOffset(89, 28)
		)
		button.TextSize = 10
		filterButtons[selectedFilter] = button
		table.insert(actionConnections, button.Activated:Connect(function()
			activeFilter = selectedFilter
			rebuild()
		end))
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "InventoryList"
	list.Position = UDim2.fromOffset(16, 112)
	list.Size = UDim2.fromOffset(376, 356)
	list.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
	list.BackgroundTransparency = 0.15
	list.BorderSizePixel = 0
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ScrollBarThickness = 6
	list.Parent = panel
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = list
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(66, 66)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.FillDirectionMaxCells = 5
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	inventoryList = list

	local equipment = Instance.new("ScrollingFrame")
	equipment.Name = "EquipmentList"
	equipment.Position = UDim2.fromOffset(410, 80)
	equipment.Size = UDim2.fromOffset(294, 224)
	equipment.BackgroundTransparency = 1
	equipment.BorderSizePixel = 0
	equipment.CanvasSize = UDim2.fromOffset(0, 0)
	equipment.AutomaticCanvasSize = Enum.AutomaticSize.Y
	equipment.ScrollingDirection = Enum.ScrollingDirection.Y
	equipment.ScrollBarThickness = 4
	equipment.Parent = panel
	equipmentList = equipment

	detailsLabel = makeLabel(panel, "Выберите предмет.", UDim2.fromOffset(410, 314), UDim2.fromOffset(294, 92), 12)
	detailsLabel.Name = "Details"
	detailsLabel.TextWrapped = true
	detailsLabel.TextYAlignment = Enum.TextYAlignment.Top

	statusLabel = makeLabel(panel, "", UDim2.fromOffset(410, 406), UDim2.fromOffset(294, 20), 11)
	statusLabel.Name = "Status"

	equipButton = makeButton(panel, "Equip", "НАДЕТЬ", UDim2.fromOffset(410, 438), UDim2.fromOffset(68, 32))
	unequipButton = makeButton(panel, "Unequip", "СНЯТЬ", UDim2.fromOffset(410, 438), UDim2.fromOffset(68, 32))
	useButton = makeButton(panel, "Use", "ИСП.", UDim2.fromOffset(482, 438), UDim2.fromOffset(68, 32))
	quickSlotButton = makeButton(panel, "QuickSlot", "НА [0]", UDim2.fromOffset(554, 438), UDim2.fromOffset(68, 32))
	discardButton = makeButton(panel, "Discard", "ВЫБР.", UDim2.fromOffset(626, 438), UDim2.fromOffset(78, 32))

	table.insert(actionConnections, equipButton.Activated:Connect(function()
		if callbacks ~= nil and selectedKind == "Inventory" and selectedIdentifier ~= nil then
			callbacks.equip(selectedIdentifier)
		end
	end))
	table.insert(actionConnections, unequipButton.Activated:Connect(function()
		if callbacks ~= nil and selectedKind == "Equipment" and selectedIdentifier ~= nil then
			callbacks.unequip(selectedIdentifier)
		end
	end))
	table.insert(actionConnections, useButton.Activated:Connect(function()
		if callbacks ~= nil and selectedKind == "Inventory" and selectedIdentifier ~= nil then
			callbacks.consume(selectedIdentifier)
		end
	end))
	table.insert(actionConnections, quickSlotButton.Activated:Connect(function()
		if callbacks == nil or selectedKind ~= "Inventory" or selectedIdentifier == nil then return end
		local entry = findInventoryEntry(selectedIdentifier)
		if entry == nil or typeof(entry.itemId) ~= "string" then return end
		local definition = ItemDefinitions[entry.itemId]
		if definition == nil or definition.category ~= "Consumable" then return end
		if callbacks.assignQuickSlot ~= nil and callbacks.assignQuickSlot(entry.itemId) then
			if statusLabel ~= nil then
				statusLabel.Text = "Предмет назначен на быстрый слот [0]."
				statusLabel.TextColor3 = Color3.fromRGB(168, 206, 155)
			end
		end
	end))
	table.insert(actionConnections, discardButton.Activated:Connect(function()
		if callbacks ~= nil and selectedKind == "Inventory" and selectedIdentifier ~= nil then
			callbacks.discard(selectedIdentifier)
		end
	end))

	local lastSignature = ""
	stopResponsive = ResponsiveLayout.observe(function(metrics)
		currentMetrics = metrics
		local signature = metrics.layoutClass .. ":" .. tostring(metrics.touchTarget) .. ":" .. tostring(math.round(metrics.contentSize.X))
		if signature == lastSignature then return end
		lastSignature = signature

		if metrics.isTouch then
			local filterY = ResponsiveLayout.scaled(metrics, 56, 50, 68)
			for index, filterId in FILTER_ORDER do
				local filter = filterButtons[filterId]
				if filter ~= nil then
					filter.Position = UDim2.new((index - 1) * 0.25, metrics.gap / 2, 0, filterY)
					filter.Size = UDim2.new(0.25, -metrics.gap, 0, metrics.touchTarget)
					filter.TextSize = math.round(ResponsiveLayout.scaled(metrics, 10, 9, 12))
				end
			end
			invTitle.Visible = false
			equippedTitle.Visible = false
			local grid = list:FindFirstChildOfClass("UIGridLayout")
			if grid ~= nil then
				local cell = ResponsiveLayout.scaled(metrics, 62, 56, 72)
				grid.CellSize = UDim2.fromOffset(cell, cell)
				grid.CellPadding = UDim2.fromOffset(metrics.gap, metrics.gap)
			end
		else
			for index, filterId in FILTER_ORDER do
				local filter = filterButtons[filterId]
				if filter ~= nil then
					filter.Position = UDim2.fromOffset(16 + (index - 1) * 94, 78)
					filter.Size = UDim2.fromOffset(89, 28)
					filter.TextSize = 10
				end
			end
			invTitle.Visible = true
			equippedTitle.Visible = true
			local grid = list:FindFirstChildOfClass("UIGridLayout")
			if grid ~= nil then
				grid.CellSize = UDim2.fromOffset(66, 66)
				grid.CellPadding = UDim2.fromOffset(6, 6)
			end
		end
		rebuild()
	end)

	screenGui = gui
	setPanelOpen(false)
	rebuild()
end

function InventoryUi.stop(): ()
	if stopResponsive ~= nil then stopResponsive(); stopResponsive = nil end
	currentMetrics = nil
	if closeConnection ~= nil then closeConnection:Disconnect(); closeConnection = nil end
	for _, connection in actionConnections do connection:Disconnect() end
	table.clear(actionConnections)
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	root = nil
	modalBlocker = nil
	inventoryList = nil
	equipmentList = nil
	detailsLabel = nil
	statusLabel = nil
	lunaLabel = nil
	capacityLabel = nil
	equipButton = nil
	unequipButton = nil
	useButton = nil
	discardButton = nil
	quickSlotButton = nil
	table.clear(filterButtons)
	activeFilter = "All"
	currentSnapshot = nil
	selectedKind = nil
	selectedIdentifier = nil
	callbacks = nil
end

return InventoryUi
