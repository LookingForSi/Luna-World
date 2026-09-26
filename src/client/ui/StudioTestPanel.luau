--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)

local StudioTestPanel = {}

local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local archetypeAttributeConnection: RBXScriptConnection? = nil
local levelAttributeConnection: RBXScriptConnection? = nil
local speedAttributeConnection: RBXScriptConnection? = nil
local levelValueLabel: TextLabel? = nil
local speedButton: TextButton? = nil
local buttonConnections: { RBXScriptConnection } = {}
local buttons: { [string]: TextButton } = {}

local ARCHETYPES = {
	{ id = "knight", label = "Рыцарь" },
	{ id = "ranger", label = "Следопыт" },
	{ id = "mystic", label = "Мистик" },
}

local TELEPORTS = {
	{ id = "village", label = "ДЕРЕВНЯ" },
	{ id = "farm", label = "ФЕРМА" },
	{ id = "moonfall", label = "MOONFALL" },
	{ id = "goblins", label = "ГОБЛИНЫ" },
	{ id = "spiders", label = "ПАУКИ" },
	{ id = "woodland", label = "DARK WOOD" },
	{ id = "cemetery", label = "КЛАДБИЩЕ" },
	{ id = "shrine", label = "SHRINE" },
	{ id = "ancient", label = "ANCIENT" },
	{ id = "ruins", label = "RUINS" },
}

local function updateSelection(): ()
	local selected = player:GetAttribute(CombatConfig.ArchetypeAttribute)
	for archetypeId, button in buttons do
		local active = selected == archetypeId
		button.BackgroundColor3 = if active then Color3.fromRGB(92, 105, 58) else Color3.fromRGB(42, 45, 56)
	end
end

local function currentLevel(): number
	local value = player:GetAttribute(ProgressionConfig.LevelAttribute)
	if typeof(value) ~= "number" then return 1 end
	return math.clamp(math.floor(value), 1, ProgressionConfig.LevelCap)
end

local function updateLevel(): ()
	if levelValueLabel ~= nil then
		levelValueLabel.Text = string.format("LV %d", currentLevel())
	end
end

local function updateSpeed(): ()
	if speedButton == nil then return end
	local active = player:GetAttribute(CombatConfig.StudioMovementMultiplierAttribute) == 5
	speedButton.Text = if active then "SPEED x5 · ON" else "SPEED x5"
	speedButton.BackgroundColor3 = if active then Color3.fromRGB(92, 105, 58) else Color3.fromRGB(42, 45, 56)
end

