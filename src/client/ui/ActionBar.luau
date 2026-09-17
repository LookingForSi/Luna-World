--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)

local ActionBar = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local autoButton: TextButton? = nil
local autoConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}

local function makeButton(parent: Instance, name: string, text: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = position
	button.Size = UDim2.fromOffset(112, 52)
	button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
	button.TextColor3 = Color3.fromRGB(240, 240, 244)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.Text = text
	button.Parent = parent
	return button
end

local function updateAuto(): ()
	if autoButton == nil then return end
	local enabled = player:GetAttribute(CombatConfig.AutoAttackEnabledAttribute) == true
	autoButton.Text = if enabled then "AUTO: ВКЛ" else "AUTO: ВЫКЛ"
	autoButton.BackgroundColor3 = if enabled then Color3.fromRGB(91, 105, 58) else Color3.fromRGB(42, 45, 56)
end

function ActionBar.start(onAttack: () -> (), onAutoToggle: () -> ()): ()
	ActionBar.stop()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatActionBar"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "PrimaryActions"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -20, 1, -20)
	frame.Size = UDim2.fromOffset(232, 52)
	frame.BackgroundTransparency = 1
	frame.Parent = gui

	local attackButton = makeButton(frame, "Attack", "АТАКА", UDim2.fromOffset(0, 0))
	autoButton = makeButton(frame, "Auto", "AUTO: ВЫКЛ", UDim2.fromOffset(120, 0))
	table.insert(buttonConnections, attackButton.Activated:Connect(onAttack))
	table.insert(buttonConnections, (autoButton :: TextButton).Activated:Connect(onAutoToggle))
	autoConnection = player:GetAttributeChangedSignal(CombatConfig.AutoAttackEnabledAttribute):Connect(updateAuto)
	screenGui = gui
	updateAuto()
end

function ActionBar.stop(): ()
	if autoConnection ~= nil then
		autoConnection:Disconnect()
		autoConnection = nil
	end
	for _, connection in buttonConnections do connection:Disconnect() end
	table.clear(buttonConnections)
	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
	autoButton = nil
end

return ActionBar
