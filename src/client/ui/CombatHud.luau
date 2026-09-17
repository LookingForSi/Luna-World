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
local healthTextLabel: TextLabel? = nil
local healthFill: Frame? = nil
local xpLabel: TextLabel? = nil
local resourceLabel: TextLabel? = nil
local feedbackLabel: TextLabel? = nil
local healthConnection: RBXScriptConnection? = nil
local targetAncestryConnection: RBXScriptConnection? = nil
local xpConnection: RBXScriptConnection? = nil
local resourceConnections: { RBXScriptConnection } = {}
local presentationConnection: RBXScriptConnection? = nil
local feedbackGeneration = 0
local currentTarget: Model? = nil

local function disconnectTarget(): ()
	if healthConnection ~= nil then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	if targetAncestryConnection ~= nil then
		targetAncestryConnection:Disconnect()
		targetAncestryConnection = nil
	end
	currentTarget = nil
end

local function updateXP(): ()
	local value = player:GetAttribute("SessionXP")
	local sessionXP = if typeof(value) == "number" then value else 0
	if xpLabel ~= nil then
		xpLabel.Text = string.format("XP: %d", sessionXP)
	end
end

local RESOURCE_NAMES = {
	Stamina = "Выносливость",
	Focus = "Концентрация",
	Mana = "Мана",
}

local function updateResource(): ()
	local resourceType = player:GetAttribute(CombatConfig.ResourceTypeAttribute)
	local current = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
	local maximum = player:GetAttribute(CombatConfig.ResourceMaximumAttribute)
	if resourceLabel ~= nil then
		local displayName = if typeof(resourceType) == "string" then RESOURCE_NAMES[resourceType] or resourceType else "Ресурс"
		local currentValue = if typeof(current) == "number" then current else 0
		local maximumValue = if typeof(maximum) == "number" then maximum else 0
		resourceLabel.Text = string.format("%s: %d / %d", displayName, math.floor(currentValue), math.floor(maximumValue))
	end
end

local function updateHealth(humanoid: Humanoid): ()
	local health = math.max(0, humanoid.Health)
	local maxHealth = math.max(0, humanoid.MaxHealth)
	local ratio = if maxHealth > 0 then math.clamp(health / maxHealth, 0, 1) else 0
	if healthTextLabel ~= nil then
		healthTextLabel.Text = string.format("HP: %d / %d", math.ceil(health), math.ceil(maxHealth))
	end
	if healthFill ~= nil then
		healthFill.Size = UDim2.fromScale(ratio, 1)
	end
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

function CombatHud.start(): ()
	CombatHud.stop()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "TargetFrame"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 24)
	panel.Size = UDim2.fromOffset(280, 86)
	panel.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = gui

	targetNameLabel = makeTextLabel(panel, "TargetName", UDim2.fromOffset(8, 4))
	healthTextLabel = makeTextLabel(panel, "HealthText", UDim2.fromOffset(8, 28))

	local healthBackground = Instance.new("Frame")
	healthBackground.Name = "HealthBar"
	healthBackground.Position = UDim2.fromOffset(8, 60)
	healthBackground.Size = UDim2.new(1, -16, 0, 14)
	healthBackground.BackgroundColor3 = Color3.fromRGB(54, 32, 36)
	healthBackground.BorderSizePixel = 0
	healthBackground.ClipsDescendants = true
	healthBackground.Parent = panel

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(159, 52, 62)
	fill.BorderSizePixel = 0
	fill.Parent = healthBackground
	healthFill = fill

	local xp = makeTextLabel(gui, "SessionXP", UDim2.new(0, 20, 1, -44))
	xp.Size = UDim2.fromOffset(200, 28)
	xpLabel = xp
	local resource = makeTextLabel(gui, "CombatResource", UDim2.new(0, 20, 1, -72))
	resource.Size = UDim2.fromOffset(260, 28)
	resourceLabel = resource
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

	if targetNameLabel == nil or healthTextLabel == nil or healthFill == nil then
		return
	end
	if target == nil then
		targetNameLabel.Text = "No target"
		healthTextLabel.Text = "HP: --"
		healthFill.Size = UDim2.fromScale(0, 1)
		return
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	currentTarget = target
	targetNameLabel.Text = target.Name
	updateHealth(humanoid)
	healthConnection = humanoid.HealthChanged:Connect(function()
		if currentTarget == target then
			updateHealth(humanoid)
		end
	end)
	targetAncestryConnection = target.AncestryChanged:Connect(function(_, parent: Instance?)
		if parent == nil and currentTarget == target then
			CombatHud.setTarget(nil)
		end
	end)
end

function CombatHud.stop(): ()
	feedbackGeneration += 1
	disconnectTarget()
	if xpConnection ~= nil then
		xpConnection:Disconnect()
		xpConnection = nil
	end
	for _, connection in resourceConnections do connection:Disconnect() end
	table.clear(resourceConnections)
	if presentationConnection ~= nil then presentationConnection:Disconnect() end
	presentationConnection = nil
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	targetNameLabel = nil
	healthTextLabel = nil
	healthFill = nil
	xpLabel = nil
	resourceLabel = nil
	feedbackLabel = nil
end

return CombatHud
