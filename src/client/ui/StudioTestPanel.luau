--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)

local StudioTestPanel = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local attributeConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}
local buttons: { [string]: TextButton } = {}

local ARCHETYPES = {
	{ id = "knight", label = "Рыцарь" },
	{ id = "ranger", label = "Следопыт" },
	{ id = "mystic", label = "Мистик" },
}

local function updateSelection(): ()
	local selected = player:GetAttribute(CombatConfig.ArchetypeAttribute)
	for archetypeId, button in buttons do
		local active = selected == archetypeId
		button.BackgroundColor3 = if active then Color3.fromRGB(92, 105, 58) else Color3.fromRGB(42, 45, 56)
	end
end

function StudioTestPanel.start(): ()
	StudioTestPanel.stop()
	if not RunService:IsStudio() then return end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local candidate = remotes:WaitForChild("StudioSetArchetype", 5)
	if candidate == nil or not candidate:IsA("RemoteEvent") then return end
	local remote = candidate :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioTestPanel"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "ArchetypeSwitcher"
	frame.Position = UDim2.fromOffset(18, 82)
	frame.Size = UDim2.fromOffset(300, 66)
	frame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(8, 3)
	title.Size = UDim2.new(1, -16, 0, 20)
	title.Font = Enum.Font.GothamMedium
	title.TextColor3 = Color3.fromRGB(205, 205, 212)
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "STUDIO · тест класса"
	title.Parent = frame

	for index, archetype in ARCHETYPES do
		local button = Instance.new("TextButton")
		button.Name = archetype.id
		button.Position = UDim2.fromOffset(8 + ((index - 1) * 96), 28)
		button.Size = UDim2.fromOffset(88, 30)
		button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
		button.TextColor3 = Color3.fromRGB(240, 240, 244)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.Text = archetype.label
		button.Parent = frame
		buttons[archetype.id] = button
		table.insert(buttonConnections, button.Activated:Connect(function()
			remote:FireServer(archetype.id)
		end))
	end

	attributeConnection = player:GetAttributeChangedSignal(CombatConfig.ArchetypeAttribute):Connect(updateSelection)
	screenGui = gui
	updateSelection()
end

function StudioTestPanel.stop(): ()
	if attributeConnection ~= nil then attributeConnection:Disconnect(); attributeConnection = nil end
	for _, connection in buttonConnections do connection:Disconnect() end
	table.clear(buttonConnections)
	table.clear(buttons)
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
end

return StudioTestPanel
