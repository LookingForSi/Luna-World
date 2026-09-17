--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local ClientCombatUiRules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)

local CombatHud = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local targetNameLabel: TextLabel? = nil
local targetHealthTextLabel: TextLabel? = nil
local targetHealthFill: Frame? = nil
local playerHealthFill: Frame? = nil
local playerResourceFill: Frame? = nil
local playerResourceLabel: TextLabel? = nil
local xpLabel: TextLabel? = nil
local feedbackLabel: TextLabel? = nil
local targetHealthConnection: RBXScriptConnection? = nil
local targetAncestryConnection: RBXScriptConnection? = nil
local playerHealthConnection: RBXScriptConnection? = nil
local playerMaxHealthConnection: RBXScriptConnection? = nil
local characterAddedConnection: RBXScriptConnection? = nil
local xpConnection: RBXScriptConnection? = nil
local resourceConnections: { RBXScriptConnection } = {}
local presentationConnection: RBXScriptConnection? = nil
local feedbackGeneration = 0
local currentTarget: Model? = nil

local RESOURCE_NAMES = {
	Stamina = "Выносливость",
	Focus = "Концентрация",
	Mana = "Мана",
}

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

local function updateXP(): ()
	local value = player:GetAttribute("SessionXP")
	local sessionXP = if typeof(value) == "number" then value else 0
	if xpLabel ~= nil then
		xpLabel.Text = string.format("XP: %d", sessionXP)
	end
end

local function updateResource(): ()
	local resourceType = player:GetAttribute(CombatConfig.ResourceTypeAttribute)
	local current = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
	local maximum = player:GetAttribute(CombatConfig.ResourceMaximumAttribute)
	local displayName = if typeof(resourceType) == "string" then RESOURCE_NAMES[resourceType] or resourceType else "Ресурс"
	local currentValue = if typeof(current) == "number" then current else 0
	local maximumValue = if typeof(maximum) == "number" then maximum else 0
	local ratio = if maximumValue > 0 then math.clamp(currentValue / maximumValue, 0, 1) else 0
	if playerResourceLabel ~= nil then playerResourceLabel.Text = displayName end
	if playerResourceFill ~= nil then playerResourceFill.Size = UDim2.fromScale(ratio, 1) end
end

local function updateTargetHealth(humanoid: Humanoid): ()
	local health = math.max(0, humanoid.Health)
	local maxHealth = math.max(0, humanoid.MaxHealth)
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	if targetHealthTextLabel ~= nil then
		targetHealthTextLabel.Text = string.format("HP: %d / %d", math.ceil(health), math.ceil(maxHealth))
	end
	if targetHealthFill ~= nil then
		targetHealthFill.Size = UDim2.fromScale(ratio, 1)
	end
end

local function updatePlayerHealth(humanoid: Humanoid): ()
	local ratio = if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 0
	if playerHealthFill ~= nil then playerHealthFill.Size = UDim2.fromScale(ratio, 1) end
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

local function makeStatusBar(parent: Instance, name: string, position: UDim2, fillName: string, fillColor: Color3): Frame
	local background = Instance.new("Frame")
	background.Name = name
	background.Position = position
	background.Size = UDim2.new(1, -16, 0, 14)
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

function CombatHud.start(): ()
	CombatHud.stop()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local targetPanel = Instance.new("Frame")
	targetPanel.Name = "TargetFrame"
	targetPanel.AnchorPoint = Vector2.new(0.5, 0)
	targetPanel.Position = UDim2.new(0.5, 0, 0, 24)
	targetPanel.Size = UDim2.fromOffset(280, 86)
	targetPanel.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	targetPanel.BackgroundTransparency = 0.15
	targetPanel.BorderSizePixel = 0
	targetPanel.Parent = gui

	targetNameLabel = makeTextLabel(targetPanel, "TargetName", UDim2.fromOffset(8, 4))
	targetHealthTextLabel = makeTextLabel(targetPanel, "HealthText", UDim2.fromOffset(8, 28))
	targetHealthFill = makeStatusBar(targetPanel, "HealthBar", UDim2.fromOffset(8, 60), "Fill", Color3.fromRGB(159, 52, 62))

	local playerPanel = Instance.new("Frame")
	playerPanel.Name = "PlayerStatusFrame"
	playerPanel.AnchorPoint = Vector2.new(0, 1)
	playerPanel.Position = UDim2.new(0, 18, 1, -16)
	playerPanel.Size = UDim2.fromOffset(300, 112)
	playerPanel.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	playerPanel.BackgroundTransparency = 0.15
	playerPanel.BorderSizePixel = 0
	playerPanel.Parent = gui

	local hpLabel = makeTextLabel(playerPanel, "PlayerHealthLabel", UDim2.fromOffset(8, 2))
	hpLabel.Size = UDim2.new(1, -16, 0, 20)
	hpLabel.Text = "HP"
	hpLabel.TextSize = 13
	playerHealthFill = makeStatusBar(playerPanel, "PlayerHealthBar", UDim2.fromOffset(8, 24), "PlayerHealthFill", Color3.fromRGB(159, 52, 62))

	local resourceLabel = makeTextLabel(playerPanel, "PlayerResourceLabel", UDim2.fromOffset(8, 42))
	resourceLabel.Size = UDim2.new(1, -16, 0, 20)
	resourceLabel.TextSize = 13
	playerResourceLabel = resourceLabel
	playerResourceFill = makeStatusBar(playerPanel, "PlayerResourceBar", UDim2.fromOffset(8, 64), "PlayerResourceFill", Color3.fromRGB(69, 108, 166))

	local xp = makeTextLabel(playerPanel, "SessionXP", UDim2.fromOffset(8, 82))
	xp.Size = UDim2.new(1, -16, 0, 24)
	xp.TextSize = 13
	xpLabel = xp

	local feedback = makeTextLabel(gui, "CombatFeedback", UDim2.new(0.5, -160, 1, -122))
	feedback.Size = UDim2.fromOffset(320, 28)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextColor3 = Color3.fromRGB(235, 185, 105)
	feedback.Text = ""
	feedbackLabel = feedback
	screenGui = gui

	CombatHud.setTarget(nil)
	updateXP()
	updateResource()
	if player.Character ~= nil then bindPlayerCharacter(player.Character) end
	characterAddedConnection = player.CharacterAdded:Connect(bindPlayerCharacter)
	xpConnection = player:GetAttributeChangedSignal("SessionXP"):Connect(updateXP)
	for _, attributeName in {
		CombatConfig.ResourceTypeAttribute,
		CombatConfig.ResourceCurrentAttribute,
		CombatConfig.ResourceMaximumAttribute,
	} do
		table.insert(resourceConnections, player:GetAttributeChangedSignal(attributeName):Connect(updateResource))
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
	targetNameLabel.Text = target.Name
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
	if xpConnection ~= nil then xpConnection:Disconnect(); xpConnection = nil end
	for _, connection in resourceConnections do connection:Disconnect() end
	table.clear(resourceConnections)
	if presentationConnection ~= nil then presentationConnection:Disconnect() end
	presentationConnection = nil
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	targetNameLabel = nil
	targetHealthTextLabel = nil
	targetHealthFill = nil
	playerHealthFill = nil
	playerResourceFill = nil
	playerResourceLabel = nil
	xpLabel = nil
	feedbackLabel = nil
end

return CombatHud
