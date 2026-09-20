--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ResponsiveLayout = require(script.Parent.Parent.ui.ResponsiveLayout)
local CharacterLobbyController = {}
local screen: ScreenGui?
local pending = {}
local selected: string?
local roster: any
local stopObserve: (() -> ())?
local layoutMetrics: ResponsiveLayout.Metrics?
local lastLayoutMode: ResponsiveLayout.Mode?
local lastViewport: Vector2?
local result = ReplicatedStorage.Remotes.CharacterResult
local request = ReplicatedStorage.Remotes.CharacterRequest
local palette = {
	bg = Color3.fromRGB(5, 10, 24),
	bgDeep = Color3.fromRGB(3, 7, 18),
	panel = Color3.fromRGB(12, 22, 46),
	panelSoft = Color3.fromRGB(18, 33, 67),
	panelHover = Color3.fromRGB(25, 47, 88),
	accent = Color3.fromRGB(96, 145, 255),
	accentBright = Color3.fromRGB(151, 199, 255),
	moon = Color3.fromRGB(220, 233, 255),
	text = Color3.fromRGB(239, 245, 255),
	muted = Color3.fromRGB(151, 169, 204),
	line = Color3.fromRGB(68, 91, 146),
	danger = Color3.fromRGB(215, 83, 112),
	success = Color3.fromRGB(111, 207, 190),
}
local function new(class: string, parent: Instance, props: any): any
	local x = Instance.new(class)
	for k, v in props do
		x[k] = v
	end
	x.Parent = parent
	return x
end

local function rounded(gui: GuiObject, radius: number?): ()
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = gui
end

local function outlined(gui: GuiObject, color: Color3?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or palette.line
	stroke.Transparency = transparency or 0.15
	stroke.Thickness = 1
	stroke.Parent = gui
	return stroke
end

local function stylePanel(gui: GuiObject, radius: number?): ()
	rounded(gui, radius or 10)
	outlined(gui)
end

local function styleButton(button: TextButton, selectedState: boolean?): ()
	button.AutoButtonColor = false
	button.BackgroundColor3 = if selectedState then palette.accent else palette.panelSoft
	button.TextColor3 = palette.text
	button.Font = Enum.Font.GothamSemibold
	rounded(button, 8)
	outlined(button, if selectedState then palette.accentBright else palette.line, if selectedState then 0 else 0.2)
end

local function sectionLabel(parent: Instance, textValue: string, y: number): TextLabel
	return new("TextLabel", parent, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(32, y),
		Size = UDim2.new(1, -64, 0, 22),
		Text = textValue,
		TextColor3 = palette.muted,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
	})
end

local function createModalShade(root: Frame): TextButton
	local shade = new("TextButton", root, {
		Name = "ModalShade",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 4,
	})
	shade.Active = true
	return shade
end

