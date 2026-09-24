--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local PartyConfig = require(ReplicatedStorage.Shared.party.PartyConfig)
local HudLayout = require(script.Parent.Parent.Parent.ui.HudLayout)

local PartyUi = {}
local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil
local panel: Frame? = nil
local memberList: ScrollingFrame? = nil
local partyWidget: Frame? = nil
local hudRows: Frame? = nil
local inviteBanner: Frame? = nil
local inviteMessage: TextLabel? = nil
local statusLabel: TextLabel? = nil
local feedbackLabel: TextLabel? = nil
local snapshot: any = nil
local callbacks: any = nil
local connections: { RBXScriptConnection } = {}
local observed: { RBXScriptConnection } = {}
local inviteGeneration = 0
local feedbackGeneration = 0

local RESULT_TEXT = table.freeze({
	NotReady = "Игрок ещё не готов",
	AlreadyInParty = "Игрок уже состоит в группе",
	PartyFull = "В группе нет свободных мест",
	InviteCooldown = "Подождите перед повторным приглашением",
	TargetUnavailable = "Игрок недоступен",
	NotAllowed = "Приглашать может только лидер группы",
	SelfInvite = "Нельзя пригласить самого себя",
	InvalidInvite = "Приглашение больше не действительно",
	ExpiredInvite = "Срок приглашения истёк",
	PartyChanged = "Состав группы уже изменился",
	NotInParty = "Вы не состоите в группе",
})

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number?): TextLabel
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1; value.Position = position; value.Size = size; value.Text = text
	value.TextColor3 = Color3.fromRGB(235, 235, 240); value.Font = Enum.Font.GothamMedium
	value.TextSize = textSize or 14; value.TextXAlignment = Enum.TextXAlignment.Left; value.Parent = parent
	return value
end

local function button(parent: Instance, text: string, position: UDim2, size: UDim2, callback: () -> ()): TextButton
	local value = Instance.new("TextButton")
	value.Position = position; value.Size = size; value.Text = text; value.Font = Enum.Font.GothamBold
	value.TextSize = 12; value.TextColor3 = Color3.fromRGB(245, 245, 245)
	value.BackgroundColor3 = Color3.fromRGB(63, 70, 83); value.BorderSizePixel = 0; value.Parent = parent
	local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 4); corner.Parent = value
	table.insert(connections, value.Activated:Connect(callback))
	return value
end

local function hasActiveParty(): boolean
	return snapshot ~= nil and typeof(snapshot.memberUserIds) == "table" and #snapshot.memberUserIds >= 2
end

local function playerName(value: Player?): string
	return if value then value:GetAttribute("CharacterNickname") or value.DisplayName else "Offline"
end

local function clearRows(container: Instance): ()
	for _, child in container:GetChildren() do if child:GetAttribute("PartyRow") then child:Destroy() end end
end

local function hideInvite(inviteId: string?): ()
	if inviteBanner == nil then return end
	local activeId = inviteBanner:GetAttribute("InviteId")
	if inviteId ~= nil and activeId ~= inviteId then return end
	inviteGeneration += 1
	inviteBanner:SetAttribute("InviteId", nil)
	inviteBanner.Visible = false
end

