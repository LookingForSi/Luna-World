--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftingDefinitions = require(ReplicatedStorage.Shared.definitions.CraftingDefinitions)
local EconomyRules = require(ReplicatedStorage.Shared.economy.EconomyRules)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local HudLayout = require(script.Parent.Parent.Parent.ui.HudLayout)

local EconomyUi = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil
local modalBlocker: TextButton? = nil
local list: ScrollingFrame? = nil
local title: TextLabel? = nil
local balance: TextLabel? = nil
local status: TextLabel? = nil
local toast: TextLabel? = nil
local snapshot: any = nil
local mode = "DialogueMerchant"
local callbacks: any = nil
local connections: { RBXScriptConnection } = {}
local rowConnections: { RBXScriptConnection } = {}
local sellCart: { [string]: number } = {}
local onboarded = false

local function updateOnboarding(): ()
	local level = Players.LocalPlayer:GetAttribute(ProgressionConfig.LevelAttribute)
	if onboarded or typeof(level) ~= "number" or level < 6 or toast == nil then return end
	onboarded = true
	toast.Visible = true
	task.delay(8, function()
		if toast ~= nil then toast.Visible = false end
	end)
end

local function label(
	parent: Instance,
	text: string,
	position: UDim2,
	size: UDim2,
	fontSize: number
): TextLabel
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Text = text
	value.Position = position
	value.Size = size
	value.Font = Enum.Font.Gotham
	value.TextSize = fontSize
	value.TextColor3 = Color3.fromRGB(225, 222, 211)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = parent
	return value
end

local function button(parent: Instance, text: string): TextButton
	local value = Instance.new("TextButton")
	value.Size = UDim2.new(1, -12, 0, 48)
	value.BackgroundColor3 = Color3.fromRGB(48, 52, 61)
	value.BorderSizePixel = 0
	value.TextColor3 = Color3.fromRGB(232, 220, 184)
	value.Font = Enum.Font.Gotham
	value.TextSize = 12
	value.TextWrapped = true
	value.Text = text
	value.Parent = parent
	return value
end

local function clearList(): ()
	for _, connection in rowConnections do connection:Disconnect() end
	table.clear(rowConnections)
	if list == nil then return end
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function owned(itemId: string): number
	local total = 0
	if snapshot == nil then return total end
	for _, entry in snapshot.inventory do
		if entry.itemId == itemId then total += entry.quantity end
	end
	return total
end

local function inventoryEntry(instanceId: string): any?
	if snapshot == nil then return nil end
	for _, entry in snapshot.inventory do
		if entry.instanceId == instanceId then return entry end
	end
	return nil
end

local function reconcileSellCart(): ()
	for instanceId, quantity in sellCart do
		local entry = inventoryEntry(instanceId)
		local price = if entry ~= nil then EconomyRules.buybackPrice(entry.itemId) else nil
		if entry == nil or price == nil then
			sellCart[instanceId] = nil
		else
			sellCart[instanceId] = math.clamp(math.floor(quantity), 1, entry.quantity)
		end
	end
end

local function sellCartTotal(): number
	local total = 0
	for instanceId, quantity in sellCart do
		local entry = inventoryEntry(instanceId)
		if entry ~= nil then
			local price = EconomyRules.buybackPrice(entry.itemId)
			if price ~= nil then total += price * quantity end
		end
	end
	return total
end

local function createSellPane(parent: Instance, name: string, position: UDim2): ScrollingFrame
	local pane = Instance.new("ScrollingFrame")
	pane.Name = name
	pane.Position = position
	pane.Size = UDim2.new(0.49, 0, 1, -74)
	pane.AutomaticCanvasSize = Enum.AutomaticSize.Y
	pane.CanvasSize = UDim2.fromOffset(0, 0)
	pane.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
	pane.BorderSizePixel = 0
	pane.ScrollBarThickness = 5
	pane.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = pane
	return pane
end

