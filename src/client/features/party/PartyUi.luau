--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PartyConfig = require(ReplicatedStorage.Shared.party.PartyConfig)
local HudLayout = require(script.Parent.Parent.Parent.ui.HudLayout)

local PartyUi = {}
local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil
local partyWidget: Frame? = nil
local widgetButton: TextButton? = nil
local rosterPanel: Frame? = nil
local memberList: ScrollingFrame? = nil
local inviteBanner: Frame? = nil
local inviteMessage: TextLabel? = nil
local feedbackLabel: TextLabel? = nil
local snapshot: any = nil
local callbacks: any = nil
local expanded = false
local connections: { RBXScriptConnection } = {}
local observed: { RBXScriptConnection } = {}
local rowConnections: { RBXScriptConnection } = {}
local inviteGeneration = 0
local feedbackGeneration = 0

local RESULT_TEXT = table.freeze({
	NotReady = "Игрок ещё не готов", AlreadyInParty = "Игрок уже состоит в группе",
	PartyFull = "В группе нет свободных мест", InviteCooldown = "Подождите перед повторным приглашением",
	TargetUnavailable = "Игрок недоступен", NotAllowed = "Приглашать может только лидер группы",
	SelfInvite = "Нельзя пригласить самого себя", InvalidInvite = "Приглашение больше не действительно",
	ExpiredInvite = "Срок приглашения истёк", PartyChanged = "Состав группы уже изменился",
	NotInParty = "Вы не состоите в группе", NotLeader = "Исключать участников может только лидер",
	CannotKickSelf = "Лидер не может исключить себя", TargetNotMember = "Игрок больше не состоит в группе",
})

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number?): TextLabel
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1; value.Position = position; value.Size = size; value.Text = text
	value.TextColor3 = Color3.fromRGB(235, 235, 240); value.Font = Enum.Font.GothamMedium
	value.TextSize = textSize or 14; value.TextXAlignment = Enum.TextXAlignment.Left; value.Parent = parent
	return value
end

local function button(parent: Instance, text: string, position: UDim2, size: UDim2, callback: () -> (), dynamic: boolean?): TextButton
	local value = Instance.new("TextButton")
	value.Position = position; value.Size = size; value.Text = text; value.Font = Enum.Font.GothamBold
	value.TextSize = 12; value.TextColor3 = Color3.fromRGB(245, 245, 245)
	value.BackgroundColor3 = Color3.fromRGB(63, 70, 83); value.BorderSizePixel = 0; value.Parent = parent
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = value
	local connection = value.Activated:Connect(callback)
	table.insert(if dynamic then rowConnections else connections, connection)
	return value
end

local function hasParty(): boolean
	return snapshot ~= nil and typeof(snapshot.memberUserIds) == "table" and #snapshot.memberUserIds >= 2
end

local function displayName(player: Player?): string
	return if player then player:GetAttribute("CharacterNickname") or player.DisplayName else "Offline"
end

local function disconnectRows(): ()
	for _, connection in observed do connection:Disconnect() end
	for _, connection in rowConnections do connection:Disconnect() end
	table.clear(observed); table.clear(rowConnections)
end

local function clearRows(): ()
	if memberList == nil then return end
	disconnectRows()
	for _, child in memberList:GetChildren() do if child:GetAttribute("PartyRow") then child:Destroy() end end
end

local function setExpanded(value: boolean): ()
	expanded = value and hasParty()
	if rosterPanel then rosterPanel.Visible = expanded end
	if widgetButton then widgetButton.Text = string.gsub(widgetButton.Text, expanded and "▴$" or "▾$", expanded and "▾" or "▴") end
end

