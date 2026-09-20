--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ResponsiveLayout = require(script.Parent.Parent.ui.ResponsiveLayout)
local CharacterLobbyController = {}
local screen: ScreenGui?
local pending = {}
local selected: string?
local roster: any
local stopObserve: (() -> ())?
local layoutMetrics: ResponsiveLayout.Metrics?
local result = ReplicatedStorage.Remotes.CharacterResult
local request = ReplicatedStorage.Remotes.CharacterRequest
local palette = {
	bg = Color3.fromRGB(12, 17, 27),
	panel = Color3.fromRGB(27, 35, 49),
	gold = Color3.fromRGB(211, 174, 91),
	text = Color3.fromRGB(235, 231, 217),
	muted = Color3.fromRGB(154, 164, 181),
	danger = Color3.fromRGB(155, 54, 54),
}
local function new(class: string, parent: Instance, props: any): any
	local x = Instance.new(class)
	for k, v in props do
		x[k] = v
	end
	x.Parent = parent
	return x
end
local function send(action: string, data: any?)
	local id = HttpService:GenerateGUID(false)
	local p = data or {}
	p.action = action
	p.requestId = id
	pending[id] = action
	request:FireServer(p)
end
local function clear(parent: Instance)
	for _, x in parent:GetChildren() do
		x:Destroy()
	end