local function sellRow(parent: Instance, height: number): Frame
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, height)
	row.BackgroundColor3 = Color3.fromRGB(43, 46, 54)
	row.BorderSizePixel = 0
	row.Parent = parent
	return row
end

local function statSummary(item: any): string
	local values = {}
	for key, value in item.statModifiers do
		if value ~= 0 then table.insert(values, string.format("%s %+g", key, value)) end
	end
	return table.concat(values, ", ")
end

local function setMode(nextMode: string): ()
	mode = nextMode
	if status ~= nil then status.Text = "" end
end

local function addTopic(text: string, nextMode: string): ()
	if list == nil then return end
	local row = button(list, text)
	row.TextSize = 15
	row.Font = Enum.Font.GothamBold
	table.insert(rowConnections, row.Activated:Connect(function()
		setMode(nextMode)
		EconomyUi.open(nextMode)
	end))
end

local function dialogueModeForCurrent(): string
	return if string.sub(mode, 1, 5) == "Craft" then "DialogueBlacksmith" else "DialogueMerchant"
end

local function addBackToDialogue(): ()
	if list == nil then return end
	local row = button(list, "← Назад к диалогу")
	row.Size = UDim2.new(1, -12, 0, 36)
	table.insert(rowConnections, row.Activated:Connect(function()
		EconomyUi.open(dialogueModeForCurrent())
	end))
end

local function rebuildDialogue(): boolean
	if title == nil then return false end
	if mode == "DialogueMerchant" then
		title.Text = "ДИАЛОГ — ТОРГОВЕЦ"
		addTopic("Купить", "Buy")
		addTopic("Продать", "Sell")
		return true
	elseif mode == "DialogueBlacksmith" then
		title.Text = "ДИАЛОГ — КУЗНЕЦ"
		addTopic("Ковать — Рыцарь", "CraftKnight")
		addTopic("Ковать — Следопыт", "CraftRanger")
		addTopic("Ковать — Мистик", "CraftMystic")
		addTopic("Обработать материалы", "CraftMaterial")
		return true
	end
	return false
end

local rebuild: () -> ()

