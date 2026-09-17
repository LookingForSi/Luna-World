--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)

local ActionBar = {}
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local autoButton: TextButton? = nil
local attackButton: TextButton? = nil
local autoConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}
local skillButtons: { [string]: TextButton } = {}
local skillResourceTypes: { [string]: string } = {}

local function makeButton(parent: Instance, name: string, text: string, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
	button.TextColor3 = Color3.fromRGB(240, 240, 244)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextWrapped = true
	button.Text = text
	button.Parent = parent
	return button
end

local function updateAuto(): ()
	if autoButton == nil then return end
	local enabled = player:GetAttribute(CombatConfig.AutoAttackEnabledAttribute) == true
	autoButton.Text = if enabled then "AUTO\nВКЛ" else "AUTO\nВЫКЛ"
	autoButton.BackgroundColor3 = if enabled then Color3.fromRGB(91, 105, 58) else Color3.fromRGB(42, 45, 56)
end

local function updateCooldowns(): ()
	local now = workspace:GetServerTimeNow()
	if attackButton ~= nil then
		local readyAt = player:GetAttribute(CombatConfig.BasicAttackReadyAtAttribute)
		local remaining = if typeof(readyAt) == "number" then math.max(0, readyAt - now) else 0
		attackButton.Text = if remaining > 0 then string.format("АТАКА\n%.1f", remaining) else "АТАКА"
	end
	for skillId, button in skillButtons do
		local definition = SkillDefinitions[skillId]
		if definition ~= nil then
			local readyAt = player:GetAttribute(CombatConfig.SkillCooldownAttributePrefix .. skillId)
			local remaining = if typeof(readyAt) == "number" then math.max(0, readyAt - now) else 0
			button.Text = if remaining > 0
				then string.format("%s\n%.1f", definition.displayName, remaining)
				else definition.displayName
			button.BackgroundColor3 = if remaining > 0 then Color3.fromRGB(33, 35, 43) else Color3.fromRGB(42, 45, 56)
			local currentResource = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
			local resourceType = player:GetAttribute(CombatConfig.ResourceTypeAttribute)
			local hasResource = typeof(currentResource) == "number"
				and resourceType == skillResourceTypes[skillId]
				and currentResource >= definition.resourceCost
			button.Active = hasResource
			button.TextTransparency = if hasResource then 0 else 0.45
		end
	end
end

function ActionBar.start(skillIds: { string }, onAttack: () -> (), onAutoToggle: () -> (), onSkill: (string) -> (), onClearTarget: () -> ()): ()
	ActionBar.stop()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatActionBar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "PrimaryActions"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -8, 1, -12)
	frame.Size = UDim2.new(1, -16, 0, 142)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(280, 142)
	constraint.MaxSize = Vector2.new(414, 142)
	constraint.Parent = frame

	for index, skillId in skillIds do
		local definition = SkillDefinitions[skillId]
		if definition ~= nil then
			local skillButton = makeButton(frame, "Skill" .. tostring(index), definition.displayName, UDim2.new(0.32, -4, 0, 54))
			skillButton.Position = UDim2.new((index - 1) * 0.34, 0, 0, 0)
			skillButtons[skillId] = skillButton
			skillResourceTypes[skillId] = definition.resourceType
			table.insert(buttonConnections, skillButton.Activated:Connect(function() onSkill(skillId) end))
		end
	end

	local clearButton = makeButton(frame, "ClearTarget", "СБРОС\nЦЕЛИ", UDim2.new(0.2, -4, 0, 70))
	clearButton.Position = UDim2.new(0, 0, 0, 62)
	autoButton = makeButton(frame, "Auto", "AUTO\nВЫКЛ", UDim2.new(0.25, -4, 0, 70))
	(autoButton :: TextButton).Position = UDim2.new(0.21, 0, 0, 62)
	local attackSize = UDim2.new(0.52, -4, 0, if UserInputService.TouchEnabled then 80 else 70)
	attackButton = makeButton(frame, "Attack", "АТАКА", attackSize)
	local attack = attackButton :: TextButton
	attack.Position = UDim2.new(0.48, 0, 0, if UserInputService.TouchEnabled then 58 else 62)
	attack.TextSize = 18
	table.insert(buttonConnections, attack.Activated:Connect(onAttack))
	table.insert(buttonConnections, (autoButton :: TextButton).Activated:Connect(onAutoToggle))
	table.insert(buttonConnections, clearButton.Activated:Connect(onClearTarget))
	autoConnection = player:GetAttributeChangedSignal(CombatConfig.AutoAttackEnabledAttribute):Connect(updateAuto)
	renderConnection = RunService.RenderStepped:Connect(updateCooldowns)
	screenGui = gui
	updateAuto()
	updateCooldowns()
end

function ActionBar.stop(): ()
	if autoConnection ~= nil then autoConnection:Disconnect() end
	if renderConnection ~= nil then renderConnection:Disconnect() end
	autoConnection, renderConnection = nil, nil
	for _, connection in buttonConnections do connection:Disconnect() end
	table.clear(buttonConnections)
	table.clear(skillButtons)
	table.clear(skillResourceTypes)
	if screenGui ~= nil then screenGui:Destroy() end
	screenGui, autoButton, attackButton = nil, nil, nil
end

return ActionBar
