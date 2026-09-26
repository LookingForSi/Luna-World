--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ResponsiveLayout = require(script.Parent.Parent.Parent.ui.ResponsiveLayout)
local CharacterLobbyController = {}
local screen: ScreenGui?
local pending = {}
local selected: string?
local roster: any
local stopObserve: (() -> ())?
local resultConnection: RBXScriptConnection?
local accountReadyConnection: RBXScriptConnection?
local bootstrapStateConnection: RBXScriptConnection?
local onEnterWorld: ((string) -> ())?
local layoutMetrics: ResponsiveLayout.Metrics?
local lastLayoutMode: ResponsiveLayout.Mode?
local lastViewport: Vector2?
local enterWorldPending = false
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
		StoreError = "Не удалось сохранить данные. Попробуйте ещё раз",
		AccountNotReady = "Аккаунт ещё не готов. Попробуйте ещё раз",
		TransferInProgress = "Переход в мир уже выполняется",
		CharacterNotOwned = "Персонаж больше недоступен. Обновите список",
		CharacterNotOwnedOrActive = "Не удалось активировать персонажа. Попробуйте ещё раз",
		ServiceNotRunning = "Переход в мир временно недоступен",
		SaveFailed = "Не удалось сохранить персонажа перед переходом",
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

function CharacterLobbyController.requestSelect(characterId: string): ()
	send("Select", { characterId = characterId })
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
		TextSize = if smallTouch then 14 else 18,
	})
	local bootstrapState = ReplicatedStorage:FindFirstChild("ServerBootstrapState")
	if not roster and bootstrapState ~= nil and bootstrapState:IsA("StringValue") and string.sub(bootstrapState.Value, 1, 7) == "Failed:" then
		status.Text = "Сервер не запустился. Проверьте Studio Output."
		status.TextColor3 = palette.danger
	end
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
			local shade = createModalShade(root)
			local modalSize = ResponsiveLayout.modalSize(metrics, Vector2.new(590, 540))
			local modal = new("Frame", root, {
				Name = "CreationModal", AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(modalSize.X, modalSize.Y),
				BackgroundColor3 = palette.panel, BorderSizePixel = 0, ZIndex = 5,
			})
			if smallTouch then modal.Size = UDim2.new(1, -20, 1, -8) end
			modal:SetAttribute("MobileSurface", "FullWorkspace")
			stylePanel(modal, 14)
			local headerHeight = if smallTouch then 38 else 56
			local footerHeight = if smallTouch then 46 else 64
			local bodyPaddingX = if smallTouch then 16 else 24
			local rowGap = if smallTouch then 4 else 8
			new("TextLabel", modal, {
				Name = "CreationHeader",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(if smallTouch then 48 else 20, 0),
				Size = UDim2.new(1, if smallTouch then -96 else -76, 0, headerHeight),
				Text = "СОЗДАНИЕ ГЕРОЯ",
				TextColor3 = palette.moon,
				TextSize = if smallTouch then 17 else 20,
				Font = Enum.Font.GothamBold,
				TextXAlignment = if smallTouch then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
				ZIndex = 6,
			})
			local close = new("TextButton", modal, {
				Name = "Close",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, if smallTouch then 3 else 6),
				Size = UDim2.fromOffset(if smallTouch then 36 else 44, if smallTouch then 36 else 44),
				Text = "×",
				TextSize = if smallTouch then 20 else 24,
				ZIndex = 7,
			})
			styleButton(close, false)
			local bodyScroll = new("ScrollingFrame", modal, {
				Name = "CreationBody",
				Position = UDim2.fromOffset(0, headerHeight),
				Size = UDim2.new(1, 0, 1, -(headerHeight + footerHeight)),
				AutomaticCanvasSize = if smallTouch then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
				CanvasSize = UDim2.fromOffset(0, 0),
				ScrollingEnabled = not smallTouch or metrics.usableHeight < 330,
				ScrollBarThickness = if smallTouch and metrics.usableHeight >= 330 then 0 else 5,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 6,
			})
			new("UIPadding", bodyScroll, {
				PaddingLeft = UDim.new(0, if smallTouch then math.max(16, metrics.usableWidth * 0.09) else bodyPaddingX),
				PaddingRight = UDim.new(0, if smallTouch then math.max(16, metrics.usableWidth * 0.09) else bodyPaddingX),
				PaddingTop = UDim.new(0, if smallTouch then 2 else 4),
				PaddingBottom = UDim.new(0, if smallTouch then 4 else 12),
			})
			new("UIListLayout", bodyScroll, { Padding = UDim.new(0, rowGap), SortOrder = Enum.SortOrder.LayoutOrder })
			local footer = new("Frame", modal, {
				Name = "CreationFooter",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, footerHeight),
				BackgroundTransparency = 1,
				ZIndex = 6,
			})
			local function dismiss(): () shade:Destroy(); modal:Destroy() end
			close.Activated:Connect(dismiss); shade.Activated:Connect(dismiss)
			local function heading(textValue: string): TextLabel
				return new("TextLabel", bodyScroll, {
					Size = UDim2.new(1, 0, 0, if smallTouch then 10 else 20),
					BackgroundTransparency = 1,
					Text = textValue,
					TextColor3 = palette.muted,
					TextSize = if smallTouch then 11 else 13,
					Font = Enum.Font.GothamMedium,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 7,
				})
			end
			heading("ИМЯ")
			local name = new("TextBox", bodyScroll, {
				Name = "Nickname",
				Size = UDim2.new(1, 0, 0, if smallTouch then 30 else 46),
				BackgroundColor3 = palette.bgDeep,
				TextColor3 = palette.text,
				PlaceholderColor3 = palette.muted,
				PlaceholderText = if RunService:IsStudio() then "Studio: любое непустое имя" else "3–16 латинских символов",
				Text = "",
				TextSize = if smallTouch then 14 else 17,
				ClearTextOnFocus = false,
				ZIndex = 6,
			})
			rounded(name, 8); outlined(name)
			heading("КЛАСС")
			local class = "knight"
			local classRow = new("Frame", bodyScroll, { Name = "ClassOptions", Size = UDim2.new(1, 0, 0, if smallTouch then 34 else 58), BackgroundTransparency = 1, ZIndex = 6 })
			new("UIGridLayout", classRow, { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), FillDirectionMaxCells = 3 })
			local classButtons = {}
			local classNames = { knight = "РЫЦАРЬ", ranger = "СЛЕДОПЫТ", mystic = "МИСТИК" }
			local function refreshClassButtons(): () for id, button in classButtons do styleButton(button, id == class); button.Text = (if id == class then "✓ " else "") .. classNames[id] end end
			for _, id in { "knight", "ranger", "mystic" } do local b = new("TextButton", classRow, { Name = "Class_" .. id, TextSize = if smallTouch then 11 else 12, TextWrapped = true, ZIndex = 6 }); classButtons[id] = b; b.Activated:Connect(function() class = id; refreshClassButtons() end) end
			refreshClassButtons()
			heading("ПОЛ")
			local bodyType = "male"
			local genderRow = new("Frame", bodyScroll, { Name = "GenderOptions", Size = UDim2.new(1, 0, 0, if smallTouch then 30 else 48), BackgroundTransparency = 1, ZIndex = 6 })
			new("UIGridLayout", genderRow, { CellSize = UDim2.new(0.5, -4, 1, 0), CellPadding = UDim2.fromOffset(8, 0), FillDirectionMaxCells = 2 })
			local genderButtons = {}
			local function refreshBodyButtons(): () for id, button in genderButtons do styleButton(button, id == bodyType); button.Text = (if id == bodyType then "✓ " else "") .. (if id == "male" then "МУЖСКОЙ" else "ЖЕНСКИЙ") end end
			for _, id in { "male", "female" } do local b = new("TextButton", genderRow, { Name = "Body_" .. id, TextSize = 13, ZIndex = 6 }); genderButtons[id] = b; b.Activated:Connect(function() bodyType = id; refreshBodyButtons() end) end
			refreshBodyButtons()
			heading("БЫСТРОЕ ИМЯ")
			local quick = new("Frame", bodyScroll, { Name = "QuickName", Size = UDim2.new(1, 0, 0, if smallTouch then 30 else 44), BackgroundTransparency = 1, ZIndex = 6 })
			new("UIGridLayout", quick, { CellSize = UDim2.new(1 / 3, -6, 1, 0), CellPadding = UDim2.fromOffset(8, 0), FillDirectionMaxCells = 3 })
			local mine = new("TextButton", quick, { Text = "Мой Roblox ник", TextSize = 11, TextWrapped = true, ZIndex = 6 }); styleButton(mine, false)
			local random = new("TextButton", quick, { Text = "Случайное", TextSize = 12, ZIndex = 6 }); styleButton(random, false)
			local check = new("TextButton", quick, { Text = "Проверить", TextSize = 12, ZIndex = 6 }); styleButton(check, false)
			local nameStatus = new("TextLabel", bodyScroll, { Name = "NicknameStatus", Size = UDim2.new(1, 0, 0, if smallTouch then 12 else 24), BackgroundTransparency = 1, Text = if RunService:IsStudio() then "Studio: строгая проверка имени отключена" else "", TextColor3 = palette.muted, TextSize = if smallTouch then 9 else 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
			local function checkName(): () send("CheckNickname", { nickname = name.Text }); nameStatus.Text = "Проверяем имя…" end
			mine.Activated:Connect(function() name.Text = Players.LocalPlayer.Name; checkName() end)
			random.Activated:Connect(function() local a = { "Astra", "Luna", "Mira", "Selene", "Vela", "Nyx", "Orion" }; local z = { "dor", "wyn", "ris", "fox", "riel", "moon", "star" }; name.Text = a[math.random(#a)] .. z[math.random(#z)]; checkName() end)
			check.Activated:Connect(checkName)
			local create = new("TextButton", footer, {
				Name = "CreateCharacter",
				AnchorPoint = if smallTouch then Vector2.new(0.5, 0) else Vector2.zero,
				Position = if smallTouch then UDim2.new(0.5, 0, 0, 3) else UDim2.fromOffset(24, 8),
				Size = if smallTouch then UDim2.fromOffset(280, 40) else UDim2.new(1, -48, 0, 48),
				BackgroundColor3 = palette.accent,
				TextColor3 = palette.text,
				Text = "СОЗДАТЬ ПЕРСОНАЖА",
				Font = Enum.Font.GothamBold,
				TextSize = if smallTouch then 13 else 15,
				ZIndex = 7,
			})
			rounded(create, 8); outlined(create, palette.accentBright, 0)
			create.Activated:Connect(function() nameStatus.Text = "Создаём персонажа…"; send("Create", { nickname = name.Text, archetypeId = class, bodyType = bodyType, appearancePresetId = "default" }) end)
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
	stylePanel(preview, 12)
	local chosen = nil
	for _, c in roster.characters do
		if c.characterId == selected then
			chosen = c
		end
	end
	new("TextLabel", preview, {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(if smallTouch then 14 else 20, if smallTouch then 10 else 20),
		Size = UDim2.new(1, if smallTouch then -28 else -40, 0, if smallTouch then 82 else 110),
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
		TextSize = if smallTouch then 14 else 20,
		Font = Enum.Font.GothamSemibold,
	})
	local play = new("TextButton", preview, {
		Name = "EnterWorld",
		Position = if smallTouch then UDim2.new(0, 14, 1, -50) else UDim2.new(0, 24, 1, -78),
		Size = if smallTouch then UDim2.new(1, -28, 0, 40) else UDim2.new(1, -48, 0, 54),
		BackgroundColor3 = palette.accentBright,
		TextColor3 = palette.bg,
		Text = if enterWorldPending
			then "ПЕРЕХОД В МИР…"
			elseif chosen and chosen.needsIdentity
			then "ЗАВЕРШИТЬ СОЗДАНИЕ"
			else "ВОЙТИ В МИР",
		TextSize = 18,
		Font = Enum.Font.GothamBold,
		Active = chosen ~= nil and not enterWorldPending,
		AutoButtonColor = false,
	})
	rounded(play, 9)
	outlined(play, if chosen then palette.accentBright else palette.line, if chosen then 0 else 0.3)
	play.BackgroundColor3 = if chosen and not enterWorldPending then palette.accent else palette.panelSoft
	play.TextColor3 = if chosen and not enterWorldPending then palette.text else palette.muted
	play.Activated:Connect(function()
		if enterWorldPending then
			return
		end
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
			local characterId = chosen.characterId
			enterWorldPending = true
			render()
			if onEnterWorld ~= nil then
				onEnterWorld(characterId)
			else
				send("Select", { characterId = characterId })
			end
		end
	end)
	if chosen then
		local del = new("TextButton", preview, {
			Position = UDim2.fromOffset(if smallTouch then 14 else 24, if smallTouch then 92 else 150),
			Size = UDim2.fromOffset(if smallTouch then 104 else 190, if smallTouch then 32 else 44),
			BackgroundColor3 = palette.danger,
			TextColor3 = palette.text,
			Text = if smallTouch then "Удалить" else "Удалить персонажа",
			TextSize = if smallTouch then 12 else 14,
			TextScaled = false,
			TextWrapped = false,
		})
		rounded(del, 8)
		outlined(del, palette.danger, 0.15)
		del.Activated:Connect(function()
			local blocker = createModalShade(root)
			blocker.Name = "DeleteBlocker"
			blocker.ZIndex = 20
			local dialog = new("Frame", root, {
				Name = "DeleteDialog", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(if smallTouch then 390 else 460, if smallTouch then 176 else 190),
				BackgroundColor3 = palette.panel, BorderSizePixel = 0, ZIndex = 21,
			})
			dialog:SetAttribute("MobileSurface", "CompactDialog")
			stylePanel(dialog, 12)
			local deleteName = chosen.nickname or "незавершённого персонажа"
			local deleteConfirmation = chosen.deleteConfirmation or "DELETE:UNFINISHED"
			new("TextLabel", dialog, {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -56, 0, 34),
				Text = "Удалить " .. deleteName .. "?", TextColor3 = palette.text, Font = Enum.Font.GothamBold,
				TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22,
			})
			local cancel = new("TextButton", dialog, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34), Text = "×", TextSize = 20, ZIndex = 22 })
			styleButton(cancel, false)
			local confirm = new("TextBox", dialog, {
				Name = "DeleteConfirmation",
				Position = UDim2.fromOffset(16, 52),
				Size = UDim2.new(1, -32, 0, 42),
				PlaceholderText = "Введите " .. deleteConfirmation,
				Text = "",
				TextSize = 14,
				ZIndex = 22,
			})
			local submit = new("TextButton", dialog, {
				Name = "ConfirmDelete", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 102),
				Size = UDim2.fromOffset(180, 38), BackgroundColor3 = palette.danger, TextColor3 = palette.text,
				Text = "ПОДТВЕРДИТЬ УДАЛЕНИЕ", TextSize = 12, Font = Enum.Font.GothamBold, ZIndex = 22,
			})
			rounded(submit, 8); outlined(submit, palette.danger, 0.1)
			local deleteStatus = new("TextLabel", dialog, {
				Name = "DeleteStatus", Position = UDim2.fromOffset(12, 142), Size = UDim2.new(1, -24, 0, 24),
				BackgroundTransparency = 1, Text = "", TextColor3 = palette.muted, TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 22,
			})
			local function dismissDelete(): () blocker:Destroy(); dialog:Destroy() end
			cancel.Activated:Connect(dismissDelete)
			blocker.Activated:Connect(dismissDelete)
			local function confirmDelete(): () deleteStatus.Text = "Проверяем подтверждение…"; send("Delete", { characterId = chosen.characterId, confirmation = confirm.Text }) end
			confirm.FocusLost:Connect(function(enter)
				if enter then confirmDelete() end
			end)
			submit.Activated:Connect(confirmDelete)
		end)
	end
	new("TextLabel", root, {
		Name = "BuildLabel",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, edge, 1, -(edge + 28)),
		Size = UDim2.new(0.5, -edge, 0, 24),
		Text = roster.buildLabel,
		TextColor3 = palette.muted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
	})