local function rebuildSell(): ()
	if list == nil or snapshot == nil then return end
	reconcileSellCart()
	if title ~= nil then title.Text = "ТОРГОВЕЦ — ПРОДАТЬ" end

	local workspace = Instance.new("Frame")
	workspace.Name = "SellWorkspace"
	workspace.Size = UDim2.new(1, -12, 0, 350)
	workspace.BackgroundTransparency = 1
	workspace.Parent = list

	label(workspace, "ИНВЕНТАРЬ", UDim2.fromOffset(4, 0), UDim2.new(0.49, -4, 0, 24), 12).Font = Enum.Font.GothamBold
	label(workspace, "К ПРОДАЖЕ", UDim2.new(0.51, 0, 0, 0), UDim2.new(0.49, -4, 0, 24), 12).Font = Enum.Font.GothamBold

	local inventoryPane = createSellPane(workspace, "SellInventory", UDim2.fromOffset(0, 28))
	local cartPane = createSellPane(workspace, "SellCart", UDim2.new(0.51, 0, 0, 28))

	for _, entry in snapshot.inventory do
		local item = ItemDefinitions[entry.itemId]
		local price = EconomyRules.buybackPrice(entry.itemId)
		local row = sellRow(inventoryPane, 62)
		local itemText = if price ~= nil
			then string.format("%s ×%d\n%d Luna / шт.", item.displayName, entry.quantity, price)
			else string.format("%s ×%d\nне продаётся", item.displayName, entry.quantity)
		local name = label(row, itemText, UDim2.fromOffset(8, 4), UDim2.new(1, -108, 1, -8), 11)
		name.TextWrapped = true

		local quantity = Instance.new("TextBox")
		quantity.Name = "Quantity"
		quantity.Position = UDim2.new(1, -98, 0, 8)
		quantity.Size = UDim2.fromOffset(42, 28)
		quantity.BackgroundColor3 = Color3.fromRGB(31, 34, 41)
		quantity.BorderSizePixel = 0
		quantity.TextColor3 = Color3.fromRGB(238, 235, 224)
		quantity.Font = Enum.Font.GothamBold
		quantity.TextSize = 12
		quantity.ClearTextOnFocus = false
		quantity.Text = tostring(sellCart[entry.instanceId] or 1)
		quantity.Active = price ~= nil
		quantity.Parent = row

		local add = button(row, "→")
		add.Position = UDim2.new(1, -50, 0, 8)
		add.Size = UDim2.fromOffset(42, 28)
		add.TextSize = 16
		add.Active = price ~= nil
		add.AutoButtonColor = price ~= nil
		add.BackgroundTransparency = if price ~= nil then 0 else 0.55
		if price ~= nil then
			local function normalizedQuantity(): number
				local requested = tonumber(quantity.Text) or 1
				return math.clamp(math.floor(requested), 1, entry.quantity)
			end
			local function putInCart(): ()
				local normalized = normalizedQuantity()
				quantity.Text = tostring(normalized)
				sellCart[entry.instanceId] = normalized
				rebuild()
			end
			table.insert(rowConnections, add.Activated:Connect(putInCart))
			table.insert(rowConnections, quantity.FocusLost:Connect(function(enterPressed: boolean)
				local normalized = normalizedQuantity()
				quantity.Text = tostring(normalized)
				if sellCart[entry.instanceId] ~= nil or enterPressed then
					sellCart[entry.instanceId] = normalized
					rebuild()
				end
			end))
		end
	end

	for _, entry in snapshot.inventory do
		local selectedQuantity = sellCart[entry.instanceId]
		if selectedQuantity == nil then continue end
		local item = ItemDefinitions[entry.itemId]
		local price = EconomyRules.buybackPrice(entry.itemId)
		if price == nil then continue end
		local row = sellRow(cartPane, 54)
		local name = label(
			row,
			string.format("%s ×%d\n+%d Luna", item.displayName, selectedQuantity, price * selectedQuantity),
			UDim2.fromOffset(8, 3),
			UDim2.new(1, -60, 1, -6),
			11
		)
		name.TextWrapped = true
		local remove = button(row, "←")
		remove.Position = UDim2.new(1, -50, 0, 10)
		remove.Size = UDim2.fromOffset(42, 28)
		remove.TextSize = 16
		table.insert(rowConnections, remove.Activated:Connect(function()
			sellCart[entry.instanceId] = nil
			rebuild()
		end))
	end

	local total = sellCartTotal()
	local totalLabel = label(
		workspace,
		string.format("Итого к получению: %d Luna", total),
		UDim2.new(0, 4, 1, -38),
		UDim2.new(0.51, -8, 0, 34),
		13
	)
	totalLabel.Name = "SellTotal"
	totalLabel.Font = Enum.Font.GothamBold

	local confirm = button(workspace, if total > 0 then string.format("ПРОДАТЬ ВЫБРАННОЕ · +%d Luna", total) else "ПРОДАТЬ ВЫБРАННОЕ")
	confirm.Name = "SellConfirm"
	confirm.Position = UDim2.new(0.51, 0, 1, -42)
	confirm.Size = UDim2.new(0.49, 0, 0, 36)
	confirm.TextSize = 11
	confirm.Active = total > 0
	confirm.AutoButtonColor = total > 0
	confirm.BackgroundTransparency = if total > 0 then 0 else 0.55
	if total > 0 then
		table.insert(rowConnections, confirm.Activated:Connect(function()
			local selections = {}
			for _, entry in snapshot.inventory do
				local selectedQuantity = sellCart[entry.instanceId]
				if selectedQuantity ~= nil then
					table.insert(selections, { instanceId = entry.instanceId, quantity = selectedQuantity })
				end
			end
			if #selections > 0 and callbacks ~= nil and callbacks.sellBatch ~= nil then
				callbacks.sellBatch(selections)
			end
		end))
	end