local function friendlyReason(reason: any): string
	local map = {
		InvalidCharacters = "Допустимы латинские буквы, цифры, _ и -",
		InvalidLength = "Имя должно быть от 3 до 16 символов",
		InvalidNickname = "Введите имя",
		NicknameTaken = "Это имя уже занято",
		Filtered = "Имя не прошло фильтрацию Roblox",
		SlotLimit = "Все слоты персонажей заняты",
		StoreError = "Сервис имён временно недоступен",
	}
	return map[tostring(reason)] or tostring(reason)
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
	local edge = if smallTouch then 10 else 28
	local root = screen:FindFirstChild("LobbyRoot") :: Frame
	if not root then
		return
	end
	clear(root)
	root.BackgroundColor3 = palette.bg
	local backgroundGradient = new("UIGradient", root, {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, palette.bgDeep),
			ColorSequenceKeypoint.new(0.52, palette.bg),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 18, 42)),
		}),
		Rotation = 28,
	})
	new("TextLabel", root, {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(edge, edge),
		Size = UDim2.new(1, -edge * 2, 0, 56),
		Text = "LUNA WORLD",
		TextColor3 = palette.moon,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
	})
	local status = new("TextLabel", root, {
		Name = "Status",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(edge, edge + 58),
		Size = UDim2.new(1, -edge * 2, 0, 30),
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
		Position = if portrait
			then UDim2.fromOffset(edge, edge + 96)
			else UDim2.fromOffset(edge, edge + 96),
		Size = if portrait
			then UDim2.new(1, -edge * 2, 0, math.min(210, metrics.contentSize.Y * 0.32))
			else UDim2.new(0.34, -edge, 1, -(edge * 2 + 126)),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
	})
	stylePanel(cards, 12)
	new("UIPadding", cards, {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	})
	new("UIListLayout", cards, { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	for _, c in roster.characters do
		local b = new("TextButton", cards, {
			Name = "CharacterCard",
			Size = UDim2.new(1, -8, 0, 76),
			BackgroundColor3 = if selected == c.characterId then palette.accent else palette.panelSoft,
			TextColor3 = palette.text,
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
		styleButton(b, selected == c.characterId)
		b.Activated:Connect(function()
			selected = c.characterId
			render()
		end)
	end
	if #roster.characters < roster.slotLimit then
		local add = new("TextButton", cards, {
			Name = "CreateSlot",
			Active = true,
			AutoButtonColor = true,
			Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = palette.panel,
			TextColor3 = palette.accentBright,
			Text = "＋ Создать персонажа",
			TextSize = 16,
		})
		styleButton(add, false)
		add.TextColor3 = palette.accentBright
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
				TextColor3 = palette.accentBright,
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
			local nameStatus = new("TextLabel", modal, {
				Name = "NicknameStatus",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(30, 326),
				Size = UDim2.new(1, -60, 0, 22),
				Text = "",
				TextColor3 = palette.muted,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 6,
			})
			check.Activated:Connect(function()
				send("CheckNickname", { nickname = name.Text })
				nameStatus.Text = "Проверяем имя…"
			end)
			local create = new("TextButton", modal, {
				Position = UDim2.fromOffset(30, 355),
				Size = UDim2.new(1, -60, 0, 50),
				BackgroundColor3 = palette.accentBright,
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
		Position = if portrait
			then UDim2.fromOffset(edge, edge + 96 + math.min(210, metrics.contentSize.Y * 0.32) + 10)
			else UDim2.new(0.34, edge, 0, edge + 96),
		Size = if portrait
			then UDim2.new(1, -edge * 2, 1, -(edge * 2 + 136 + math.min(210, metrics.contentSize.Y * 0.32)))
			else UDim2.new(0.66, -(edge * 2), 1, -(edge * 2 + 126)),
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
		BackgroundColor3 = palette.accentBright,
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
					BackgroundColor3 = palette.accentBright,
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
		Position = UDim2.new(0, edge, 1, -(edge + 24)),
		Size = UDim2.new(1, -edge * 2, 0, 24),
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
		{ Name = "CharacterLobby", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100 }
	)
	local root = new("Frame", screen, {
		Name = "LobbyRoot",
		BackgroundColor3 = palette.bg,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
	})
	stopObserve = ResponsiveLayout.observe(function(m)
		local previousMode = lastLayoutMode
		local previousViewport = lastViewport
		layoutMetrics = m
		lastLayoutMode = m.mode
		lastViewport = m.viewport

		-- LastInputTypeChanged also fires on the first mouse/touch press. Rebuilding
		-- the whole lobby there destroys the pressed button before Activated fires.
		-- Only rebuild when viewport/layout geometry truly changed.
		local geometryChanged = previousMode == nil
			or previousMode ~= m.mode
			or previousViewport == nil
			or math.abs(previousViewport.X - m.viewport.X) > 1
			or math.abs(previousViewport.Y - m.viewport.Y) > 1
		if roster ~= nil and geometryChanged then
			render()
		end
	end)
	result.OnClientEvent:Connect(function(p)
		if typeof(p) ~= "table" then
			return
		end
		pending[p.requestId] = nil
		if p.action == "CheckNickname" then
			local rootNow = screen and screen:FindFirstChild("LobbyRoot")
			local modal = rootNow and rootNow:FindFirstChild("CreationModal")
			local modalStatus = modal and modal:FindFirstChild("NicknameStatus")
			local s = modalStatus or (rootNow and rootNow:FindFirstChild("Status"))
			if s and s:IsA("TextLabel") then
				s.Text = if p.ok then "Имя свободно" else "Имя недоступно: " .. tostring(p.reason)
				s.TextColor3 = if p.ok then palette.accentBright else palette.danger
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
			local rootNow = screen and screen:FindFirstChild("LobbyRoot")
			local modal = rootNow and rootNow:FindFirstChild("CreationModal")
			local modalStatus = modal and modal:FindFirstChild("NicknameStatus")
			local s = modalStatus or (rootNow and rootNow:FindFirstChild("Status"))
			if s and s:IsA("TextLabel") then
				s.Text = "Ошибка: " .. tostring(p.reason) .. " — повторите попытку"
				s.TextColor3 = palette.danger
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
	layoutMetrics = nil
	lastLayoutMode = nil
	lastViewport = nil
end
return CharacterLobbyController
