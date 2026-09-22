--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local CharacterConfig = require(ReplicatedStorage.Shared.config.CharacterConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.progression.ProgressionRules)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local ClientCombatUiRules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)
local HudLayout = require(script.Parent.HudLayout)
local ResponsiveLayout = require(script.Parent.ResponsiveLayout)

local CombatHud = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local targetNameLabel: TextLabel? = nil
local targetHealthTextLabel: TextLabel? = nil
local targetHealthFill: Frame? = nil
local playerCombatPointsFill: Frame? = nil
local playerCombatPointsValueLabel: TextLabel? = nil
local playerHealthFill: Frame? = nil
local playerHealthValueLabel: TextLabel? = nil
local playerResourceFill: Frame? = nil
local playerResourceLabel: TextLabel? = nil
local playerResourceValueLabel: TextLabel? = nil
local xpFill: Frame? = nil
local xpValueLabel: TextLabel? = nil
local levelLabel: TextLabel? = nil
local playerNameLabel: TextLabel? = nil
local feedbackLabel: TextLabel? = nil
local targetHealthConnection: RBXScriptConnection? = nil
local targetAncestryConnection: RBXScriptConnection? = nil
local playerHealthConnection: RBXScriptConnection? = nil
local playerMaxHealthConnection: RBXScriptConnection? = nil
local characterAddedConnection: RBXScriptConnection? = nil
local statusConnections: { RBXScriptConnection } = {}
local presentationConnection: RBXScriptConnection? = nil
local feedbackGeneration = 0
local currentTarget: Model? = nil
local compactMobile = false


local RESOURCE_NAMES = {
	Stamina = "STM",
	Focus = "FCS",
	Mana = "MP",
}

local function shouldUseCompactMobile(): boolean
	while workspace.CurrentCamera == nil do
		workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	end
	return ResponsiveLayout.isSmallTouch(ResponsiveLayout.metrics(workspace.CurrentCamera))
end

local function disconnectTarget(): ()
	if targetHealthConnection ~= nil then
		targetHealthConnection:Disconnect()
		targetHealthConnection = nil
	end
	if targetAncestryConnection ~= nil then
		targetAncestryConnection:Disconnect()
		targetAncestryConnection = nil
	end
	currentTarget = nil
end

local function disconnectPlayerHealth(): ()
	if playerHealthConnection ~= nil then playerHealthConnection:Disconnect(); playerHealthConnection = nil end
	if playerMaxHealthConnection ~= nil then playerMaxHealthConnection:Disconnect(); playerMaxHealthConnection = nil end
end

local function formatStatusNumber(value: number): string
	local rounded = math.round(value)
	if math.abs(value - rounded) < 0.05 then
		return tostring(rounded)
	end
	return string.format("%.1f", value)
end

local function updateProgression(): ()
	local rawLevel = player:GetAttribute(ProgressionConfig.LevelAttribute)
	local rawXP = player:GetAttribute(ProgressionConfig.ExperienceAttribute)
	local level = if typeof(rawLevel) == "number" then math.clamp(math.floor(rawLevel), 1, ProgressionConfig.LevelCap) else 1
	local xp = if typeof(rawXP) == "number" then math.max(0, math.floor(rawXP)) else 0
	local required = ProgressionRules.requiredXP(level)

	if levelLabel ~= nil then
		levelLabel.Text = string.format("LVL %d", level)
	end
	if xpValueLabel ~= nil then
		xpValueLabel.Text = if required == nil then "MAX" else string.format("%d / %d", xp, required)
	end
	if xpFill ~= nil then
		local ratio = if required == nil then 1 else math.clamp(xp / required, 0, 1)
		xpFill.Size = UDim2.fromScale(ratio, 1)
	end
end