end

rebuild = function(): ()
	clearList()
	if list == nil then return end

	if balance ~= nil then
		balance.Text = if snapshot ~= nil then string.format("Luna: %d", snapshot.luna) else "Luna: —"
	end
	if rebuildDialogue() then return end
	if snapshot == nil then return end

	addBackToDialogue()

	if string.sub(mode, 1, 5) == "Craft" then
		local discipline = string.sub(mode, 6)
		local disciplineNames = { Knight = "РЫЦАРЬ", Ranger = "СЛЕДОПЫТ", Mystic = "МИСТИК" }
		if title ~= nil then title.Text = if discipline == "Material" then "КУЗНЕЦ — ОБРАБОТКА" else "КУЗНЕЦ — " .. disciplineNames[discipline] end
		for _, entry in snapshot.crafts do
			local recipe = CraftingDefinitions[entry.craftId]
			if recipe.discipline ~= discipline and not (recipe.outputItemId == "accessory_silver_moon_charm" and discipline ~= "Material") then continue end
			local output = ItemDefinitions[recipe.outputItemId]
			local parts = {}
			local levelReady = snapshot.level >= recipe.requiredLevel
			local lunaReady = snapshot.luna >= recipe.fee
			local materialsReady = true
			for _, material in recipe.ingredients do
				local have = owned(material.itemId)
				if have < material.quantity then materialsReady = false end
				table.insert(parts, string.format(
					"%s %d/%d",
					ItemDefinitions[material.itemId].displayName,
					have,
					material.quantity
				))
			end
			local available = levelReady and lunaReady and materialsReady
			local state = if not levelReady then "Нужен уровень" else if not lunaReady then "Не хватает Luna" else if not materialsReady then "Не хватает материалов" else "Доступно"
			local outputSuffix = if recipe.outputQuantity > 1 then string.format(" ×%d", recipe.outputQuantity) else ""
			local details = if discipline == "Material"
				then string.format("%s → %s%s · %d Luna", table.concat(parts, ", "), output.displayName, outputSuffix, recipe.fee)
				else string.format("%s\n%s · %d Luna", statSummary(output), table.concat(parts, ", "), recipe.fee)
			local row = button(list, string.format(
				"%s%s [%s] · LV%d\n%s · %s",
				output.displayName,
				outputSuffix,
				output.grade,
				recipe.requiredLevel,
				details,
				state
			))
			row.Size = UDim2.new(1, -12, 0, 68)
			row.Active = available
			row.AutoButtonColor = available
			row.BackgroundTransparency = if available then 0 else 0.45
			if available then
				table.insert(rowConnections, row.Activated:Connect(function() callbacks.craft(entry.craftId) end))
			end
		end
	elseif mode == "Buy" then
		if title ~= nil then title.Text = "ТОРГОВЕЦ — КУПИТЬ" end
		for _, entry in snapshot.stock do
			local item = ItemDefinitions[entry.itemId]
			local row = button(list, string.format(
				"%s [%s] · %s · %d Luna",
				item.displayName,
				item.grade,
				statSummary(item),
				entry.price
			))
			table.insert(rowConnections, row.Activated:Connect(function()
				callbacks.buy(entry.itemId)
			end))
		end
	elseif mode == "Sell" then
		rebuildSell()
	end
end

function EconomyUi.open(nextMode: string): ()
	setMode(nextMode)
	if panel ~= nil then panel.Visible = true end
	if modalBlocker ~= nil then modalBlocker.Visible = true end
	rebuild()
end

function EconomyUi.setSnapshot(value: any): ()
	snapshot = value
	rebuild()
	updateOnboarding()
end