end
export type StartOptions = {
	onEnterWorld: ((string) -> ())?,
}

function CharacterLobbyController.start(options: StartOptions?): ()
	if screen then
		return
	end
	enterWorldPending = false
	onEnterWorld = if options ~= nil then options.onEnterWorld else nil
	screen = new(
		"ScreenGui",
		Players.LocalPlayer.PlayerGui,
		{ Name = "CharacterLobby", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 100 }
	)
	screen.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	screen.IgnoreGuiInset = false
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
	resultConnection = result.OnClientEvent:Connect(function(p)
		if typeof(p) ~= "table" then
			return
		end
		pending[p.requestId] = nil
		if p.action == "Select" and not p.ok then
			enterWorldPending = false
			render()
		end
		if p.action == "CheckNickname" then
			local rootNow = screen and screen:FindFirstChild("LobbyRoot")
			local modal = rootNow and rootNow:FindFirstChild("CreationModal")
			local modalStatus = modal and modal:FindFirstChild("NicknameStatus", true)
			local s = modalStatus or (rootNow and rootNow:FindFirstChild("Status"))
			if s and s:IsA("TextLabel") then
				s.Text = if p.ok then (if RunService:IsStudio() then "Имя доступно в Studio" else "Имя свободно") else friendlyReason(p.reason)
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
			local modalStatus = modal and modal:FindFirstChild("NicknameStatus", true)
			local deleteDialog = rootNow and rootNow:FindFirstChild("DeleteDialog")
			local deleteStatus = deleteDialog and deleteDialog:FindFirstChild("DeleteStatus")
			local actionStatus = if p.action == "Delete" then deleteStatus else modalStatus
			local s = actionStatus or (rootNow and rootNow:FindFirstChild("Status"))
			if s and s:IsA("TextLabel") then
				s.Text = friendlyReason(p.reason)
				s.TextColor3 = palette.danger
			end
		end
	end)
	local player = Players.LocalPlayer
	local bootstrapState = ReplicatedStorage:FindFirstChild("ServerBootstrapState")
	if bootstrapState ~= nil and bootstrapState:IsA("StringValue") then
		bootstrapStateConnection = bootstrapState.Changed:Connect(render)
	else
		bootstrapStateConnection = ReplicatedStorage.ChildAdded:Connect(function(child)
			if child.Name ~= "ServerBootstrapState" or not child:IsA("StringValue") then return end
			if bootstrapStateConnection ~= nil then bootstrapStateConnection:Disconnect() end
			bootstrapStateConnection = child.Changed:Connect(render)
			render()
		end)
	end
	if player:GetAttribute("AccountReady") then
		send("Roster")
	else
		accountReadyConnection = player:GetAttributeChangedSignal("AccountReady"):Connect(function()
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
		stopObserve = nil
	end
	if resultConnection ~= nil then
		resultConnection:Disconnect()
		resultConnection = nil
	end
	if accountReadyConnection ~= nil then
		accountReadyConnection:Disconnect()
		accountReadyConnection = nil
	end
	if bootstrapStateConnection ~= nil then
		bootstrapStateConnection:Disconnect()
		bootstrapStateConnection = nil
	end
	if screen then
		screen:Destroy()
		screen = nil
	end
	layoutMetrics = nil
	lastLayoutMode = nil
	lastViewport = nil
	onEnterWorld = nil
	enterWorldPending = false
	table.clear(pending)
end
return CharacterLobbyController