local function renderParty(): ()
	if partyWidget == nil or widgetButton == nil or rosterPanel == nil or memberList == nil then return end
	clearRows()
	local active = hasParty()
	partyWidget.Visible = active
	if not active then setExpanded(false); return end

	local members = snapshot.memberUserIds
	local isLeader = snapshot.leaderUserId == localPlayer.UserId
	widgetButton.Text = string.format("👥  %d/%d%s  %s", #members, PartyConfig.MaxMembers, if isLeader then " · ★" else "", if expanded then "▾" else "▴")
	memberList.CanvasSize = UDim2.fromOffset(0, #members * 42)
	for index, userId in members do
		local member = Players:GetPlayerByUserId(userId)
		local row = Instance.new("Frame"); row.Name = "MemberRow"; row:SetAttribute("PartyRow", true)
		row.BackgroundColor3 = Color3.fromRGB(29, 32, 40); row.BackgroundTransparency = 0.12; row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(0, (index - 1) * 42); row.Size = UDim2.new(1, 0, 0, 38); row.Parent = memberList
		local isSelf = userId == localPlayer.UserId
		local leaderMarker = if snapshot.leaderUserId == userId then "★ Лидер · " else ""
		local name = label(row, "", UDim2.fromOffset(8, 1), UDim2.new(1, if isLeader and not isSelf then -84 else -16, 0, 18), 12)
		local healthBar = Instance.new("Frame"); healthBar.BackgroundColor3 = Color3.fromRGB(56, 59, 67); healthBar.BorderSizePixel = 0
		healthBar.Position = UDim2.fromOffset(8, 22); healthBar.Size = UDim2.new(1, if isLeader and not isSelf then -84 else -16, 0, 10); healthBar.Parent = row
		local healthFill = Instance.new("Frame"); healthFill.Name = "HealthFill"; healthFill.BackgroundColor3 = Color3.fromRGB(117, 170, 101)
		healthFill.BorderSizePixel = 0; healthFill.Size = UDim2.fromScale(0, 1); healthFill.Parent = healthBar
		local function update(): ()
			local character = if member then member.Character else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local suffix = if isSelf then " (Вы)" else ""
			if humanoid and humanoid.Health <= 0 then
				name.Text = leaderMarker .. displayName(member) .. suffix .. " · DEAD"; healthFill.Size = UDim2.fromScale(0, 1)
			elseif humanoid then
				name.Text = string.format("%s%s%s · HP %d/%d", leaderMarker, displayName(member), suffix, humanoid.Health, humanoid.MaxHealth)
				healthFill.Size = UDim2.fromScale(if humanoid.MaxHealth > 0 then math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) else 0, 1)
			else name.Text = leaderMarker .. displayName(member) .. suffix .. " · HP —" end
		end
		update()
		if member then
			table.insert(observed, member.CharacterAdded:Connect(function() task.defer(renderParty) end))
			local humanoid = if member.Character then member.Character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then table.insert(observed, humanoid.HealthChanged:Connect(update)) end
		end
		if isLeader and not isSelf then
			button(row, "ИСКЛ.", UDim2.new(1, -70, 0.5, -14), UDim2.fromOffset(64, 28), function() callbacks.kick(userId) end, true)
		end
	end
end

local function hideInvite(inviteId: string?): ()
	if inviteBanner == nil then return end
	if inviteId ~= nil and inviteBanner:GetAttribute("InviteId") ~= inviteId then return end
	inviteGeneration += 1; inviteBanner:SetAttribute("InviteId", nil); inviteBanner.Visible = false
end

function PartyUi.setSnapshot(value: any): () snapshot = value; renderParty() end

function PartyUi.setInvite(value: any): ()
	if inviteBanner == nil or inviteMessage == nil or typeof(value) ~= "table" or typeof(value.inviteId) ~= "string" then return end
	local inviteId = value.inviteId
	if value.cancelled then hideInvite(inviteId); return end
	inviteGeneration += 1; local ownGeneration = inviteGeneration
	inviteBanner:SetAttribute("InviteId", inviteId); inviteMessage.Text = tostring(value.inviterName) .. " приглашает вас в группу"; inviteBanner.Visible = true
	local expiresAt = if typeof(value.expiresAt) == "number" then value.expiresAt else workspace:GetServerTimeNow() + PartyConfig.InviteTtlSeconds
	task.delay(math.max(0, expiresAt - workspace:GetServerTimeNow()), function() if inviteGeneration == ownGeneration then hideInvite(inviteId) end end)
end

function PartyUi.showResult(value: any): ()
	if feedbackLabel == nil or typeof(value) ~= "table" then return end
	local message = if value.ok and value.action == "Invite" then "Приглашение отправлено" elseif value.ok then "Готово" else RESULT_TEXT[value.reason] or tostring(value.reason or "Действие отклонено")
	feedbackGeneration += 1; local ownGeneration = feedbackGeneration
	feedbackLabel.Text = message; feedbackLabel.Visible = true
	task.delay(2.5, function() if feedbackGeneration == ownGeneration and feedbackLabel then feedbackLabel.Visible = false end end)
end

function PartyUi.toggle(): () setExpanded(not expanded) end

function PartyUi.start(actions: any): ()
	PartyUi.stop(); callbacks = actions
	gui = Instance.new("ScreenGui"); gui.Name = "PartyUi"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = false; gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local mobile = UserInputService.TouchEnabled
	feedbackLabel = label(gui, "", UDim2.new(0.5, -150, 0, if mobile then 128 else 180), UDim2.fromOffset(300, 32), if mobile then 12 else 14)
	feedbackLabel.Name = "PartyActionFeedback"; feedbackLabel.BackgroundColor3 = Color3.fromRGB(22, 24, 31); feedbackLabel.BackgroundTransparency = 0.12
	feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center; feedbackLabel.Visible = false

	partyWidget = Instance.new("Frame"); partyWidget.Name = "PartyHud"; partyWidget.AnchorPoint = Vector2.new(0.5, 1)
	partyWidget.Position = UDim2.new(0.5, 0, 1, if mobile then -58 else -96); partyWidget.Size = UDim2.fromOffset(if mobile then 300 else 360, if mobile then 210 else 232)
	partyWidget.BackgroundTransparency = 1; partyWidget.Visible = false; partyWidget.Parent = gui
	widgetButton = button(partyWidget, "👥  0/4  ▴", UDim2.new(0.5, -90, 1, -32), UDim2.fromOffset(180, 32), PartyUi.toggle)
	widgetButton.Name = "CollapsedPartyWidget"

	rosterPanel = Instance.new("Frame"); rosterPanel.Name = "ExpandedPartyRoster"; rosterPanel.Position = UDim2.fromOffset(0, 0)
	rosterPanel.Size = UDim2.new(1, 0, 1, -40); rosterPanel.Visible = false; rosterPanel.Parent = partyWidget; HudLayout.applyPanelStyle(rosterPanel)
	label(rosterPanel, "СОСТАВ ГРУППЫ", UDim2.fromOffset(10, 4), UDim2.new(1, -120, 0, 28), 13)
	button(rosterPanel, "ПОКИНУТЬ", UDim2.new(1, -104, 0, 4), UDim2.fromOffset(94, 28), function() callbacks.leave() end)
	memberList = Instance.new("ScrollingFrame"); memberList.Name = "MemberList"; memberList.BackgroundTransparency = 1; memberList.BorderSizePixel = 0
	memberList.Position = UDim2.fromOffset(8, 36); memberList.Size = UDim2.new(1, -16, 1, -44); memberList.ScrollBarThickness = 4; memberList.Parent = rosterPanel

	inviteBanner = Instance.new("Frame"); inviteBanner.Name = "InviteBanner"; inviteBanner.AnchorPoint = Vector2.new(0.5, 0)
	inviteBanner.Position = UDim2.new(0.5, 0, 0, if mobile then 68 else 122); inviteBanner.Size = if mobile then UDim2.new(1, -16, 0, 54) else UDim2.fromOffset(620, 48)
	inviteBanner.Visible = false; inviteBanner.Parent = gui; HudLayout.applyPanelStyle(inviteBanner)
	inviteMessage = label(inviteBanner, "", UDim2.fromOffset(12, 0), UDim2.new(1, if mobile then -178 else -224, 1, 0), if mobile then 11 else 14)
	button(inviteBanner, "Принять", UDim2.new(1, if mobile then -164 else -204, 0.5, -16), UDim2.fromOffset(if mobile then 76 else 94, 32), function()
		local id = inviteBanner and inviteBanner:GetAttribute("InviteId"); if typeof(id) == "string" then callbacks.accept(id); hideInvite(id) end
	end)
	button(inviteBanner, "Отклонить", UDim2.new(1, if mobile then -84 else -104, 0.5, -16), UDim2.fromOffset(if mobile then 78 else 94, 32), function()
		local id = inviteBanner and inviteBanner:GetAttribute("InviteId"); if typeof(id) == "string" then callbacks.decline(id); hideInvite(id) end
	end)
	table.insert(connections, Players.PlayerRemoving:Connect(function() task.defer(renderParty) end))
	renderParty()
end

function PartyUi.stop(): ()
	inviteGeneration += 1; feedbackGeneration += 1; disconnectRows()
	for _, connection in connections do connection:Disconnect() end; table.clear(connections)
	if gui then gui:Destroy() end
	gui=nil; partyWidget=nil; widgetButton=nil; rosterPanel=nil; memberList=nil; inviteBanner=nil; inviteMessage=nil; feedbackLabel=nil
	snapshot=nil; callbacks=nil; expanded=false
end

return PartyUi
