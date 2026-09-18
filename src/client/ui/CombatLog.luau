--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local ClientCombatLogRules = require(ReplicatedStorage.Shared.combat.ClientCombatLogRules)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)

local CombatLog = {}

local player = Players.LocalPlayer
local localEntityId = "player:" .. tostring(player.UserId)
local screenGui: ScreenGui? = nil
local frame: Frame? = nil
local body: Frame? = nil
local toggleButton: TextButton? = nil
local presentationConnection: RBXScriptConnection? = nil
local expanded = true
local entries: { string } = {}
local MAX_ENTRIES = 9

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

local function append(text: string): ()
	if text == "" or body == nil then return end
	table.insert(entries, text)
	while #entries > MAX_ENTRIES do table.remove(entries, 1) end

	for _, child in body:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	for index, entry in entries do
		local label = Instance.new("TextLabel")
		label.Name = "Entry" .. tostring(index)
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(8, (index - 1) * 18)
		label.Size = UDim2.new(1, -16, 0, 18)
		label.Font = Enum.Font.RobotoMono
		label.TextColor3 = Color3.fromRGB(224, 224, 230)
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = entry
		label.Parent = body
	end
end

local function setExpanded(value: boolean): ()
	expanded = value
	if body ~= nil then body.Visible = expanded end
	if frame ~= nil then
		frame.Size = if expanded then UDim2.fromOffset(500, 190) else UDim2.fromOffset(128, 30)
	end
	if toggleButton ~= nil then toggleButton.Text = if expanded then "БОЙ  ▲" else "БОЙ  ▼" end
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

function CombatLog.start(): ()
	CombatLog.stop()

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatLog"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "CombatLogFrame"
	root.AnchorPoint = Vector2.new(0, 1)
	root.Position = UDim2.new(0, 8, 1, -8)
	root.Size = UDim2.fromOffset(500, 190)
	root.BackgroundColor3 = Color3.fromRGB(20, 22, 29)
	root.BackgroundTransparency = 0.18
	root.BorderSizePixel = 0
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

	local logBody = Instance.new("Frame")
	logBody.Name = "Entries"
	logBody.Position = UDim2.fromOffset(0, 30)
	logBody.Size = UDim2.new(1, 0, 1, -30)
	logBody.BackgroundTransparency = 1
	logBody.Parent = root

	screenGui = gui
	frame = root
	body = logBody
	toggleButton = toggle
	table.clear(entries)
	setExpanded(true)

	toggle.Activated:Connect(function()
		setExpanded(not expanded)
	end)
	presentationConnection = ReplicatedStorage.Remotes.CombatPresentation.OnClientEvent:Connect(onPresentation)
end

function CombatLog.stop(): ()
	if presentationConnection ~= nil then presentationConnection:Disconnect(); presentationConnection = nil end
	if screenGui ~= nil then screenGui:Destroy(); screenGui = nil end
	frame = nil
	body = nil
	toggleButton = nil
	table.clear(entries)
	expanded = true
end

return CombatLog
