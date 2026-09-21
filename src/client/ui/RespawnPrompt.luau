--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RespawnConfig = require(ReplicatedStorage.Shared.config.RespawnConfig)

local RespawnPrompt = {}

local player = Players.LocalPlayer
local respawnRequest = ReplicatedStorage.Remotes:WaitForChild("RespawnRequest") :: RemoteEvent
local screenGui: ScreenGui? = nil
local dialog: Frame? = nil
local laterButton: TextButton? = nil
local yesButton: TextButton? = nil
local pendingConnection: RBXScriptConnection? = nil
local buttonConnections: { RBXScriptConnection } = {}
local dismissed = false
local requestGeneration = 0

local function setVisible(): ()
	local pending = player:GetAttribute(RespawnConfig.RespawnPendingAttribute) == true
	if not pending then
		dismissed = false
		requestGeneration += 1
	end
	if dialog ~= nil then dialog.Visible = pending and not dismissed end
	if laterButton ~= nil then laterButton.Visible = pending and dismissed end
	if yesButton ~= nil and not pending then
		yesButton.Active = true
		yesButton.AutoButtonColor = true
		yesButton.Text = "Да"
	end
end

local function requestReturn(): ()
	if player:GetAttribute(RespawnConfig.RespawnPendingAttribute) ~= true then return end
	requestGeneration += 1
	local generation = requestGeneration
	if yesButton ~= nil then
		yesButton.Active = false
		yesButton.AutoButtonColor = false
		yesButton.Text = "Возвращение..."
	end
	respawnRequest:FireServer()
	task.delay(1.5, function()
		if generation ~= requestGeneration or player:GetAttribute(RespawnConfig.RespawnPendingAttribute) ~= true then return end
		if yesButton ~= nil then
			yesButton.Active = true
			yesButton.AutoButtonColor = true
			yesButton.Text = "Да"
		end
	end)
end

local function makeButton(parent: Instance, text: string, position: UDim2, size: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(44, 47, 58)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = size
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(242, 242, 245)
	button.TextSize = 15
	button.Text = text
	button.Parent = parent
	return button
end

function RespawnPrompt.start(): ()
	RespawnPrompt.stop()

	local gui = Instance.new("ScreenGui")
	gui.Name = "RespawnPrompt"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "RespawnDialog"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromOffset(430, 170)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(18, 18)
	title.Size = UDim2.new(1, -36, 0, 34)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(238, 238, 242)
	title.TextSize = 22
	title.Text = "Вы были убиты"
	title.Parent = panel

	local question = Instance.new("TextLabel")
	question.BackgroundTransparency = 1
	question.Position = UDim2.fromOffset(18, 58)
	question.Size = UDim2.new(1, -36, 0, 28)
	question.Font = Enum.Font.Gotham
	question.TextColor3 = Color3.fromRGB(205, 205, 212)
	question.TextSize = 16
	question.Text = "Вернуться в ближайший город?"
	question.Parent = panel

	local yes = makeButton(panel, "Да", UDim2.fromOffset(70, 108), UDim2.fromOffset(130, 42))
	local no = makeButton(panel, "Нет", UDim2.fromOffset(230, 108), UDim2.fromOffset(130, 42))
	yes.BackgroundColor3 = Color3.fromRGB(75, 95, 58)
	yesButton = yes
	dialog = panel

	local later = makeButton(gui, "Вернуться в город", UDim2.new(0.5, -90, 1, -82), UDim2.fromOffset(180, 42))
	later.AnchorPoint = Vector2.new(0, 0)
	later.BackgroundColor3 = Color3.fromRGB(75, 95, 58)
	laterButton = later

	table.insert(buttonConnections, yes.Activated:Connect(requestReturn))
	table.insert(buttonConnections, no.Activated:Connect(function()
		dismissed = true
		setVisible()
	end))
	table.insert(buttonConnections, later.Activated:Connect(function()
		dismissed = false
		setVisible()
	end))

	pendingConnection = player:GetAttributeChangedSignal(RespawnConfig.RespawnPendingAttribute):Connect(setVisible)
	screenGui = gui
	setVisible()
end

function RespawnPrompt.stop(): ()
	requestGeneration += 1
	if pendingConnection ~= nil then pendingConnection:Disconnect(); pendingConnection = nil end
	for _, connection in buttonConnections do connection:Disconnect() end
	table.clear(buttonConnections)
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	dialog = nil
	laterButton = nil
	yesButton = nil
	dismissed = false
end

return RespawnPrompt
