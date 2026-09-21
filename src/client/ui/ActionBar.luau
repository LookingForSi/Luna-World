--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.progression.ProgressionRules)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local HudLayout = require(script.Parent.HudLayout)
local ResponsiveLayout = require(script.Parent.ResponsiveLayout)

local ActionBar = {}
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local autoButton: TextButton? = nil
local attackButton: TextButton? = nil
local inventoryButton: TextButton? = nil
local mapButton: TextButton? = nil
local questButton: TextButton? = nil
local quickSlotButton: TextButton? = nil
local quickUseCallback: (() -> ())? = nil
local quickStateCallback: (() -> any)? = nil
local autoConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local inputTypeConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}
local skillButtons: { [string]: TextButton } = {}
local skillResourceTypes: { [string]: string } = {}

local function makeButton(parent: Instance, name: string, text: string, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(240, 240, 244)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextWrapped = true
	button.Text = text
	button.Parent = parent
	return button
end

local function autoBindingHint(): string
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "L2"
	end
	return "G"
end

local function inventoryBindingText(): string
	local inputType = UserInputService:GetLastInputType()
	if inputType == Enum.UserInputType.Touch then
		return "ИНВЕНТАРЬ"
	end
	if string.find(inputType.Name, "Gamepad") ~= nil then
		return "ИНВЕНТАРЬ [SELECT]"
	end
	return "ИНВЕНТАРЬ [T]"
end

local function mapBindingText(): string
	local inputType = UserInputService:GetLastInputType()
	if inputType == Enum.UserInputType.Touch or string.find(inputType.Name, "Gamepad") ~= nil then
		return "КАРТА"
	end
	return "КАРТА [M]"
end

local function questBindingText(): string
	local inputType = UserInputService:GetLastInputType()
	if inputType == Enum.UserInputType.Touch or string.find(inputType.Name, "Gamepad") ~= nil then
		return "ЗАДАНИЯ"
	end
	return "ЗАДАНИЯ [Y]"
end

local function updateBindingHints(): ()
	if inventoryButton ~= nil then
		inventoryButton.Text = inventoryBindingText()
	end
	if mapButton ~= nil then
		mapButton.Text = mapBindingText()
	end
	if questButton ~= nil then
		questButton.Text = questBindingText()
	end
end

local function updateAuto(): ()
	if autoButton == nil then return end
	local enabled = player:GetAttribute(CombatConfig.AutoAttackEnabledAttribute) == true
	local hint = if UserInputService:GetLastInputType() == Enum.UserInputType.Touch
		then "AUTO"
		else string.format("AUTO [%s]", autoBindingHint())
	autoButton.Text = hint .. if enabled then "\nВКЛ" else "\nВЫКЛ"
	autoButton.BackgroundColor3 = if enabled then Color3.fromRGB(91, 105, 58) else Color3.fromRGB(42, 45, 56)
end

local function updateCooldowns(): ()
	local now = workspace:GetServerTimeNow()
	if attackButton ~= nil then
		local readyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
		local remaining = if typeof(readyAt) == "number" then math.max(0, readyAt - now) else 0
		attackButton.Text = if remaining > 0 then string.format("АТАКА\n%.1f", remaining) else "АТАКА"
	end

	if quickSlotButton ~= nil and quickStateCallback ~= nil then
		local quickState = quickStateCallback()
		local itemId = if typeof(quickState) == "table" then quickState.itemId else nil
		local quantity = if typeof(quickState) == "table" and typeof(quickState.quantity) == "number" then quickState.quantity else 0
		if typeof(itemId) == "string" then
			local definition = ItemDefinitions[itemId]
			local displayName = if definition ~= nil then definition.displayName else itemId
			quickSlotButton.Text = if UserInputService:GetLastInputType() == Enum.UserInputType.Touch
				then string.format("%s ×%d", displayName, quantity)
				else string.format("[0]\n%s ×%d", displayName, quantity)
			quickSlotButton.Active = quantity > 0
			quickSlotButton.TextTransparency = if quantity > 0 then 0 else 0.45
			quickSlotButton.BackgroundColor3 = if quantity > 0 then Color3.fromRGB(42, 45, 56) else Color3.fromRGB(33, 35, 43)
		else
			quickSlotButton.Text = if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then "БЫСТРО" else "[0]"
			quickSlotButton.Active = false
			quickSlotButton.TextTransparency = 0.45
			quickSlotButton.BackgroundColor3 = Color3.fromRGB(33, 35, 43)
		end
	end

	local rawLevel = player:GetAttribute(ProgressionConfig.LevelAttribute)
	local level = if typeof(rawLevel) == "number" then rawLevel else 1
	for skillId, button in skillButtons do
		local definition = SkillDefinitions[skillId]
		if definition == nil then continue end
		local unlocked = ProgressionRules.isSkillUnlocked(definition.unlockLevel, level)
		if not unlocked then
			-- Keep the ten-slot bar stable, but reveal skill names only when the
			-- character actually unlocks them.
			button.Text = ""
			button.Active = false
			button.TextTransparency = 1
			button.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
			continue
		end

		local readyAt = player:GetAttribute(CombatConfig.SkillCooldownAttributePrefix .. skillId)
		local remaining = if typeof(readyAt) == "number" then math.max(0, readyAt - now) else 0
		button.Text = if remaining > 0
			then string.format("%s\n%.1f", definition.displayName, remaining)
			else definition.displayName

		local currentResource = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
		local resourceType = player:GetAttribute(CombatConfig.ResourceTypeAttribute)
		local hasResource = typeof(currentResource) == "number"
			and resourceType == skillResourceTypes[skillId]
			and currentResource >= definition.resourceCost
		button.Active = remaining <= 0 and hasResource
		button.TextTransparency = if button.Active then 0 else 0.45
		button.BackgroundColor3 = if button.Active then Color3.fromRGB(42, 45, 56) else Color3.fromRGB(33, 35, 43)
	end
end

local function buildSkillBar(gui: ScreenGui, skillIds: { string }, onSkill: (string) -> ()): ()
	local metrics = ResponsiveLayout.metrics(workspace.CurrentCamera)
	local mobileLandscape = metrics.mode == "MobileLandscape"
	local slotCount = if mobileLandscape then 6 else 10
	local quickSlotIndex = slotCount
	local width = if mobileLandscape then 306 elseif UserInputService.TouchEnabled then 350 else HudLayout.SkillBarSize.X
	local skillFrame = Instance.new("Frame")
	skillFrame.Name = "SkillBar"
	skillFrame.AnchorPoint = Vector2.new(1, 1)
	skillFrame.Position = UDim2.new(
		1,
		-(HudLayout.ActionBarSize.X + HudLayout.CornerMargin + 12),
		1,
		-HudLayout.CornerMargin
	)
	skillFrame.Size = UDim2.fromOffset(width, HudLayout.SkillBarSize.Y)
	HudLayout.applyPanelStyle(skillFrame)
	skillFrame.Parent = gui

	local content = Instance.new("Frame")
	content.Name = "SkillSlots"
	content.Position = UDim2.fromOffset(5, 5)
	content.Size = UDim2.new(1, -10, 1, -10)
	content.BackgroundTransparency = 1
	content.Parent = skillFrame

	for index = 1, slotCount do
		local skillId = skillIds[index]
		local button = makeButton(
			content,
			"SkillSlot" .. tostring(index),
			"",
			UDim2.new(1 / slotCount, -4, 1, 0)
		)
		button.Position = UDim2.new((index - 1) / slotCount, 2, 0, 0)
		button.TextSize = if UserInputService.TouchEnabled then 8 else 10

		if index == quickSlotIndex then
			quickSlotButton = button
			button.Text = if UserInputService.TouchEnabled then "БЫСТРО" else "[0]"
			table.insert(buttonConnections, button.Activated:Connect(function()
				if quickUseCallback ~= nil then quickUseCallback() end
			end))
			continue
		end

		if skillId ~= nil then
			local definition = SkillDefinitions[skillId]
			if definition ~= nil then
				skillButtons[skillId] = button
				skillResourceTypes[skillId] = definition.resourceType
				table.insert(buttonConnections, button.Activated:Connect(function()
					onSkill(skillId)
				end))
			end
		else
			button.Active = false
			button.BackgroundColor3 = Color3.fromRGB(29, 31, 39)
		end
	end
end

function ActionBar.start(
	skillIds: { string },
	onAttack: () -> (),
	onAutoToggle: () -> (),
	onSkill: (string) -> (),
	onClearTarget: () -> (),
	onInventoryToggle: () -> (),
	onMapToggle: () -> (),
	onQuestToggle: () -> (),
	onQuickUse: () -> (),
	getQuickState: () -> any
): ()
	ActionBar.stop()
	quickUseCallback = onQuickUse
	quickStateCallback = getQuickState

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatActionBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local mobileLandscape = ResponsiveLayout.metrics(workspace.CurrentCamera).mode == "MobileLandscape"
	local actionHeight = if mobileLandscape then 112 elseif UserInputService.TouchEnabled then HudLayout.ActionBarSize.Y + 12 else HudLayout.ActionBarSize.Y
	local frame = Instance.new("Frame")
	frame.Name = "PrimaryActions"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -HudLayout.CornerMargin, 1, -HudLayout.CornerMargin)
	frame.Size = UDim2.fromOffset(HudLayout.ActionBarSize.X, actionHeight)
	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(HudLayout.ActionBarSize.X, actionHeight)
	sizeConstraint.MinSize = Vector2.new(300, actionHeight)
	sizeConstraint.Parent = frame
	HudLayout.applyPanelStyle(frame)
	frame.Parent = gui

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(HudLayout.InnerPadding, HudLayout.InnerPadding)
	content.Size = UDim2.new(1, -HudLayout.InnerPadding * 2, 1, -HudLayout.InnerPadding * 2)
	content.BackgroundTransparency = 1
	content.Parent = frame

	mapButton = makeButton(content, "Map", mapBindingText(), UDim2.new(0.31, -2, 0, if mobileLandscape then 34 else 36))
	local mapToggle = mapButton :: TextButton

	questButton = makeButton(content, "Quests", questBindingText(), UDim2.new(0.31, -2, 0, 36))
	local quests = questButton :: TextButton
	quests.Position = UDim2.new(0.345, 0, 0, 0)

	inventoryButton = makeButton(content, "Inventory", inventoryBindingText(), UDim2.new(0.31, -2, 0, 36))
	local inventory = inventoryButton :: TextButton
	inventory.Position = UDim2.new(0.69, 0, 0, 0)

	local lowerRowHeight = if mobileLandscape then 62 elseif UserInputService.TouchEnabled then 104 else 92
	autoButton = makeButton(content, "Auto", "AUTO [G]\nВЫКЛ", UDim2.new(0.31, -2, 0, lowerRowHeight))
	local auto = autoButton :: TextButton
	auto.Position = UDim2.new(0, 0, 0, 42)

	local clearButton = makeButton(content, "ClearTarget", "СБРОС\nЦЕЛИ", UDim2.new(0.31, -2, 0, lowerRowHeight))
	clearButton.Position = UDim2.new(0.345, 0, 0, 42)

	local attackDiameter = lowerRowHeight
	attackButton = makeButton(content, "Attack", "АТАКА", UDim2.fromOffset(attackDiameter, attackDiameter))
	local attack = attackButton :: TextButton
	attack.AnchorPoint = Vector2.new(1, 0)
	attack.Position = UDim2.new(1, 0, 0, 42)
	attack.TextSize = 19

	local attackCorner = Instance.new("UICorner")
	attackCorner.CornerRadius = UDim.new(1, 0)
	attackCorner.Parent = attack

	buildSkillBar(gui, skillIds, onSkill)

	table.insert(buttonConnections, inventory.Activated:Connect(onInventoryToggle))
	table.insert(buttonConnections, mapToggle.Activated:Connect(onMapToggle))
	table.insert(buttonConnections, quests.Activated:Connect(onQuestToggle))
	table.insert(buttonConnections, attack.Activated:Connect(onAttack))
	table.insert(buttonConnections, auto.Activated:Connect(onAutoToggle))
	table.insert(buttonConnections, clearButton.Activated:Connect(onClearTarget))

	autoConnection = player:GetAttributeChangedSignal(CombatConfig.AutoAttackEnabledAttribute):Connect(updateAuto)
	renderConnection = RunService.RenderStepped:Connect(updateCooldowns)
	inputTypeConnection = UserInputService.LastInputTypeChanged:Connect(updateBindingHints)
	screenGui = gui
	updateAuto()
	updateCooldowns()
	updateBindingHints()
end

function ActionBar.stop(): ()
	if autoConnection ~= nil then autoConnection:Disconnect() end
	if renderConnection ~= nil then renderConnection:Disconnect() end
	if inputTypeConnection ~= nil then inputTypeConnection:Disconnect() end
	autoConnection, renderConnection, inputTypeConnection = nil, nil, nil
	for _, connection in buttonConnections do connection:Disconnect() end
	table.clear(buttonConnections)
	table.clear(skillButtons)
	table.clear(skillResourceTypes)
	if screenGui ~= nil then screenGui:Destroy() end
	screenGui, autoButton, attackButton, inventoryButton, mapButton, questButton, quickSlotButton = nil, nil, nil, nil, nil, nil, nil
	quickUseCallback = nil
	quickStateCallback = nil
end

return ActionBar