end
local function render()
	if not screen then
		return
	end
	local metrics = layoutMetrics or ResponsiveLayout.metrics(workspace.CurrentCamera)
	local portrait = metrics.mode == "MobilePortrait"
	local smallTouch = ResponsiveLayout.isSmallTouch(metrics)
	local root = screen:FindFirstChild("LobbyRoot") :: Frame
	if not root then
		return
	end
	clear(root)
	new("TextLabel", root, {
		Name = "Title",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 52),
		Text = "LUNA WORLD",
		TextColor3 = palette.gold,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	})
	local status = new("TextLabel", root, {
		Name = "Status",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 0, 30),
		Text = if roster then "Выберите героя" else "Загрузка аккаунта…",
		TextColor3 = palette.text,
		Font = Enum.Font.Gotham,
		TextSize = 18,
	})
	if not roster then
		return
	end
	local cards = new("ScrollingFrame", root, {
		Name = "CharacterRoster",
		BackgroundColor3 = palette.panel,
		BorderSizePixel = 0,
		Position = if portrait then UDim2.new(0, 0, 0, 88) else UDim2.new(0, 0, 0, 92),
		Size = if portrait then UDim2.new(1, 0, 0, 188) else UDim2.new(0.38, -8, 1, -132),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
	})
	new("UIListLayout", cards, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	for _, c in roster.characters do
		local b = new("TextButton", cards, {
			Name = "CharacterCard",
			Size = UDim2.new(1, -8, 0, 76),
			BackgroundColor3 = if selected == c.characterId then palette.gold else palette.bg,
			TextColor3 = if selected == c.characterId then palette.bg else palette.text,
			Text = string.format(
				"%s  •  LV %d\n%s  •  %s",
				c.nickname or "Завершить создание",
				c.level,
				c.archetypeId,
				c.bodyType or "—"
			),
			TextSize = 16,
			Font = Enum.Font.GothamSemibold,
		})
		b.Activated:Connect(function()
			selected = c.characterId
			render()
		end)
	end
	if #roster.characters < roster.slotLimit then
		local add = new("TextButton", cards, {
			Name = "CreateSlot",
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = palette.panel,
			TextColor3 = palette.gold,
			Text = "＋ Создать персонажа",
			TextSize = 16,
		})
		add.Activated:Connect(function()
			local modalSize = ResponsiveLayout.modalSize(metrics, Vector2.new(460, 420))
			local modal = new("ScrollingFrame", root, {
				Name = "CreationModal",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.fromOffset(modalSize.X, modalSize.Y),
				CanvasSize = UDim2.fromOffset(0, 420),
				ScrollBarThickness = if smallTouch then 5 else 0,
				BackgroundColor3 = palette.panel,
				BorderSizePixel = 0,
				ZIndex = 5,
			})
			new("TextLabel", modal, {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 50),
				Text = "СОЗДАНИЕ ГЕРОЯ",
				TextColor3 = palette.gold,
				TextSize = 22,
				Font = Enum.Font.GothamBold,
				ZIndex = 6,
			})
			local close = new("TextButton", modal, {
				Name = "Close",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 8),
				Size = UDim2.fromOffset(44, 44),
				BackgroundColor3 = palette.bg,
				TextColor3 = palette.text,
				Text = "×",
				TextSize = 24,
				ZIndex = 7,
			})
			close.Activated:Connect(function() modal:Destroy() end)
			local name = new("TextBox", modal, {
				Name = "Nickname",
				Position = UDim2.fromOffset(30, 65),
				Size = UDim2.new(1, -60, 0, 48),
				PlaceholderText = "Имя (3–16 латинских символов)",
				Text = "",
				TextSize = 17,
				ZIndex = 6,
			})
			local class = "knight"
			local body = "male"
			for i, v in { "knight", "ranger", "mystic" } do
				local b = new("TextButton", modal, {
					Position = UDim2.new((i - 1) / 3, 10, 0, 135),
					Size = UDim2.new(1 / 3, -20, 0, 55),
					Text = if v == "knight" then "РЫЦАРЬ" else if v == "ranger" then "СЛЕДОПЫТ" else "МИСТИК",
					TextSize = 14,
					ZIndex = 6,
				})
				b.Activated:Connect(function()
					class = v
				end)
			end
			for i, v in { "male", "female" } do
				local b = new("TextButton", modal, {
					Position = UDim2.new((i - 1) / 2, 15, 0, 210),
					Size = UDim2.new(0.5, -30, 0, 50),
					Text = if v == "male" then "Мужской" else "Женский",
					TextSize = 16,
					ZIndex = 6,
				})
				b.Activated:Connect(function()
					body = v
				end)
			end
			local mine = new("TextButton", modal, {
				Position = UDim2.new(0, 30, 0, 280),
				Size = UDim2.new(0.34, -24, 0, 44),
				Text = "Мой Roblox ник",
				TextSize = 13,
				ZIndex = 6,
			})
			mine.Activated:Connect(function()
				name.Text = Players.LocalPlayer.Name
				send("CheckNickname", { nickname = name.Text })
				status.Text = "Проверяем имя…"
			end)
			local random = new("TextButton", modal, {
				Position = UDim2.new(0.34, 8, 0, 280),
				Size = UDim2.new(0.33, -16, 0, 44),
				Text = "🎲 Случайное",
				TextSize = 13,
				ZIndex = 6,
			})
			random.Activated:Connect(function()
				local a = { "Astra", "Luna", "Mira", "Selene", "Vela" }
				local z = { "dor", "wyn", "ris", "fox", "riel" }
				name.Text = a[math.random(#a)] .. z[math.random(#z)]
				send("CheckNickname", { nickname = name.Text })
				status.Text = "Проверяем имя…"
			end)
			local check = new("TextButton", modal, {
				Position = UDim2.new(0.67, 8, 0, 280),
				Size = UDim2.new(0.33, -38, 0, 44),
				Text = "Проверить",
				TextSize = 13,
				ZIndex = 6,
			})
			check.Activated:Connect(function()
				send("CheckNickname", { nickname = name.Text })
				status.Text = "Проверяем имя…"
			end)
			local create = new("TextButton", modal, {
				Position = UDim2.fromOffset(30, 345),
				Size = UDim2.new(1, -60, 0, 50),
				BackgroundColor3 = palette.gold,
				TextColor3 = palette.bg,
				Text = "СОЗДАТЬ",
				Font = Enum.Font.GothamBold,
				TextSize = 17,
				ZIndex = 6,
			})
			create.Activated:Connect(function()
				send(
					"Create",
					{ nickname = name.Text, archetypeId = class, bodyType = body, appearancePresetId = "default" }
				)
			end)
		end)
	end
	local preview = new("Frame", root, {
		Name = "CharacterPreview",
		Position = if portrait then UDim2.new(0, 0, 0, 286) else UDim2.new(0.4, 8, 0, 92),
		Size = if portrait then UDim2.new(1, 0, 1, -320) else UDim2.new(0.6, -8, 1, -132),
		BackgroundColor3 = palette.panel,
		BorderSizePixel = 0,
	})
	local chosen = nil
	for _, c in roster.characters do
		if c.characterId == selected then
			chosen = c
		end
	end
	new("TextLabel", preview, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.new(1, -40, 0, 110),
		Text = if chosen
			then string.format(
				"%s\n%s • Уровень %d\nXP %d • Luna %d",
				chosen.nickname or "Без имени",
				chosen.archetypeId,
				chosen.level,
				chosen.xp,
				chosen.luna
			)
			else "Выберите карточку героя",
		TextColor3 = palette.text,
		TextSize = 20,
		Font = Enum.Font.GothamSemibold,
	})
	local play = new("TextButton", preview, {
		Name = "EnterWorld",
		Position = UDim2.new(0, 24, 1, -78),
		Size = UDim2.new(1, -48, 0, 54),
		BackgroundColor3 = palette.gold,
		TextColor3 = palette.bg,
		Text = if chosen and chosen.needsIdentity
			then "ЗАВЕРШИТЬ СОЗДАНИЕ"
			else "ВОЙТИ В МИР",
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		Active = chosen ~= nil,
	})
	play.Activated:Connect(function()
		if chosen and chosen.needsIdentity then
			local name = new(
				"TextBox",
				preview,
				{
					Name = "LegacyNickname",
					Position = UDim2.fromOffset(24, 270),
					Size = UDim2.new(1, -48, 0, 46),
					PlaceholderText = "Новое уникальное имя",
					Text = "",
					TextSize = 16,
				}
			)
			local bodyType = "male"
			local body = new(
				"TextButton",
				preview,
				{
					Position = UDim2.fromOffset(24, 320),
					Size = UDim2.new(1, -48, 0, 38),
					Text = "Тип тела: Мужской (сменить)",
					TextSize = 14,
				}
			)
			body.Activated:Connect(function()
				bodyType = if bodyType == "male" then "female" else "male"
				body.Text = if bodyType == "male"
					then "Тип тела: Мужской (сменить)"
					else "Тип тела: Женский (сменить)"
			end)
			local complete = new(
				"TextButton",
				preview,
				{
					Position = UDim2.fromOffset(24, 364),
					Size = UDim2.new(1, -48, 0, 48),
					BackgroundColor3 = palette.gold,
					Text = "СОХРАНИТЬ ИМЯ И ТИП ТЕЛА",
					TextSize = 14,
				}
			)
			complete.Activated:Connect(function()
				send(
					"CompleteIdentity",
					{
						characterId = chosen.characterId,
						nickname = name.Text,
						archetypeId = chosen.archetypeId,
						bodyType = bodyType,
						appearancePresetId = "default",
					}
				)
			end)
		elseif chosen then
			send("Select", { characterId = chosen.characterId })
		end
	end)
	if chosen then
		local del = new("TextButton", preview, {
			Position = UDim2.fromOffset(24, 150),
			Size = UDim2.fromOffset(190, 44),
			BackgroundColor3 = palette.danger,
			TextColor3 = palette.text,
			Text = "Удалить персонажа",
			TextSize = 14,
		})
		del.Activated:Connect(function()
			local confirm = new("TextBox", preview, {
				Name = "DeleteConfirmation",
				Position = UDim2.fromOffset(24, 205),
				Size = UDim2.new(1, -48, 0, 48),
				PlaceholderText = "Введите DELETE:" .. tostring(chosen.nickname),
				Text = "",
				TextSize = 15,
			})
			confirm.FocusLost:Connect(function(enter)
				if enter then
					send("Delete", { characterId = chosen.characterId, confirmation = confirm.Text })
				end
			end)
		end)
	end
	new("TextLabel", root, {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 0, 1, -30),
		Size = UDim2.new(1, 0, 0, 24),
		Text = roster.buildLabel .. "  •  ⚙ Настройки: UI / текст / звук",
		TextColor3 = palette.muted,
		TextSize = 13,
	})
