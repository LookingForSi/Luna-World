--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local ClientCombatLogRules = require(ReplicatedStorage.Shared.combat.ClientCombatLogRules)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local HudLayout = require(script.Parent.HudLayout)
local ResponsiveLayout = require(script.Parent.ResponsiveLayout)

local CombatLog = {}

local player = Players.LocalPlayer
local localEntityId = "player:" .. tostring(player.UserId)
local screenGui: ScreenGui? = nil
local frame: Frame? = nil
local body: ScrollingFrame? = nil
local toggleButton: TextButton? = nil
local presentationConnection: RBXScriptConnection? = nil
local levelConnection: RBXScriptConnection? = nil
local expanded = true
local entryLabels: { TextLabel } = {}
local entrySequence = 0
local observedLevel: number? = nil
local stopObserving: (() -> ())? = nil
local currentMetrics: ResponsiveLayout.Metrics? = nil

local MAX_ENTRIES = 200
local ENTRY_HEIGHT = 18
local AUTO_SCROLL_TOLERANCE = 24

local mobNamesById: { [string]: string } = {}
for _, definition in MobDefinitions do
	mobNamesById[definition.id] = definition.displayName
end

local function skillDefinition(skillId: string?): any
	if skillId == nil then return nil end
	return SkillDefinitions[skillId]
end

local function skillName(skillId: string?): string
	local definition = skillDefinition(skillId)
	if definition ~= nil then return definition.displayName end
	return skillId or "Действие"
end

local function isBasicAttack(skillId: string?): boolean
	return skillId ~= nil and string.find(skillId, "basic_attack", 1, true) ~= nil
end

local function isNearBottom(scroller: ScrollingFrame): boolean
	local remaining = scroller.AbsoluteCanvasSize.Y - (scroller.CanvasPosition.Y + scroller.AbsoluteWindowSize.Y)
	return remaining <= AUTO_SCROLL_TOLERANCE
end

local function scrollToBottom(scroller: ScrollingFrame): ()
	task.defer(function()
		if body ~= scroller or scroller.Parent == nil then return end
		scroller.CanvasPosition = Vector2.new(
			0,
			math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
		)
	end)
end

local function append(text: string): ()
	local scroller = body
	if text == "" or scroller == nil then return end

	local shouldFollow = isNearBottom(scroller)
	entrySequence += 1

	local label = Instance.new("TextLabel")
	label.Name = "Entry" .. tostring(entrySequence)
	label.LayoutOrder = entrySequence
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -18, 0, ENTRY_HEIGHT)
	label.Font = Enum.Font.RobotoMono
	label.TextColor3 = Color3.fromRGB(224, 224, 230)
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = scroller
	table.insert(entryLabels, label)

	while #entryLabels > MAX_ENTRIES do
		local oldest = table.remove(entryLabels, 1)
		if oldest ~= nil then oldest:Destroy() end
	end

	if shouldFollow then
		scrollToBottom(scroller)
	end
end

local function setExpanded(value: boolean): ()
	expanded = value
	if body ~= nil then body.Visible = expanded end
	if frame ~= nil then
		if currentMetrics ~= nil and (currentMetrics :: ResponsiveLayout.Metrics).isTouch then
			local metrics = currentMetrics :: ResponsiveLayout.Metrics
			local size = if expanded
				then ResponsiveLayout.combatLogExpandedSize(metrics)
				else ResponsiveLayout.combatLogCollapsedSize(metrics)
			frame.Size = UDim2.fromOffset(size.X, size.Y)
		else
			frame.Size = if expanded
				then UDim2.fromOffset(HudLayout.CombatLogSize.X, HudLayout.CombatLogSize.Y)
				else UDim2.fromOffset(128, 30)
		end
	end
	if toggleButton ~= nil then toggleButton.Text = if expanded then "Лог  ▲" else "Лог  ▼" end
end