local function updateCombatPoints(): ()
	local current = player:GetAttribute(CombatConfig.CombatPointsCurrentAttribute)
	local maximum = player:GetAttribute(CombatConfig.CombatPointsMaximumAttribute)
	local currentValue = if typeof(current) == "number" then current else 0
	local maximumValue = if typeof(maximum) == "number" then maximum else 0
	local ratio = if maximumValue > 0 then math.clamp(currentValue / maximumValue, 0, 1) else 0
	if playerCombatPointsFill ~= nil then playerCombatPointsFill.Size = UDim2.fromScale(ratio, 1) end
	if playerCombatPointsValueLabel ~= nil then
		playerCombatPointsValueLabel.Text = string.format(
			"%s / %s",
			formatStatusNumber(currentValue),
			formatStatusNumber(maximumValue)
		)
	end
end

local function updateResource(): ()
	local resourceType = player:GetAttribute(CombatConfig.ResourceTypeAttribute)
	local current = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
	local maximum = player:GetAttribute(CombatConfig.ResourceMaximumAttribute)
	local displayName = if typeof(resourceType) == "string" then RESOURCE_NAMES[resourceType] or resourceType else "RES"
	local currentValue = if typeof(current) == "number" then current else 0
	local maximumValue = if typeof(maximum) == "number" then maximum else 0
	local ratio = if maximumValue > 0 then math.clamp(currentValue / maximumValue, 0, 1) else 0
	if playerResourceLabel ~= nil then playerResourceLabel.Text = displayName end
	if playerResourceValueLabel ~= nil then
		playerResourceValueLabel.Text = string.format(
			"%s / %s",
			formatStatusNumber(currentValue),
			formatStatusNumber(maximumValue)
		)
	end
	if playerResourceFill ~= nil then playerResourceFill.Size = UDim2.fromScale(ratio, 1) end
end

local function updateTargetHealth(humanoid: Humanoid): ()
	local health = math.max(0, humanoid.Health)
	local maxHealth = math.max(0, humanoid.MaxHealth)
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	if targetHealthTextLabel ~= nil then
		targetHealthTextLabel.Text = string.format(
			"HP: %s / %s",
			formatStatusNumber(health),
			formatStatusNumber(maxHealth)
		)
	end
	if targetHealthFill ~= nil then targetHealthFill.Size = UDim2.fromScale(ratio, 1) end
end

local function updatePlayerHealth(humanoid: Humanoid): ()
	local current = math.max(0, humanoid.Health)
	local maximum = math.max(0, humanoid.MaxHealth)
	local ratio = if maximum > 0 then math.clamp(current / maximum, 0, 1) else 0
	if playerHealthFill ~= nil then playerHealthFill.Size = UDim2.fromScale(ratio, 1) end
	if playerHealthValueLabel ~= nil then
		playerHealthValueLabel.Text = string.format(
			"%s / %s",
			formatStatusNumber(current),
			formatStatusNumber(maximum)
		)
	end
end

local function bindPlayerCharacter(character: Model): ()
	disconnectPlayerHealth()
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid == nil or not humanoid:IsA("Humanoid") or player.Character ~= character then return end
	updatePlayerHealth(humanoid)
	playerHealthConnection = humanoid.HealthChanged:Connect(function()
		if player.Character == character then updatePlayerHealth(humanoid) end
	end)
	playerMaxHealthConnection = humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		if player.Character == character then updatePlayerHealth(humanoid) end
	end)
end

