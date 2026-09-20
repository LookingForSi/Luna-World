--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CraftingDefinitions = require(ReplicatedStorage.Shared.definitions.CraftingDefinitions)
local EconomyRules = require(ReplicatedStorage.Shared.economy.EconomyRules)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local HudLayout = require(script.Parent.HudLayout)

local EconomyUi = {}

local gui: ScreenGui? = nil
local panel: Frame? = nil
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
		if child:IsA("GuiButton") then child:Destroy() end
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
	return if mode == "Craft" then "DialogueBlacksmith" else "DialogueMerchant"
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
		addTopic("Ковать", "Craft")
		return true
	end
	return false
end

local function rebuild(): ()
	clearList()
	if list == nil then return end

	if balance ~= nil then
		balance.Text = if snapshot ~= nil then string.format("Luna: %d", snapshot.luna) else "Luna: —"
	end
	if rebuildDialogue() then return end
	if snapshot == nil then return end

	addBackToDialogue()

	if mode == "Craft" then
		if title ~= nil then title.Text = "КУЗНЕЦ — КОВАТЬ" end
		for _, entry in snapshot.crafts do
			local recipe = CraftingDefinitions[entry.craftId]
			local output = ItemDefinitions[recipe.outputItemId]
			local parts = {}
			local available = snapshot.luna >= recipe.fee
			for _, material in recipe.ingredients do
				local have = owned(material.itemId)
				if have < material.quantity then available = false end
				table.insert(parts, string.format(
					"%s %d/%d",
					ItemDefinitions[material.itemId].displayName,
					have,
					material.quantity
				))
			end
			local row = button(list, string.format(
				"%s [%s] · %s · %d Luna\n%s",
				output.displayName,
				output.grade,
				statSummary(output),
				recipe.fee,
				table.concat(parts, ", ")
			))
			row.AutoButtonColor = available
			row.BackgroundTransparency = if available then 0 else 0.45
			table.insert(rowConnections, row.Activated:Connect(function()
				callbacks.craft(entry.craftId)
			end))
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
		if title ~= nil then title.Text = "ТОРГОВЕЦ — ПРОДАТЬ" end
		for _, entry in snapshot.inventory do
			local item = ItemDefinitions[entry.itemId]
			local price = EconomyRules.buybackPrice(entry.itemId)
			if price ~= nil then
				local row = button(list, string.format(
					"%s ×%d · %d Luna",
					item.displayName,
					entry.quantity,
					price
				))
				table.insert(rowConnections, row.Activated:Connect(function()
					callbacks.sell(entry.instanceId)
				end))
			end
		end
	end
end

function EconomyUi.open(nextMode: string): ()
	setMode(nextMode)
	if panel ~= nil then panel.Visible = true end
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
		status.Text = "Готово."
		status.TextColor3 = Color3.fromRGB(145, 211, 161)
	else
		local reasons = {
			TooFar = "Подойдите ближе к NPC.",
			InsufficientLuna = "Недостаточно Luna.",
			InsufficientMaterials = "Не хватает материалов.",
			InventoryFull = "Инвентарь заполнен.",
			EquippedItem = "Сначала снимите предмет.",
			NotForSale = "Этот предмет не продаётся.",
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
	screen.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(680, 500)
	HudLayout.applyPanelStyle(root)
	root.Visible = false
	root.Parent = screen

	title = label(root, "ДИАЛОГ", UDim2.fromOffset(16, 10), UDim2.fromOffset(350, 28), 17)
	balance = label(root, "Luna: 0", UDim2.fromOffset(400, 10), UDim2.fromOffset(160, 28), 13)

	local close = HudLayout.makeCloseButton(root, 12)
	table.insert(connections, close.Activated:Connect(function()
		root.Visible = false
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
		"У тебя уже есть материалы — кузнец в Luna Village может изготовить No-Grade экипировку. Торговец покупает loot и продаёт материалы и расходники.",
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
	list = nil
	title = nil
	balance = nil
	status = nil
	toast = nil
	snapshot = nil
	callbacks = nil
	mode = "DialogueMerchant"
end

return EconomyUi