local function formatOutgoingResult(message: CombatPresentationRules.Message): string?
	local definition = skillDefinition(message.skillId)
	local name = skillName(message.skillId)

	if message.outcome == "Rejected" then
		return string.format("%s: отказ — %s.", name, ClientCombatLogRules.rejectionText(message.reasonCode))
	end
	if message.outcome == "ResolveFailed" then
		return string.format("%s: действие не сработало.", name)
	end
	if message.outcome == "Canceled" then
		return string.format("%s: действие прервано.", name)
	end
	if message.outcome ~= "Applied" then return nil end

	if message.amount ~= nil then
		local amount = ClientCombatLogRules.formatAmount(message.amount)
		if definition ~= nil and definition.effect.kind == "DirectHealing" then
			return string.format("%s: восстановлено %s HP.", name, amount)
		end
		local critical = if message.isCritical == true then " КРИТ!" else ""
		local suffix = if definition ~= nil and definition.effect.kind == "AreaDamage" then " суммарного урона" else " урона"
		return string.format("%s: %s%s.%s", name, amount, suffix, critical)
	end

	if definition == nil then return string.format("%s: применено.", name) end
	local effect = definition.effect
	if effect.kind == "DefenseStance" then
		local active = player.Character ~= nil and player.Character:GetAttribute(CombatConfig.DefenseStanceActiveAttribute) == true
		if active then
			return string.format(
				"%s: включена, защита +%d%%, скорость -%d%%.",
				name,
				math.round(effect.magnitude * 100),
				math.round((1 - effect.movementSpeedMultiplier) * 100)
			)
		end
		return name .. ": выключена."
	end
	if effect.kind == "MovementSlow" then
		return string.format(
			"%s: цель замедлена на %d%% на %.1f с.",
			name,
			math.round(effect.magnitude * 100),
			effect.durationSeconds
		)
	end
	if effect.kind == "AttackSpeedBuff" then
		return string.format(
			"%s: скорость базовой атаки +%d%% на %.1f с.",
			name,
			math.round(effect.magnitude * 100),
			effect.durationSeconds
		)
	end
	return name .. ": применено."
end

local function formatIncoming(message: CombatPresentationRules.Message): string?
	if message.kind ~= "Result" or message.outcome ~= "Applied" or message.amount == nil then return nil end
	local sourceName = if message.definitionId ~= nil then mobNamesById[message.definitionId] else nil
	local amount = ClientCombatLogRules.formatAmount(message.amount)
	return string.format("%s наносит вам %s урона.", sourceName or "Противник", amount)
end

local function onPresentation(value: unknown): ()
	if not CombatPresentationRules.isSupported(value) then return end
	local message = value :: CombatPresentationRules.Message
	if not ClientCombatLogRules.isRelevant(message, localEntityId) then return end

	if message.actorEntityId == localEntityId then
		if message.kind == "Reward" and message.amount ~= nil then
			local amount = ClientCombatLogRules.formatAmount(message.amount)
			if message.outcome == "Granted" and message.presentationKey == "xp" then
				append(string.format("Получено %s XP.", amount))
				return
			end
			if message.outcome == "Granted" and message.presentationKey == "luna" then
				append(string.format("Получено %s Luna.", amount))
				return
			end
			if message.definitionId ~= nil then
				local item = ItemDefinitions[message.definitionId]
				local itemName = if item ~= nil then item.displayName else message.definitionId
				if message.outcome == "Granted" and message.presentationKey == "loot_item" then
					append(string.format("Добыча: %s ×%s.", itemName, amount))
					return
				end
				if message.outcome == "Rejected" and message.presentationKey == "loot_item_full" then
					append(string.format("Инвентарь полон: %s ×%s не получен.", itemName, amount))
					return
				end
			end
		end
		if message.kind == "Action" and message.outcome == "Accepted" then
			if not isBasicAttack(message.skillId) then append("▶ " .. skillName(message.skillId)) end
			return
		end
		if message.kind == "Result" then
			local text = formatOutgoingResult(message)
			if text ~= nil then append(text) end
			return
		end
		if message.kind == "Effect" and message.effectPhase == "Ended" and message.skillId ~= nil then
			append(skillName(message.skillId) .. ": эффект закончился.")
			return
		end
		if message.kind == "Death" then
			append("Вы погибли.")
			return
		end
		if message.kind == "Respawn" then
			append("Вы вернулись в город.")
			return
		end
	elseif message.targetEntityId == localEntityId then
		local text = formatIncoming(message)
		if text ~= nil then append(text) end
	end