local function makeTextLabel(parent: Instance, name: string, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = UDim2.new(1, -16, 0, 24)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(235, 235, 240)
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeStatusBar(
	parent: Instance,
	name: string,
	position: UDim2,
	fillName: string,
	fillColor: Color3,
	rightReserved: number?
): Frame
	local background = Instance.new("Frame")
	background.Name = name
	background.Position = position
	background.Size = UDim2.new(1, -(16 + (rightReserved or 0)), 0, 14)
	background.BackgroundColor3 = Color3.fromRGB(38, 39, 47)
	background.BorderSizePixel = 0
	background.ClipsDescendants = true
	background.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = fillName
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = background
	return fill
end

local function makePlayerStatusRow(
	parent: Frame,
	name: string,
	row: number,
	labelText: string,
	fillName: string,
	fillColor: Color3
): (TextLabel, TextLabel, Frame)
	if compactMobile then
		local y = 28 + (row - 1) * 21
		local fill = makeStatusBar(parent, name .. "Bar", UDim2.fromOffset(6, y), fillName, fillColor, 0)
		local background = fill.Parent :: Frame
		background.Size = UDim2.new(1, -12, 0, 18)

		local label = makeTextLabel(background, name .. "Label", UDim2.fromOffset(5, 0))
		label.Size = UDim2.new(0.35, 0, 1, 0)
		label.Text = labelText
		label.TextSize = 10
		label.ZIndex = 3

		local valueLabel = makeTextLabel(background, name .. "Value", UDim2.fromOffset(0, 0))
		valueLabel.Size = UDim2.new(1, -8, 1, 0)
		valueLabel.Text = "0 / 0"
		valueLabel.TextSize = 10
		valueLabel.TextXAlignment = Enum.TextXAlignment.Right
		valueLabel.ZIndex = 3
		valueLabel.Parent = background
		return label, valueLabel, fill
	end

	local y = 34 + (row - 1) * 37
	local label = makeTextLabel(parent, name .. "Label", UDim2.fromOffset(8, y))
	label.Size = UDim2.new(1, -16, 0, 15)
	label.Text = labelText
	label.TextSize = 11

	local valueLabel = makeTextLabel(parent, name .. "Value", UDim2.fromOffset(8, y))
	valueLabel.Size = UDim2.new(1, -16, 0, 15)
	valueLabel.Text = "0 / 0"
	valueLabel.TextSize = 11
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right

	local fill = makeStatusBar(
		parent,
		name .. "Bar",
		UDim2.fromOffset(8, y + 17),
		fillName,
		fillColor,
		0
	)
	local background = fill.Parent
	if background ~= nil and background:IsA("Frame") then
		background.Size = UDim2.new(1, -16, 0, 12)
	end
	return label, valueLabel, fill
end

local function updatePlayerName(): ()
	if playerNameLabel == nil then return end
	local nickname = player:GetAttribute(CharacterConfig.NicknameAttribute)
	playerNameLabel.Text = if typeof(nickname) == "string" and nickname ~= "" then nickname else player.DisplayName
end

local function createPlayerHeader(parent: Frame): TextLabel
	local nameLabel = makeTextLabel(parent, "PlayerName", UDim2.fromOffset(8, 7))
	nameLabel.Size = UDim2.new(1, -82, 0, 20)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	playerNameLabel = nameLabel
	updatePlayerName()

	local level = makeTextLabel(parent, "PlayerLevel", UDim2.fromOffset(8, 7))
	level.Size = UDim2.new(1, -16, 0, 20)
	level.Font = Enum.Font.GothamBold
	level.Text = "LVL 1"
	level.TextSize = 14
	level.TextXAlignment = Enum.TextXAlignment.Right
	return level
end

function CombatHud.start(): ()
	CombatHud.stop()
	compactMobile = shouldUseCompactMobile()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui:SetAttribute("CompactMobile", compactMobile)
	gui.ResetOnSpawn = false
	if compactMobile then
		gui.IgnoreGuiInset = true
		gui.ScreenInsets = Enum.ScreenInsets.None
	else
		gui.IgnoreGuiInset = false
		gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	end
	gui.Parent = player:WaitForChild("PlayerGui")

	TextChatService.ChatWindowConfiguration.HorizontalAlignment = Enum.HorizontalAlignment.Left
	TextChatService.ChatWindowConfiguration.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local targetPanel = Instance.new("Frame")
	targetPanel.Name = "TargetFrame"
	targetPanel.AnchorPoint = Vector2.new(0.5, 0)
	targetPanel.Position = if compactMobile
		then UDim2.new(0.5, 0, 0, HudLayout.MobileEdgeMargin)
		else UDim2.new(0.5, 0, 0, HudLayout.CornerMargin)
	targetPanel.Size = if compactMobile
		then UDim2.fromOffset(HudLayout.MobileTargetSize.X, HudLayout.MobileTargetSize.Y)
		else UDim2.fromOffset(280, 86)
	HudLayout.applyPanelStyle(targetPanel)
	targetPanel.Parent = gui

	targetNameLabel = makeTextLabel(targetPanel, "TargetName", UDim2.fromOffset(8, if compactMobile then 2 else 4))
	targetNameLabel.Size = UDim2.new(1, -16, 0, if compactMobile then 20 else 24)
	targetNameLabel.TextSize = if compactMobile then 13 else 16
	if compactMobile then
		local targetFill = makeStatusBar(targetPanel, "HealthBar", UDim2.fromOffset(8, 26), "Fill", Color3.fromRGB(159, 52, 62), 0)
		targetHealthFill = targetFill
		local targetBar = targetFill.Parent :: Frame
		targetBar.Size = UDim2.new(1, -16, 0, 18)
		targetHealthTextLabel = makeTextLabel(targetBar, "HealthText", UDim2.fromOffset(0, 0))
		targetHealthTextLabel.Size = UDim2.fromScale(1, 1)
		targetHealthTextLabel.TextSize = 10
		targetHealthTextLabel.TextXAlignment = Enum.TextXAlignment.Center
		targetHealthTextLabel.ZIndex = 3
		targetHealthTextLabel.Parent = targetBar
	else
		targetHealthTextLabel = makeTextLabel(targetPanel, "HealthText", UDim2.fromOffset(8, 28))
		targetHealthFill = makeStatusBar(targetPanel, "HealthBar", UDim2.fromOffset(8, 60), "Fill", Color3.fromRGB(159, 52, 62), 0)
	end

	local playerPanel = Instance.new("Frame")
	playerPanel.Name = "PlayerStatusFrame"
	playerPanel.AnchorPoint = Vector2.new(1, 0)
	playerPanel.Position = if compactMobile
		then UDim2.new(1, -HudLayout.MobileEdgeMargin, 0, HudLayout.MobileEdgeMargin)
		else UDim2.new(1, -HudLayout.CornerMargin, 0, HudLayout.CornerMargin)
	playerPanel.Size = if compactMobile
		then UDim2.fromOffset(HudLayout.MobilePlayerStatusSize.X, HudLayout.MobilePlayerStatusSize.Y)
		else UDim2.fromOffset(HudLayout.PlayerStatusSize.X, HudLayout.PlayerStatusSize.Y)
	HudLayout.applyPanelStyle(playerPanel)
	playerPanel.Parent = gui

	levelLabel = createPlayerHeader(playerPanel)

	local cpLabel
	cpLabel, playerCombatPointsValueLabel, playerCombatPointsFill = makePlayerStatusRow(
		playerPanel,
		"CombatPoints",
		1,
		"CP",
		"CombatPointsFill",
		Color3.fromRGB(197, 157, 54)
	)
	cpLabel.Text = "CP"

	local hpLabel
	hpLabel, playerHealthValueLabel, playerHealthFill = makePlayerStatusRow(
		playerPanel,
		"PlayerHealth",
		2,
		"HP",
		"PlayerHealthFill",
		Color3.fromRGB(159, 52, 62)
	)
	hpLabel.Text = "HP"

	local resourceLabel
	resourceLabel, playerResourceValueLabel, playerResourceFill = makePlayerStatusRow(
		playerPanel,
		"PlayerResource",
		3,
		"RES",
		"PlayerResourceFill",
		Color3.fromRGB(69, 108, 166)
	)
	playerResourceLabel = resourceLabel

	local xpLabel
	xpLabel, xpValueLabel, xpFill = makePlayerStatusRow(
		playerPanel,
		"LevelXP",
		4,
		"XP",
		"LevelXPFill",
		Color3.fromRGB(119, 104, 178)
	)
	xpLabel.Text = "XP"

	local feedback = makeTextLabel(gui, "CombatFeedback", UDim2.new(0.5, -160, 1, -122))
	feedback.Size = UDim2.fromOffset(320, 28)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextColor3 = Color3.fromRGB(235, 185, 105)
	feedback.Text = ""
	feedbackLabel = feedback
	screenGui = gui

	CombatHud.setTarget(nil)
	updateProgression()
	updateCombatPoints()
	updateResource()
	if player.Character ~= nil then bindPlayerCharacter(player.Character) end
	characterAddedConnection = player.CharacterAdded:Connect(bindPlayerCharacter)

	for _, attributeName in {
		ProgressionConfig.LevelAttribute,
		ProgressionConfig.ExperienceAttribute,
		CombatConfig.CombatPointsCurrentAttribute,
		CombatConfig.CombatPointsMaximumAttribute,
		CombatConfig.ResourceTypeAttribute,
		CombatConfig.ResourceCurrentAttribute,
		CombatConfig.ResourceMaximumAttribute,
		CharacterConfig.NicknameAttribute,
	} do
		table.insert(statusConnections, player:GetAttributeChangedSignal(attributeName):Connect(function()
			if attributeName == ProgressionConfig.LevelAttribute or attributeName == ProgressionConfig.ExperienceAttribute then
				updateProgression()
			elseif attributeName == CombatConfig.CombatPointsCurrentAttribute or attributeName == CombatConfig.CombatPointsMaximumAttribute then
				updateCombatPoints()
			elseif attributeName == CharacterConfig.NicknameAttribute then
				updatePlayerName()
			else
				updateResource()
			end
		end))
	end

	presentationConnection = ReplicatedStorage.Remotes.CombatPresentation.OnClientEvent:Connect(function(message: unknown)
		if not CombatPresentationRules.isSupported(message) then return end
		local record = message :: CombatPresentationRules.Message
		if record.outcome ~= "Rejected" then return end
		local text = ClientCombatUiRules.getRejectionText(record.reasonCode)
		if text == nil or feedbackLabel == nil then return end
		feedbackGeneration += 1
		local generation = feedbackGeneration
		feedbackLabel.Text = text
		task.delay(2, function()
			if generation == feedbackGeneration and feedbackLabel ~= nil then feedbackLabel.Text = "" end
		end)
	end)
end

function CombatHud.setTarget(target: Model?): ()
	disconnectTarget()

	if targetNameLabel == nil or targetHealthTextLabel == nil or targetHealthFill == nil then return end
	if target == nil then
		targetNameLabel.Text = "No target"
		targetHealthTextLabel.Text = "HP: --"
		targetHealthFill.Size = UDim2.fromScale(0, 1)
		return
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then return end

	currentTarget = target
	local targetLevel = target:GetAttribute("Level")
	targetNameLabel.Text = if typeof(targetLevel) == "number"
		then string.format("LV %d · %s", math.floor(targetLevel), target.Name)
		else target.Name
	updateTargetHealth(humanoid)
	targetHealthConnection = humanoid.HealthChanged:Connect(function()
		if currentTarget == target then updateTargetHealth(humanoid) end
	end)
	targetAncestryConnection = target.AncestryChanged:Connect(function(_, parent: Instance?)
		if parent == nil and currentTarget == target then CombatHud.setTarget(nil) end
	end)
end

function CombatHud.stop(): ()
	feedbackGeneration += 1
	disconnectTarget()
	disconnectPlayerHealth()
	if characterAddedConnection ~= nil then characterAddedConnection:Disconnect(); characterAddedConnection = nil end
	for _, connection in statusConnections do connection:Disconnect() end
	table.clear(statusConnections)
	if presentationConnection ~= nil then presentationConnection:Disconnect() end
	presentationConnection = nil
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	targetNameLabel = nil
	targetHealthTextLabel = nil
	targetHealthFill = nil
	playerCombatPointsFill = nil
	playerCombatPointsValueLabel = nil
	playerHealthFill = nil
	playerHealthValueLabel = nil
	playerResourceFill = nil
	playerResourceLabel = nil
	playerResourceValueLabel = nil
	xpFill = nil
	xpValueLabel = nil
	levelLabel = nil
	playerNameLabel = nil
	feedbackLabel = nil
	compactMobile = false
end

return CombatHud