local function renderParty(): ()
	if partyWidget == nil or hudRows == nil or panel == nil or memberList == nil then return end
	clearRows(hudRows); clearRows(memberList)
	for _, connection in observed do connection:Disconnect() end
	table.clear(observed)

	local active = hasActiveParty()
	partyWidget.Visible = active
	if not active then panel.Visible = false; return end
	local memberUserIds = snapshot.memberUserIds
	memberList.CanvasSize = UDim2.fromOffset(0, #memberUserIds * 44)
	local hudIndex = 0
	for index, userId in memberUserIds do
		local member = Players:GetPlayerByUserId(userId)
		local leaderPrefix = if snapshot.leaderUserId == userId then "◆ " else ""
		local memberRow = label(memberList, leaderPrefix .. playerName(member), UDim2.fromOffset(8, (index - 1) * 44), UDim2.new(1, -16, 0, 40), 14)
		memberRow:SetAttribute("PartyRow", true)
		if userId == localPlayer.UserId then continue end
		hudIndex += 1
		local row = Instance.new("Frame"); row:SetAttribute("PartyRow", true); row.BorderSizePixel = 0
		row.BackgroundColor3 = Color3.fromRGB(22, 24, 31); row.BackgroundTransparency = 0.12
		row.Position = UDim2.fromOffset(0, 30 + (hudIndex - 1) * 38); row.Size = UDim2.new(1, 0, 0, 34); row.Parent = hudRows
		local title = label(row, "", UDim2.fromOffset(7, 1), UDim2.new(1, -14, 0, 16), 12)
		local health = label(row, "", UDim2.fromOffset(7, 16), UDim2.new(1, -14, 0, 16), 11)
		health.TextColor3 = Color3.fromRGB(184, 211, 179)
		local function update(): ()
			local character = if member then member.Character else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			local level = if member then member:GetAttribute(ProgressionConfig.LevelAttribute) else nil
			title.Text = leaderPrefix .. playerName(member) .. "  LVL " .. tostring(level or "—")
			health.Text = if humanoid and humanoid.Health <= 0 then "DEAD"
				elseif humanoid then string.format("HP %d / %d", humanoid.Health, humanoid.MaxHealth) else "HP —"
		end
		update()
		if member then
			table.insert(observed, member.CharacterAdded:Connect(function() task.defer(renderParty) end))
			local humanoid = if member.Character then member.Character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then table.insert(observed, humanoid.HealthChanged:Connect(update)) end
		end
	end
end

function PartyUi.setSnapshot(value: any): () snapshot = value; renderParty() end

function PartyUi.setInvite(value: any): ()
	if inviteBanner == nil or inviteMessage == nil or typeof(value) ~= "table" then return end
	local inviteId = value.inviteId
	if typeof(inviteId) ~= "string" then return end
	if value.cancelled then hideInvite(inviteId); return end
	inviteGeneration += 1
	local ownGeneration = inviteGeneration
	inviteBanner:SetAttribute("InviteId", inviteId)
	inviteMessage.Text = tostring(value.inviterName) .. " приглашает вас в группу"
	inviteBanner.Visible = true
	local expiresAt = if typeof(value.expiresAt) == "number" then value.expiresAt else workspace:GetServerTimeNow() + PartyConfig.InviteTtlSeconds
	task.delay(math.max(0, expiresAt - workspace:GetServerTimeNow()), function()
		if inviteGeneration == ownGeneration then hideInvite(inviteId) end
	end)
end

function PartyUi.showResult(value: any): ()
	if typeof(value) ~= "table" then return end
	local message = if value.ok and value.action == "Invite" then "Приглашение отправлено"
		elseif value.ok then "Готово"
		else RESULT_TEXT[value.reason] or tostring(value.reason or "Действие отклонено")
	if statusLabel then statusLabel.Text = message end
	if feedbackLabel == nil then return end
	feedbackGeneration += 1
	local ownGeneration = feedbackGeneration
	feedbackLabel.Text = message
	feedbackLabel.Visible = true
	task.delay(2.5, function()
		if feedbackGeneration == ownGeneration and feedbackLabel ~= nil then feedbackLabel.Visible = false end
	end)
end

function PartyUi.toggle(): ()
	if panel and hasActiveParty() then panel.Visible = not panel.Visible end
end

function PartyUi.start(actions: any): ()
	PartyUi.stop(); callbacks = actions
	gui = Instance.new("ScreenGui"); gui.Name = "PartyUi"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = false
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	local mobile = UserInputService.TouchEnabled
	feedbackLabel = label(gui, "", UDim2.new(0.5, -150, 0, if mobile then 128 else 180), UDim2.fromOffset(300, 32), if mobile then 12 else 14)
	feedbackLabel.Name = "PartyActionFeedback"; feedbackLabel.BackgroundColor3 = Color3.fromRGB(22, 24, 31)
	feedbackLabel.BackgroundTransparency = 0.12; feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
	feedbackLabel.Visible = false

	partyWidget = Instance.new("Frame"); partyWidget.Name = "PartyHud"; partyWidget.BackgroundTransparency = 1
	partyWidget.AnchorPoint = Vector2.new(1, 0); partyWidget.Position = UDim2.new(1, if mobile then -8 else -24, 0, if mobile then 132 else 224)
	partyWidget.Size = UDim2.fromOffset(if mobile then 200 else 230, 144); partyWidget.Visible = false; partyWidget.Parent = gui
	button(partyWidget, "ГРУППА", UDim2.fromOffset(0, 0), UDim2.fromOffset(if mobile then 82 else 96, 26), PartyUi.toggle)
	hudRows = Instance.new("Frame"); hudRows.BackgroundTransparency = 1; hudRows.Size = UDim2.fromScale(1, 1); hudRows.Parent = partyWidget

	panel = Instance.new("Frame"); panel.Name = "PartyPanel"; panel.AnchorPoint = Vector2.new(0.5, 0.5); panel.Position = UDim2.fromScale(0.5, if mobile then 0.42 else 0.5)
	panel.Size = if mobile then UDim2.fromOffset(300, 240) else UDim2.fromOffset(360, 300)
	panel.Visible = false; panel.Parent = gui; HudLayout.applyPanelStyle(panel)
	label(panel, "СОСТАВ ГРУППЫ", UDim2.fromOffset(16, 10), UDim2.new(1, -68, 0, 32), 17)
	table.insert(connections, HudLayout.makeCloseButton(panel).Activated:Connect(function() if panel then panel.Visible = false end end))
	memberList = Instance.new("ScrollingFrame"); memberList.Name = "MemberList"; memberList.BackgroundTransparency = 1
	memberList.BorderSizePixel = 0; memberList.Position = UDim2.fromOffset(12, 52); memberList.Size = UDim2.new(1, -24, 1, -116)
	memberList.ScrollBarThickness = 5; memberList.Parent = panel
	statusLabel = label(panel, "", UDim2.fromOffset(14, -58), UDim2.new(1, -174, 0, 32), 12); statusLabel.AnchorPoint = Vector2.new(0, 1); statusLabel.Position = UDim2.new(0, 14, 1, -10)
	button(panel, "ПОКИНУТЬ ГРУППУ", UDim2.new(1, -154, 1, -48), UDim2.fromOffset(140, 34), function() callbacks.leave() end)

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
	inviteGeneration += 1
	feedbackGeneration += 1
	for _, connection in connections do connection:Disconnect() end
	for _, connection in observed do connection:Disconnect() end
	table.clear(connections); table.clear(observed)
	if gui then gui:Destroy() end
	gui=nil; panel=nil; memberList=nil; partyWidget=nil; hudRows=nil; inviteBanner=nil; inviteMessage=nil; statusLabel=nil; feedbackLabel=nil
	snapshot=nil; callbacks=nil
end

return PartyUi