end

local function readLevel(): number
	local value = player:GetAttribute(ProgressionConfig.LevelAttribute)
	if typeof(value) ~= "number" then return 1 end
	return math.clamp(math.floor(value), 1, ProgressionConfig.LevelCap)
end

local function onLevelChanged(): ()
	local newLevel = readLevel()
	local previousLevel = observedLevel
	observedLevel = newLevel
	if previousLevel == nil or newLevel <= previousLevel then return end

	for level = previousLevel + 1, newLevel do
		append(string.format("★ Получен уровень %d.", level))
	end
end

function CombatLog.start(): ()
	CombatLog.stop()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatLog"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "CombatLogFrame"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, HudLayout.CornerMargin, 1, -HudLayout.CornerMargin)
	root.Size = UDim2.fromOffset(HudLayout.CombatLogSize.X, HudLayout.CombatLogSize.Y)
	HudLayout.applyPanelStyle(root)
	root.Parent = gui

	local toggle = Instance.new("TextButton")
	toggle.Name = "Toggle"
	toggle.Position = UDim2.fromOffset(0, 0)
	toggle.Size = UDim2.fromOffset(128, 30)
	toggle.BackgroundColor3 = Color3.fromRGB(33, 36, 45)
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.GothamBold
	toggle.TextColor3 = Color3.fromRGB(235, 235, 240)
	toggle.TextSize = 13
	toggle.Parent = root

	local logBody = Instance.new("ScrollingFrame")
	logBody.Name = "Entries"
	logBody.Position = UDim2.fromOffset(0, 30)
	logBody.Size = UDim2.new(1, 0, 1, -30)
	logBody.BackgroundTransparency = 1
	logBody.BorderSizePixel = 0
	logBody.CanvasSize = UDim2.fromOffset(0, 0)
	logBody.AutomaticCanvasSize = Enum.AutomaticSize.Y
	logBody.ScrollingDirection = Enum.ScrollingDirection.Y
	logBody.ScrollBarThickness = 6
	logBody.ScrollBarImageColor3 = Color3.fromRGB(116, 121, 136)
	logBody.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	logBody.Parent = root

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 4)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = logBody

	local layout = Instance.new("UIListLayout")
	layout.Name = "EntryLayout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 0)
	layout.Parent = logBody

	screenGui = gui
	frame = root
	body = logBody
	toggleButton = toggle
	table.clear(entryLabels)
	entrySequence = 0
	observedLevel = readLevel()
	stopObserving = ResponsiveLayout.observe(function(metrics)
		local wasTouch = currentMetrics ~= nil and (currentMetrics :: ResponsiveLayout.Metrics).isTouch
		currentMetrics = metrics
		if metrics.isTouch and not wasTouch then expanded = false end
		setExpanded(expanded)
	end)

	toggle.Activated:Connect(function()
		setExpanded(not expanded)
	end)
	presentationConnection = ReplicatedStorage.Remotes.CombatPresentation.OnClientEvent:Connect(onPresentation)
	levelConnection = player:GetAttributeChangedSignal(ProgressionConfig.LevelAttribute):Connect(onLevelChanged)
end

function CombatLog.stop(): ()
	if presentationConnection ~= nil then presentationConnection:Disconnect(); presentationConnection = nil end
	if levelConnection ~= nil then levelConnection:Disconnect(); levelConnection = nil end
	if stopObserving ~= nil then stopObserving(); stopObserving = nil end
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	frame = nil
	body = nil
	toggleButton = nil
	table.clear(entryLabels)
	entrySequence = 0
	observedLevel = nil
	expanded = true
	currentMetrics = nil
end

return CombatLog