function StudioTestPanel.start(): ()
	StudioTestPanel.stop()
	-- The developer panel is intentionally absent from touch emulation: it must
	-- never cover the phone HUD or participate in mobile layout acceptance.
	if UserInputService.TouchEnabled then return end
	if not RunService:IsStudio() then return end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local candidate = remotes:WaitForChild("StudioSetArchetype", 5)
	local levelCandidate = remotes:WaitForChild("StudioSetLevel", 5)
	local unlockRuinsCandidate = remotes:WaitForChild("StudioUnlockRuins", 5)
	local speedCandidate = remotes:WaitForChild("StudioToggleSpeed", 5)
	local unlockAllMissionsCandidate = remotes:WaitForChild("StudioUnlockAllMissions", 5)
	local topGearCandidate = remotes:WaitForChild("StudioGrantTopGear", 5)
	local teleportCandidate = remotes:WaitForChild("StudioTeleport", 5)
	if candidate == nil or not candidate:IsA("RemoteEvent") then return end
	if levelCandidate == nil or not levelCandidate:IsA("RemoteEvent") then return end
	if unlockRuinsCandidate == nil or not unlockRuinsCandidate:IsA("RemoteEvent") then return end
	if speedCandidate == nil or not speedCandidate:IsA("RemoteEvent") then return end
	if unlockAllMissionsCandidate == nil or not unlockAllMissionsCandidate:IsA("RemoteEvent") then return end
	if topGearCandidate == nil or not topGearCandidate:IsA("RemoteEvent") then return end
	if teleportCandidate == nil or not teleportCandidate:IsA("RemoteEvent") then return end
	local remote = candidate :: RemoteEvent
	local levelRemote = levelCandidate :: RemoteEvent
	local unlockRuinsRemote = unlockRuinsCandidate :: RemoteEvent
	local speedRemote = speedCandidate :: RemoteEvent
	local unlockAllMissionsRemote = unlockAllMissionsCandidate :: RemoteEvent
	local topGearRemote = topGearCandidate :: RemoteEvent
	local teleportRemote = teleportCandidate :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioTestPanel"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "ArchetypeSwitcher"
	frame.Position = UDim2.fromOffset(18, 82)
	frame.Size = UDim2.fromOffset(300, 332)
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
	title.Text = "STUDIO · инструменты"
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

	local function makeLevelButton(name: string, text: string, x: number, width: number): TextButton
		local button = Instance.new("TextButton")
		button.Name = name
		button.Position = UDim2.fromOffset(x, 66)
		button.Size = UDim2.fromOffset(width, 30)
		button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
		button.TextColor3 = Color3.fromRGB(240, 240, 244)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 12
		button.Text = text
		button.Parent = frame
		return button
	end

	local levelDown = makeLevelButton("LevelDown", "LV -", 8, 62)
	local levelValue = makeLevelButton("LevelValue", "LV 1", 76, 72)
	levelValue.Active = false
	levelValue.AutoButtonColor = false
	levelValueLabel = levelValue
	local levelUp = makeLevelButton("LevelUp", "LV +", 154, 62)
	local levelMax = makeLevelButton("LevelMax", string.format("LV %d", ProgressionConfig.LevelCap), 222, 70)

	table.insert(buttonConnections, levelDown.Activated:Connect(function()
		levelRemote:FireServer(math.max(1, currentLevel() - 1))
	end))
	table.insert(buttonConnections, levelUp.Activated:Connect(function()
		levelRemote:FireServer(math.min(ProgressionConfig.LevelCap, currentLevel() + 1))
	end))
	table.insert(buttonConnections, levelMax.Activated:Connect(function()
		levelRemote:FireServer(ProgressionConfig.LevelCap)
	end))

	local unlockRuins = makeLevelButton("UnlockRuins", "RUINS OPEN", 8, 140)
	unlockRuins.Position = UDim2.fromOffset(8, 104)
	table.insert(buttonConnections, unlockRuins.Activated:Connect(function()
		unlockRuinsRemote:FireServer()
	end))

	speedButton = makeLevelButton("SpeedX5", "SPEED x5", 156, 136)
	speedButton.Position = UDim2.fromOffset(156, 104)
	table.insert(buttonConnections, speedButton.Activated:Connect(function()
		speedRemote:FireServer()
	end))

	local unlockAll = makeLevelButton("UnlockAllMissions", "ALL MISSIONS", 8, 140)
	unlockAll.Position = UDim2.fromOffset(8, 142)
	table.insert(buttonConnections, unlockAll.Activated:Connect(function()
		unlockAllMissionsRemote:FireServer()
	end))

	local topGear = makeLevelButton("TopGear", "TOP GEAR", 156, 136)
	topGear.Position = UDim2.fromOffset(156, 142)
	table.insert(buttonConnections, topGear.Activated:Connect(function()
		topGearRemote:FireServer()
	end))

	local teleportTitle = Instance.new("TextLabel")
	teleportTitle.Name = "TeleportTitle"
	teleportTitle.BackgroundTransparency = 1
	teleportTitle.Position = UDim2.fromOffset(8, 180)
	teleportTitle.Size = UDim2.new(1, -16, 0, 18)
	teleportTitle.Font = Enum.Font.GothamMedium
	teleportTitle.TextColor3 = Color3.fromRGB(170, 172, 182)
	teleportTitle.TextSize = 11
	teleportTitle.TextXAlignment = Enum.TextXAlignment.Left
	teleportTitle.Text = "ТЕЛЕПОРТ"
	teleportTitle.Parent = frame

	for index, destination in TELEPORTS do
		local column = (index - 1) % 3
		local row = math.floor((index - 1) / 3)
		local button = Instance.new("TextButton")
		button.Name = "Teleport_" .. destination.id
		button.Position = UDim2.fromOffset(8 + column * 96, 202 + row * 31)
		button.Size = UDim2.fromOffset(88, 26)
		button.BackgroundColor3 = Color3.fromRGB(42, 45, 56)
		button.TextColor3 = Color3.fromRGB(240, 240, 244)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 10
		button.Text = destination.label
		button.Parent = frame
		table.insert(buttonConnections, button.Activated:Connect(function()
			teleportRemote:FireServer(destination.id)
		end))
	end

	archetypeAttributeConnection = player:GetAttributeChangedSignal(CombatConfig.ArchetypeAttribute):Connect(updateSelection)
	levelAttributeConnection = player:GetAttributeChangedSignal(ProgressionConfig.LevelAttribute):Connect(updateLevel)
	speedAttributeConnection = player:GetAttributeChangedSignal(CombatConfig.StudioMovementMultiplierAttribute):Connect(updateSpeed)
	screenGui = gui
	updateSelection()
	updateLevel()
	updateSpeed()
end

function StudioTestPanel.stop(): ()
	if archetypeAttributeConnection ~= nil then archetypeAttributeConnection:Disconnect(); archetypeAttributeConnection = nil end
	if levelAttributeConnection ~= nil then levelAttributeConnection:Disconnect(); levelAttributeConnection = nil end
	if speedAttributeConnection ~= nil then speedAttributeConnection:Disconnect(); speedAttributeConnection = nil end
	for _, connection in buttonConnections do connection:Disconnect() end
	table.clear(buttonConnections)
	table.clear(buttons)
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	levelValueLabel = nil
	speedButton = nil
end

return StudioTestPanel
