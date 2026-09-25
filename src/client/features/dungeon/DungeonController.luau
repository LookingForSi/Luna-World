--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = {}
local connection: RBXScriptConnection? = nil
local gui: ScreenGui? = nil
local action = ReplicatedStorage.Remotes:WaitForChild("DungeonAction") :: RemoteEvent

local function label(parent: Instance, name: string, size: UDim2, pos: UDim2, text: string, textSize: number): TextLabel
	local value = Instance.new("TextLabel")
	value.Name = name
	value.Size = size
	value.Position = pos
	value.BackgroundColor3 = Color3.fromRGB(24, 25, 34)
	value.BackgroundTransparency = 0.12
	value.TextColor3 = Color3.fromRGB(235, 232, 220)
	value.Font = Enum.Font.Gotham
	value.TextSize = textSize
	value.TextWrapped = true
	value.Text = text
	value.Parent = parent
	return value
end

local function button(parent: Instance, name: string, pos: UDim2, text: string, callback: () -> ()): TextButton
	local value = Instance.new("TextButton")
	value.Name = name
	value.Size = UDim2.fromOffset(150, 38)
	value.Position = pos
	value.BackgroundColor3 = Color3.fromRGB(72, 58, 100)
	value.TextColor3 = Color3.new(1, 1, 1)
	value.Font = Enum.Font.GothamBold
	value.TextSize = 14
	value.Text = text
	value.Parent = parent
	value.Activated:Connect(callback)
	return value
end

local function clearModal(): ()
	if gui then
		local old = gui:FindFirstChild("DungeonModal")
		if old then old:Destroy() end
	end
end

local function modal(message: string, primaryText: string, actionName: string, token: string?): ()
	if not gui then return end
	clearModal()
	local frame = Instance.new("Frame")
	frame.Name = "DungeonModal"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(390, 190)
	frame.BackgroundColor3 = Color3.fromRGB(19, 20, 29)
	frame.Parent = gui
	label(frame, "Message", UDim2.new(1, -30, 0, 100), UDim2.fromOffset(15, 15), message, 18)
	button(frame, "Accept", UDim2.new(0.5, -160, 1, -52), primaryText, function()
		local payload: any = { action = actionName }
		if actionName == "ConfirmEntry" then payload.confirmationToken = token end
		if actionName == "Retreat" then payload.retreatToken = token end
		action:FireServer(payload)
		clearModal()
	end)
	button(frame, "Cancel", UDim2.new(0.5, 10, 1, -52), "Закрыть", clearModal)
end

function Controller.start(): ()
	if gui then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "DungeonUi"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local status = label(gui, "DungeonStatus", UDim2.fromOffset(330, 70), UDim2.new(0.5, -165, 0, 12), "", 15)
	status.Visible = false

	connection = (ReplicatedStorage.Remotes.DungeonEvent :: RemoteEvent).OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		if payload.state == "CONFIRM_ENTRY" then
			modal(payload.message or "Войти в Руины Селены?", "Войти", "ConfirmEntry", if typeof(payload.confirmationToken) == "string" then payload.confirmationToken else nil)
			return
		end
		if payload.state == "CONFIRM_RETREAT" then
			modal(payload.message or "Покинуть Руины Селены?", "Покинуть", "Retreat", if typeof(payload.retreatToken) == "string" then payload.retreatToken else nil)
			return
		end
		if payload.state == "COMPLETED" then
			local reward = payload.reward or {}
			modal(
				string.format("РУИНЫ СЕЛЕНЫ ПРОЙДЕНЫ\n+%s XP  +%s Luna\nОсквернённая реликвия", tostring(reward.xp or 0), tostring(reward.luna or 0)),
				"Вернуться в Moonfall",
				"Return",
				nil
			)
		end
		status.Visible = true
		status.Text = "Руины Селены\n" .. tostring(payload.objective or payload.message or "Подготовка...")
		if payload.state == "RETURNING"
			or payload.state == "RETURN_RETRY"
			or payload.state == "FAILED"
			or payload.state == "WIPE"
			or payload.state == "BOSS_ENRAGED"
			or payload.state == "ENTRANCE_UNLOCKED"
		then
			status.Text = tostring(payload.message or status.Text)
		end
	end)
end

function Controller.stop(): ()
	if connection then connection:Disconnect(); connection = nil end
	if gui then gui:Destroy(); gui = nil end
end

return Controller