function EconomyUi.showResult(value: any): ()
	if status == nil then return end
	if value.ok then
		if value.action == "SellBatch" then
			table.clear(sellCart)
			status.Text = string.format("Продано. Получено %d Luna.", value.totalLuna or 0)
			rebuild()
		else
			status.Text = "Готово."
		end
		status.TextColor3 = Color3.fromRGB(145, 211, 161)
	else
		local reasons = {
			TooFar = "Подойдите ближе к NPC.",
			InsufficientLuna = "Недостаточно Luna.",
			InsufficientMaterials = "Не хватает материалов.",
			LevelTooLow = "Недостаточный уровень.",
			InventoryFull = "Инвентарь заполнен.",
			EquippedItem = "Сначала снимите предмет.",
			NotForSale = "Этот предмет не продаётся.",
			InvalidQuantity = "Количество изменилось. Обновите корзину.",
			NotOwned = "Предмет уже отсутствует в инвентаре.",
		}
		status.Text = reasons[value.reason] or "Операция отклонена."
		status.TextColor3 = Color3.fromRGB(222, 145, 145)
	end
end

function EconomyUi.start(actionCallbacks: any): ()
	callbacks = actionCallbacks

	local screen = Instance.new("ScreenGui")
	screen.Name = "VillageEconomyUi"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 9
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local blocker = Instance.new("TextButton")
	blocker.Name = "ModalBlocker"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundColor3 = Color3.new(0, 0, 0)
	-- Input shield only. Do not visually darken the world or the modal contents.
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Active = true
	blocker.Modal = true
	blocker.Visible = false
	blocker.ZIndex = 1
	blocker.Parent = screen
	modalBlocker = blocker

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(680, 500)
	HudLayout.applyPanelStyle(root)
	root.BackgroundTransparency = 0.03
	root.Visible = false
	root.Name = "EconomyPanel"
	root.ZIndex = 2
	root.Parent = screen

	title = label(root, "ДИАЛОГ", UDim2.fromOffset(16, 10), UDim2.fromOffset(350, 28), 17)
	balance = label(root, "Luna: 0", UDim2.fromOffset(400, 10), UDim2.fromOffset(160, 28), 13)

	local close = HudLayout.makeCloseButton(root, 12)
	table.insert(connections, close.Activated:Connect(function()
		root.Visible = false
		if modalBlocker ~= nil then modalBlocker.Visible = false end
	end))

	local scrolling = Instance.new("ScrollingFrame")
	scrolling.Name = "DialogueTopics"
	scrolling.Position = UDim2.fromOffset(16, 52)
	scrolling.Size = UDim2.new(1, -32, 1, -100)
	scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrolling.CanvasSize = UDim2.fromOffset(0, 0)
	scrolling.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
	scrolling.BorderSizePixel = 0
	scrolling.ScrollBarThickness = 6
	scrolling.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scrolling
	list = scrolling

	status = label(root, "", UDim2.new(0, 16, 1, -38), UDim2.new(1, -32, 0, 24), 12)
	toast = label(
		screen,
		"У тебя уже есть материалы — кузнец в Luna Village может обработать сырьё и изготовить No-Grade экипировку. Торговец покупает добычу и продаёт расходники.",
		UDim2.new(0.5, -300, 0, 80),
		UDim2.fromOffset(600, 70),
		14
	)
	toast.BackgroundTransparency = 0.12
	toast.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
	toast.TextWrapped = true
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.Visible = false

	table.insert(connections, Players.LocalPlayer:GetAttributeChangedSignal(ProgressionConfig.LevelAttribute):Connect(updateOnboarding))
	gui = screen
	panel = root
	updateOnboarding()
end

function EconomyUi.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)
	clearList()
	if gui ~= nil then gui:Destroy(); gui = nil end
	panel = nil
	modalBlocker = nil
	list = nil
	title = nil
	balance = nil
	status = nil
	toast = nil
	snapshot = nil
	callbacks = nil
	table.clear(sellCart)
	mode = "DialogueMerchant"
end

return EconomyUi
