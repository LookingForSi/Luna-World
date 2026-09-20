--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.progression.ProgressionRules)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local HudLayout = require(script.Parent.HudLayout)

local ActionBar = {}
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local autoButton: TextButton? = nil
local attackButton: TextButton? = nil
local inventoryButton: TextButton? = nil
local mapButton: TextButton? = nil
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
	return "ИНВЕНТАРЬ [I]"
end

local function updateInventoryHint(): ()
	if inventoryButton ~= nil then
		inventoryButton.Text = inventoryBindingText()
	end
end

local function updateAuto(): ()
	if autoButton == nil then return end
	local enabled = player:GetAttribute(CombatConfig.AutoAttackEnabledAttribute) == true
	autoButton.Text = if enabled
		then string.format("AUTO [%s]\nВКЛ", autoBindingHint())
		else string.format("AUTO [%s]\nВЫКЛ", autoBindingHint())
	autoButton.BackgroundColor3 = if enabled then Color3.fromRGB(91, 105, 58) else Color3.fromRGB(42, 45, 56)
end

local function updateCooldowns(): ()
	local now = workspace:GetServerTimeNow()
	if attackButton ~= nil then
		local readyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
		local remaining = if typeof(readyAt) == "number" then math.max(0, readyAt - now) else 0
		attackButton.Text = if remaining > 0 then string.format("АТАКА\n%.1f", remaining) else "АТАКА"
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
	local width = if UserInputService.TouchEnabled then 350 else HudLayout.SkillBarSize.X
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

	for index = 1, 10 do
		local skillId = skillIds[index]
		local button = makeButton(
			content,
			"SkillSlot" .. tostring(index),
			"",
			UDim2.new(0.1, -4, 1, 0)
		)
		button.Position = UDim2.new((index - 1) * 0.1, 2, 0, 0)
		button.TextSize = if UserInputService.TouchEnabled then 8 else 10

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
	onMapToggle: () -> ()
): ()
	ActionBar.stop()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatActionBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local actionHeight = if UserInputService.TouchEnabled then HudLayout.ActionBarSize.Y + 12 else HudLayout.ActionBarSize.Y
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

	mapButton = makeButton(content, "Map", if UserInputService.TouchEnabled then "КАРТА" else "КАРТА [M]", UDim2.new(0.32, -2, 0, 36))
	local mapToggle = mapButton :: TextButton
	inventoryButton = makeButton(content, "Inventory", inventoryBindingText(), UDim2.new(0.66, -2, 0, 36))
	local inventory = inventoryButton :: TextButton
	inventory.Position = UDim2.new(0.34, 0, 0, 0)

	autoButton = makeButton(content, "Auto", "AUTO [G]\nВЫКЛ", UDim2.new(0.32, -2, 0, 44))
	local auto = autoButton :: TextButton
	auto.Position = UDim2.new(0, 0, 0, 42)

	local clearButton = makeButton(content, "ClearTarget", "СБРОС\nЦЕЛИ", UDim2.new(0.32, -2, 0, 44))
	clearButton.Position = UDim2.new(0, 0, 0, 90)

	attackButton = makeButton(content, "Attack", "АТАКА", UDim2.new(0.66, -2, 0, if UserInputService.TouchEnabled then 104 else 92))
	local attack = attackButton :: TextButton
	attack.Position = UDim2.new(0.34, 0, 0, 42)
	attack.TextSize = 19

	buildSkillBar(gui, skillIds, onSkill)

	table.insert(buttonConnections, inventory.Activated:Connect(onInventoryToggle))
	table.insert(buttonConnections, mapToggle.Activated:Connect(onMapToggle))
	table.insert(buttonConnections, attack.Activated:Connect(onAttack))
	table.insert(buttonConnections, auto.Activated:Connect(onAutoToggle))
	table.insert(buttonConnections, clearButton.Activated:Connect(onClearTarget))

	autoConnection = player:GetAttributeChangedSignal(CombatConfig.AutoAttackEnabledAttribute):Connect(updateAuto)
	renderConnection = RunService.RenderStepped:Connect(updateCooldowns)
	inputTypeConnection = UserInputService.LastInputTypeChanged:Connect(updateInventoryHint)
	screenGui = gui
	updateAuto()
	updateCooldowns()
	updateInventoryHint()
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
	screenGui, autoButton, attackButton, inventoryButton, mapButton = nil, nil, nil, nil, nil
end

return ActionBar
