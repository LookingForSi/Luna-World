--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local HudLayout = require(script.Parent.HudLayout)

local InventoryUi = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local root: Frame? = nil
local inventoryList: ScrollingFrame? = nil
local equipmentList: Frame? = nil
local detailsLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local lunaLabel: TextLabel? = nil
local capacityLabel: TextLabel? = nil
local equipButton: TextButton? = nil
local unequipButton: TextButton? = nil
local useButton: TextButton? = nil
local discardButton: TextButton? = nil
local closeConnection: RBXScriptConnection? = nil
local actionConnections: { RBXScriptConnection } = {}
local currentSnapshot: any = nil
local selectedKind: "Inventory" | "Equipment"? = nil
local selectedIdentifier: string? = nil
local callbacks: any = nil

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
	if details == nil then return end

	equipButton.Visible = false
	unequipButton.Visible = false
	useButton.Visible = false
	discardButton.Visible = false

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
		string.format("%s · требуется LV %d", definition.rarity, definition.requiredLevel),
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
		local effectName = if definition.consumableEffect.kind == "HealHP" then "Восстановление HP" else "Восстановление ресурса"
		table.insert(lines, string.format("%s: %g", effectName, definition.consumableEffect.amount))
	end

	details.Text = table.concat(lines, "\n")
	if selectedKind == "Equipment" then
		unequipButton.Visible = true
	else
		equipButton.Visible = definition.equipmentSlot ~= nil
		useButton.Visible = definition.category == "Consumable"
		discardButton.Visible = true
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
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end

	if currentSnapshot == nil or typeof(currentSnapshot.inventory) ~= "table" then return end
	for index, entry in currentSnapshot.inventory do
		if typeof(entry) ~= "table" or typeof(entry.instanceId) ~= "string" or typeof(entry.itemId) ~= "string" then continue end
		local definition = ItemDefinitions[entry.itemId]
		local displayName = if definition ~= nil then definition.displayName else entry.itemId
		local quantity = if typeof(entry.quantity) == "number" and entry.quantity > 1 then " ×" .. tostring(entry.quantity) else ""
		local button = makeButton(
			list,
			"Item" .. tostring(index),
			displayName .. quantity,
			UDim2.fromOffset(0, 0),
			UDim2.new(1, -8, 0, 34)
		)
		button.LayoutOrder = index
		button.TextXAlignment = Enum.TextXAlignment.Left
		button.TextSize = 12
		button.Activated:Connect(function()
			select("Inventory", entry.instanceId)
		end)
	end
end

local function rebuildEquipment(): ()
	local container = equipmentList
	if container == nil then return end
	for _, child in container:GetChildren() do child:Destroy() end

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
			UDim2.fromOffset(0, (index - 1) * 38),
			UDim2.new(1, 0, 0, 34)
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
		}
		statusLabel.Text = reasons[result.reason] or "Действие отклонено."
		statusLabel.TextColor3 = Color3.fromRGB(222, 145, 145)
	end
end

function InventoryUi.toggle(): ()
	if root ~= nil then root.Visible = not root.Visible end
end

function InventoryUi.start(actionCallbacks: any): ()
	InventoryUi.stop()
	callbacks = actionCallbacks

	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "InventoryPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(720, 500)
	HudLayout.applyPanelStyle(panel)
	panel.Visible = false
	panel.Parent = gui

	makeLabel(panel, "ИНВЕНТАРЬ", UDim2.fromOffset(16, 8), UDim2.fromOffset(220, 28), 17)
	lunaLabel = makeLabel(panel, "Luna: 0", UDim2.fromOffset(250, 8), UDim2.fromOffset(170, 28), 13)
	capacityLabel = makeLabel(panel, "0 / 40", UDim2.fromOffset(430, 8), UDim2.fromOffset(90, 28), 13)

	local close = makeButton(panel, "Close", "×", UDim2.new(1, -46, 0, 8), UDim2.fromOffset(32, 28))
	close.TextSize = 18
	closeConnection = close.Activated:Connect(function() panel.Visible = false end)

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

	local list = Instance.new("ScrollingFrame")
	list.Name = "InventoryList"
	list.Position = UDim2.fromOffset(16, 80)
	list.Size = UDim2.fromOffset(376, 388)
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
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	inventoryList = list

	local equipment = Instance.new("Frame")
	equipment.Name = "EquipmentList"
	equipment.Position = UDim2.fromOffset(410, 80)
	equipment.Size = UDim2.fromOffset(294, 224)
	equipment.BackgroundTransparency = 1
	equipment.Parent = panel
	equipmentList = equipment

	detailsLabel = makeLabel(panel, "Выберите предмет.", UDim2.fromOffset(410, 314), UDim2.fromOffset(294, 92), 12)
	detailsLabel.TextWrapped = true
	detailsLabel.TextYAlignment = Enum.TextYAlignment.Top

	statusLabel = makeLabel(panel, "", UDim2.fromOffset(410, 406), UDim2.fromOffset(294, 20), 11)

	equipButton = makeButton(panel, "Equip", "НАДЕТЬ", UDim2.fromOffset(410, 438), UDim2.fromOffset(92, 32))
	unequipButton = makeButton(panel, "Unequip", "СНЯТЬ", UDim2.fromOffset(410, 438), UDim2.fromOffset(92, 32))
	useButton = makeButton(panel, "Use", "ИСП.", UDim2.fromOffset(508, 438), UDim2.fromOffset(92, 32))
	discardButton = makeButton(panel, "Discard", "ВЫБРОСИТЬ", UDim2.fromOffset(606, 438), UDim2.fromOffset(98, 32))

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
	table.insert(actionConnections, discardButton.Activated:Connect(function()
		if callbacks ~= nil and selectedKind == "Inventory" and selectedIdentifier ~= nil then
			callbacks.discard(selectedIdentifier)
		end
	end))

	screenGui = gui
	root = panel
	rebuild()
end

function InventoryUi.stop(): ()
	if closeConnection ~= nil then closeConnection:Disconnect(); closeConnection = nil end
	for _, connection in actionConnections do connection:Disconnect() end
	table.clear(actionConnections)
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	root = nil
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
	currentSnapshot = nil
	selectedKind = nil
	selectedIdentifier = nil
	callbacks = nil
end

return InventoryUi