end
function CharacterLobbyController.start(): ()
	if screen then
		return
	end
	screen = new(
		"ScreenGui",
		Players.LocalPlayer.PlayerGui,
		{ Name = "CharacterLobby", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 100 }
	)
	local root = new("Frame", screen, { Name = "LobbyRoot", BackgroundColor3 = palette.bg, BorderSizePixel = 0 })
	stopObserve = ResponsiveLayout.observe(function(m)
		layoutMetrics = m
		local size = ResponsiveLayout.modalSize(m, Vector2.new(1120, 720))
		root.Size = UDim2.fromOffset(size.X, size.Y)
		root.Position = UDim2.fromScale(0.5, 0.5)
		root.AnchorPoint = Vector2.new(0.5, 0.5)
		if roster ~= nil then render() end
	end)
	result.OnClientEvent:Connect(function(p)
		if typeof(p) ~= "table" then
			return
		end
		pending[p.requestId] = nil
		if p.action == "CheckNickname" then
			local s = screen and screen:FindFirstChild("LobbyRoot") and screen.LobbyRoot:FindFirstChild("Status")
			if s then
				s.Text = if p.ok then "Имя свободно" else "Имя недоступно: " .. tostring(p.reason)
			end
			return
		end
		if p.ok and p.data then
			roster = p.data
			if not selected and roster.characters[1] then
				selected = roster.characters[1].characterId
			end
			render()
		elseif not p.ok then
			local s = screen and screen:FindFirstChild("LobbyRoot") and screen.LobbyRoot:FindFirstChild("Status")
			if s then
				s.Text = "Ошибка: " .. tostring(p.reason) .. " — повторите попытку"
			end
		end
	end)
	local player = Players.LocalPlayer
	if player:GetAttribute("AccountReady") then
		send("Roster")
	else
		player:GetAttributeChangedSignal("AccountReady"):Connect(function()
			if player:GetAttribute("AccountReady") then
				send("Roster")
			end
		end)
	end
	render()
end
function CharacterLobbyController.stop(): ()
	if stopObserve then
		stopObserve()
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
end
return CharacterLobbyController
