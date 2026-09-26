--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local NpcDefinitions = require(ReplicatedStorage.Shared.definitions.NpcDefinitions)
local HudLayout = require(script.Parent.Parent.Parent.ui.HudLayout)
local MobileOverlayCoordinator = require(script.Parent.Parent.Parent.ui.MobileOverlayCoordinator)
local MobileSurface = require(script.Parent.Parent.Parent.ui.MobileSurface)
local ResponsiveLayout = require(script.Parent.Parent.Parent.ui.ResponsiveLayout)

local QuestController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local acceptRemote = remotes:WaitForChild("QuestAcceptRequest") :: RemoteEvent
local turnInRemote = remotes:WaitForChild("QuestTurnInRequest") :: RemoteEvent
local snapshotRequest = remotes:WaitForChild("QuestSnapshotRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("QuestSnapshot") :: RemoteEvent
local dialogueEvent = remotes:WaitForChild("DialogueOpen") :: RemoteEvent
local travelRequest = remotes:WaitForChild("TravelRequest") :: RemoteEvent
local travelResult = remotes:WaitForChild("TravelResult") :: RemoteEvent

local WAYPOINT_HIDE_DISTANCE = 80
local STUDS_PER_METER = 10

local gui: ScreenGui? = nil
local dialogue: Frame? = nil
local questOffer: Frame? = nil
local travelConfirm: Frame? = nil
local journal: Frame? = nil
local journalList: ScrollingFrame? = nil
local mapFrame: Frame? = nil
local modalBlocker: TextButton? = nil
local mapCanvas: Frame? = nil
local playerDot: TextLabel? = nil
local dungeonEntranceLabel: TextLabel? = nil

local snapshot: any = { quests = {}, markers = {} }
local firstSnapshotReceived = false
local connections: { RBXScriptConnection } = {}
local markerGuis: { BillboardGui } = {}
local waypointLabels: { [string]: TextLabel } = {}
local mapQuestDots: { [string]: TextLabel } = {}
local activeQuestIds: { [string]: boolean } = {}
local seenQuestIds: { [string]: boolean } = {}
local stopObserving: (() -> ())? = nil

local function applyMobileLayout(metrics: ResponsiveLayout.Metrics): ()
	if not metrics.isTouch then return end
	if dialogue ~= nil then
		dialogue:SetAttribute("MobileSurface", "MenuSheet")
		MobileSurface.apply(dialogue, "MenuSheet", metrics, math.min(300, metrics.usableHeight * 0.7))
	end
	if questOffer ~= nil then
		questOffer:SetAttribute("MobileSurface", "CompactDialog")
		MobileSurface.apply(questOffer, "CompactDialog", metrics, math.min(340, metrics.usableHeight * 0.65))
	end
	if travelConfirm ~= nil then
		travelConfirm:SetAttribute("MobileSurface", "CompactDialog")
		MobileSurface.apply(travelConfirm, "CompactDialog", metrics, 220)
	end
	for _, workspaceFrame in { journal, mapFrame } do
		if workspaceFrame ~= nil then
			workspaceFrame:SetAttribute("MobileSurface", "FullWorkspace")
			MobileSurface.apply(workspaceFrame, "FullWorkspace", metrics)
			local constraint = workspaceFrame:FindFirstChildOfClass("UISizeConstraint")
			if constraint ~= nil then
				constraint.MinSize = Vector2.zero
				constraint.MaxSize = Vector2.new(10000, 10000)
			end
		end
	end
end

local function syncWorkspaceHud(): ()
	if gui == nil then return end
	MobileOverlayCoordinator.setWorkspaceOpen(gui, (journal ~= nil and journal.Visible) or (mapFrame ~= nil and mapFrame.Visible))
end

local MAP_POIS = {
	{ id = "poi_moonfall_farm", label = "Farm" },
	{ id = "poi_stone_circle", label = "Stone Circle" },
	{ id = "poi_moonfall_crossroads", label = "Moonfall" },
}

local function poi(id: string): Vector3?
	for _, point in WorldLayout.PointsOfInterest do
		if point.id == id then return point.position end
	end
	return nil
end

local function makeText(parent: Instance, value: string, size: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = value
	label.TextColor3 = Color3.fromRGB(236, 229, 205)
	label.Font = Enum.Font.Gotham
	label.TextSize = size
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 4
	label.Parent = parent
	return label
end

local function makeButton(parent: Instance, value: string): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(48, 52, 61)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(235, 224, 194)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextWrapped = true
	button.Text = value
	button.Parent = parent
	return button
end

local function clearChildren(parent: Instance): ()
	for _, child in parent:GetChildren() do
		child:Destroy()
	end
end

local function normalizedMapPoint(position: Vector3): Vector2
	local bounds = WorldLayout.WorldBounds
	local x = (position.X - bounds.minX) / (bounds.maxX - bounds.minX)
	local z = (position.Z - bounds.minZ) / (bounds.maxZ - bounds.minZ)
	-- World north is +Z. The authored map is rotated 180 degrees so north is up.
	return Vector2.new(1 - math.clamp(x, 0, 1), 1 - math.clamp(z, 0, 1))
end

local function mapPosition(position: Vector3): UDim2
	local p = normalizedMapPoint(position)
	return UDim2.fromScale(0.04 + p.X * 0.92, 0.04 + p.Y * 0.92)
end

local function addMapDot(parent: Instance, position: Vector3, size: number, color: Color3, transparency: number): Frame
	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = mapPosition(position)
	dot.Size = UDim2.fromOffset(size, size)
	dot.BackgroundColor3 = color
	dot.BackgroundTransparency = transparency
	dot.BorderSizePixel = 0
	dot.ZIndex = 2
	dot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	return dot
end

local function addDottedPolyline(parent: Instance, points: { Vector3 }, color: Color3, dotSize: number): ()
	for index = 1, #points - 1 do
		local a = points[index]
		local b = points[index + 1]
		local distance = (Vector2.new(a.X, a.Z) - Vector2.new(b.X, b.Z)).Magnitude
		local steps = math.max(2, math.ceil(distance / 75))
		for step = 0, steps - 1 do
			addMapDot(parent, a:Lerp(b, step / steps), dotSize, color, 0.3)
		end
	end
	if #points > 0 then
		addMapDot(parent, points[#points], dotSize, color, 0.3)
	end
end

local function zoneDefinition(zoneId: string): any?
	for _, candidate in WorldLayout.Zones do
		if candidate.id == zoneId then return candidate end
	end
	return nil
end

local function addZoneEllipses(parent: Instance): ()
	for index, volume in WorldLayout.ZoneVolumes do
		local min = volume.center - volume.size / 2
		local max = volume.center + volume.size / 2
		local p1 = normalizedMapPoint(min)
		local p2 = normalizedMapPoint(max)
		local left = math.min(p1.X, p2.X)
		local top = math.min(p1.Y, p2.Y)
		local right = math.max(p1.X, p2.X)
		local bottom = math.max(p1.Y, p2.Y)

		local zone = Instance.new("Frame")
		zone.Name = "Zone_" .. volume.zoneId
		zone.AnchorPoint = Vector2.new(0, 0)
		zone.Position = UDim2.fromScale(0.04 + left * 0.92, 0.04 + top * 0.92)
		zone.Size = UDim2.fromScale(
			math.max(0.04, (right - left) * 0.92),
			math.max(0.04, (bottom - top) * 0.92)
		)
		zone.BackgroundColor3 = if index % 2 == 0
			then Color3.fromRGB(81, 96, 69)
			else Color3.fromRGB(93, 78, 61)
		zone.BackgroundTransparency = 0.82
		zone.BorderSizePixel = 0
		zone.ZIndex = 1
		zone.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = zone

		local definition = zoneDefinition(volume.zoneId)
		if definition ~= nil then
			local label = makeText(zone, definition.displayName, 14)
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.Size = UDim2.new(0.92, 0, 0, 24)
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextColor3 = Color3.fromRGB(213, 216, 197)
			label.TextStrokeColor3 = Color3.fromRGB(16, 20, 17)
			label.TextStrokeTransparency = 0.55
			label.ZIndex = 3
		end
	end
end

local function addRiver(parent: Instance): ()
	local bridge = poi("poi_meadow_bridge")
	if bridge == nil then return end

	for x = -1240, 1240, 70 do
		local z = bridge.Z + 0.065 * (x - bridge.X) + 28 * math.sin((x + 180) / 280)
		addMapDot(parent, Vector3.new(x, 0, z), 9, Color3.fromRGB(67, 139, 173), 0.18)
	end
end

local function addRoutes(parent: Instance): ()
	local roadColor = Color3.fromRGB(185, 158, 103)
	addDottedPolyline(parent, WorldLayout.Route, roadColor, 5)
	addDottedPolyline(parent, WorldLayout.MoonfallRoadRoute, roadColor, 5)
	addDottedPolyline(parent, WorldLayout.GoblinCampRoute, roadColor, 4)
	addDottedPolyline(parent, WorldLayout.SpiderHollowRoute, roadColor, 4)
	addDottedPolyline(parent, WorldLayout.SpiderReturnRoute, roadColor, 4)
	addDottedPolyline(parent, WorldLayout.AncientApproachRoute, roadColor, 5)
end

local function addPois(parent: Instance): ()
	for _, entry in MAP_POIS do
		local position = poi(entry.id)
		if position == nil then continue end

		local label = makeText(parent, "◆ " .. entry.label, 11)
		label.AnchorPoint = Vector2.new(0, 0.5)
		label.Position = mapPosition(position)
		label.Size = UDim2.fromOffset(130, 20)
		label.TextColor3 = Color3.fromRGB(232, 222, 188)
		label.TextStrokeColor3 = Color3.fromRGB(12, 16, 18)
		label.TextStrokeTransparency = 0.45
		label.ZIndex = 5
	end
end

local function buildMap(parent: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "WorldMap"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.62, 0.72)
	frame.BackgroundColor3 = Color3.fromRGB(18, 26, 28)
	frame.BackgroundTransparency = 0.14
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 20
	frame.Parent = parent

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(560, 430)
	sizeConstraint.MaxSize = Vector2.new(940, 720)
	sizeConstraint.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(116, 126, 112)
	stroke.Transparency = 0.25
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = makeText(frame, "КАРТА МИРА", 19)
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -110, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 22

	local close = HudLayout.makeCloseButton(frame, 24)
	table.insert(connections, close.Activated:Connect(function()
		QuestController.toggleMap()
	end))

	local canvas = Instance.new("Frame")
	canvas.Name = "MapCanvas"
	canvas.Position = UDim2.fromOffset(14, 48)
	canvas.Size = UDim2.new(1, -28, 1, -62)
	canvas.BackgroundColor3 = Color3.fromRGB(32, 45, 39)
	canvas.BackgroundTransparency = 0.28
	canvas.BorderSizePixel = 0
	canvas.ClipsDescendants = true
	canvas.ZIndex = 21
	canvas.Parent = frame
	mapCanvas = canvas

	local north = makeText(canvas, "N ↑", 12)
	north.AnchorPoint = Vector2.new(0.5, 0)
	north.Position = UDim2.fromScale(0.5, 0.01)
	north.Size = UDim2.fromOffset(42, 20)
	north.TextXAlignment = Enum.TextXAlignment.Center
	north.TextColor3 = Color3.fromRGB(220, 220, 210)
	north.ZIndex = 10

	addZoneEllipses(canvas)
	addRiver(canvas)
	addRoutes(canvas)
	addPois(canvas)

	playerDot = makeText(canvas, "● ВЫ", 13)
	playerDot.Size = UDim2.fromOffset(65, 22)
	playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	playerDot.TextColor3 = Color3.fromRGB(104, 220, 255)
	playerDot.TextStrokeColor3 = Color3.fromRGB(8, 20, 26)
	playerDot.TextStrokeTransparency = 0.2
	playerDot.ZIndex = 12

	return frame
end

local function activeTargetForQuest(quest: any): (Vector3?, string?)
	if quest.state == "ReadyToTurnIn" then
		local definition = NpcDefinitions[quest.turnInNpcId]
		if definition == nil then return nil, nil end
		local existing = workspace:FindFirstChild(definition.modelName, true)
		if existing ~= nil and existing:IsA("Model") then
			return existing:GetPivot().Position, quest.displayName
		end
		local base = poi(definition.poiId)
		if base ~= nil then
			return base + (definition.positionOffset or Vector3.zero), quest.displayName
		end
		return nil, quest.displayName
	end

	for _, objective in quest.objectives do
		if objective.progress >= objective.required then continue end
		if objective.npcId ~= nil then
			local definition = NpcDefinitions[objective.npcId]
			if definition ~= nil then
				local existing = workspace:FindFirstChild(definition.modelName, true)
				if existing ~= nil and existing:IsA("Model") then
					return existing:GetPivot().Position, objective.displayText
				end
				local base = poi(definition.poiId)
				if base ~= nil then return base + (definition.positionOffset or Vector3.zero), objective.displayText end
			end
		elseif objective.poiId ~= nil then
			return poi(objective.poiId), objective.displayText
		elseif objective.waypointPoiId ~= nil then
			return poi(objective.waypointPoiId), objective.displayText
		end
	end

	return nil, nil
end

local function questById(questId: string): any?
	for _, quest in snapshot.quests or {} do
		if quest.id == questId then return quest end
	end
	return nil
end

local function syncActiveQuestState(): ()
	local present: { [string]: boolean } = {}
	for _, quest in snapshot.quests or {} do
		present[quest.id] = true
		if seenQuestIds[quest.id] ~= true then
			seenQuestIds[quest.id] = true
			activeQuestIds[quest.id] = true
		end
	end
	for questId in activeQuestIds do
		if present[questId] ~= true then activeQuestIds[questId] = nil end
	end
end

local function buildJournal(): ()
	if journal == nil or journalList == nil then return end
	clearChildren(journalList)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = journalList

	local quests = snapshot.quests or {}
	if #quests == 0 then
		local empty = makeText(journalList, "Активных заданий пока нет.", 14)
		empty.Size = UDim2.new(1, -12, 0, 44)
		return
	end

	for _, quest in quests do
		local row = Instance.new("Frame")
		row.Name = quest.id
		row.Size = UDim2.new(1, -10, 0, 112 + #quest.objectives * 18)
		row.BackgroundColor3 = Color3.fromRGB(31, 34, 42)
		row.BackgroundTransparency = 0.15
		row.BorderSizePixel = 0
		row.Parent = journalList

		local title = makeText(row, quest.displayName, 15)
		title.Position = UDim2.fromOffset(12, 8)
		title.Size = UDim2.new(1, -136, 0, 26)
		title.Font = Enum.Font.GothamBold

		local active = activeQuestIds[quest.id] == true
		local toggle = makeButton(row, if active then "✓ АКТИВНО" else "○ НЕАКТИВНО")
		toggle.AnchorPoint = Vector2.new(1, 0)
		toggle.Position = UDim2.new(1, -10, 0, 8)
		toggle.Size = UDim2.fromOffset(112, 28)
		toggle.BackgroundColor3 = if active then Color3.fromRGB(78, 94, 54) else Color3.fromRGB(48, 52, 61)
		table.insert(connections, toggle.Activated:Connect(function()
			activeQuestIds[quest.id] = not active
			buildJournal()
		end))

		local lines = {}
		for _, objective in quest.objectives do
			table.insert(lines, string.format(
				"• %s  %d/%d",
				objective.displayText or objective.id,
				objective.progress,
				objective.required
			))
		end
		if quest.state == "ReadyToTurnIn" then
			table.insert(lines, "• Вернуться к NPC")
		end

		local body = makeText(row, table.concat(lines, "\n"), 12)
		body.Position = UDim2.fromOffset(12, 42)
		body.Size = UDim2.new(1, -24, 0, 26 + #lines * 18)
		body.TextYAlignment = Enum.TextYAlignment.Top
	end
end

local function buildJournalFrame(parent: ScreenGui): Frame
	local frame = Instance.new("Frame")
	frame.Name = "QuestJournal"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.48, 0.62)
	HudLayout.applyPanelStyle(frame)
	frame.Visible = false
	frame.ZIndex = 20
	frame.Parent = parent

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(520, 390)
	constraint.MaxSize = Vector2.new(760, 650)
	constraint.Parent = frame

	local title = makeText(frame, "ЗАДАНИЯ", 19)
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -80, 0, 30)
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 22

	local close = HudLayout.makeCloseButton(frame, 24)
	table.insert(connections, close.Activated:Connect(function()
		QuestController.toggleJournal()
	end))

	local list = Instance.new("ScrollingFrame")
	list.Name = "QuestList"
	list.Position = UDim2.fromOffset(16, 52)
	list.Size = UDim2.new(1, -32, 1, -68)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.fromOffset(0, 0)
	list.ZIndex = 21
	list.Parent = frame
	journalList = list

	return frame
end

local function showQuestOffer(value: any, topic: any): ()
	if questOffer == nil then return end
	clearChildren(questOffer)
	questOffer.Visible = true
	if dialogue ~= nil then dialogue.Visible = false end

	local close = HudLayout.makeCloseButton(questOffer, 24)
	table.insert(connections, close.Activated:Connect(function()
		if questOffer ~= nil then questOffer.Visible = false end
		if dialogue ~= nil then dialogue.Visible = true end
	end))

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 28)
	padding.PaddingBottom = UDim.new(0, 24)
	padding.PaddingLeft = UDim.new(0, 30)
	padding.PaddingRight = UDim.new(0, 30)
	padding.Parent = questOffer

	local title = makeText(questOffer, topic.title or "Квест", 20)
	title.Position = UDim2.fromOffset(0, 6)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 22

	local descriptionScroll = Instance.new("ScrollingFrame")
	descriptionScroll.Name = "DescriptionScroll"
	descriptionScroll.Position = UDim2.fromOffset(0, 60)
	descriptionScroll.Size = UDim2.new(1, 0, 1, -160)
	descriptionScroll.BackgroundTransparency = 1
	descriptionScroll.BorderSizePixel = 0
	descriptionScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	descriptionScroll.CanvasSize = UDim2.fromOffset(0, 0)
	descriptionScroll.ScrollBarThickness = 5
	descriptionScroll.ZIndex = 22
	descriptionScroll.Parent = questOffer
	local description = makeText(descriptionScroll, topic.description or "", 14)
	description.Size = UDim2.new(1, -10, 0, 0)
	description.AutomaticSize = Enum.AutomaticSize.Y
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.ZIndex = 22

	local rewardParts = {}
	if (topic.rewardXP or 0) > 0 then table.insert(rewardParts, string.format("%d XP", topic.rewardXP)) end
	if (topic.rewardLuna or 0) > 0 then table.insert(rewardParts, string.format("%d Luna", topic.rewardLuna)) end
	if #rewardParts > 0 then
		local reward = makeText(questOffer, "Награда: " .. table.concat(rewardParts, " · "), 12)
		reward.Position = UDim2.new(0, 0, 1, -92)
		reward.Size = UDim2.new(1, 0, 0, 24)
		reward.TextXAlignment = Enum.TextXAlignment.Center
		reward.TextTransparency = 0.15
		reward.ZIndex = 22
	end

	local primaryText = if topic.kind == "TurnInQuest" then "Завершить" else "Принять"
	local primary = makeButton(questOffer, primaryText)
	primary.Position = UDim2.new(0, 0, 1, -50)
	primary.Size = UDim2.new(0.48, 0, 0, 42)
	primary.ZIndex = 22

	local decline = makeButton(questOffer, if topic.kind == "TurnInQuest" then "Назад" else "Отказаться")
	decline.AnchorPoint = Vector2.new(1, 0)
	decline.Position = UDim2.new(1, 0, 1, -50)
	decline.Size = UDim2.new(0.48, 0, 0, 42)
	decline.ZIndex = 22

	table.insert(connections, primary.Activated:Connect(function()
		if topic.kind == "TurnInQuest" then
			turnInRemote:FireServer(topic.questId, value.npcId)
		else
			acceptRemote:FireServer(topic.questId, value.npcId)
		end
		if questOffer ~= nil then questOffer.Visible = false end
		if dialogue ~= nil then dialogue.Visible = false end
	end))
	table.insert(connections, decline.Activated:Connect(function()
		if questOffer ~= nil then questOffer.Visible = false end
		if dialogue ~= nil then dialogue.Visible = true end
	end))
end

local function showTravelConfirm(value: any, topic: any): ()
	if travelConfirm == nil then return end
	clearChildren(travelConfirm)
	travelConfirm.Visible = true
	if dialogue ~= nil then dialogue.Visible = false end

	local close = HudLayout.makeCloseButton(travelConfirm, 18)
	table.insert(connections, close.Activated:Connect(function()
		if travelConfirm ~= nil then travelConfirm.Visible = false end
		if dialogue ~= nil then dialogue.Visible = true end
	end))

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 34)
	padding.PaddingBottom = UDim.new(0, 24)
	padding.PaddingLeft = UDim.new(0, 28)
	padding.PaddingRight = UDim.new(0, 28)
	padding.Parent = travelConfirm

	local destinationName = topic.destinationName or "неизвестную локацию"
	local cost = topic.costLuna or 0
	local title = makeText(travelConfirm, "ПОДТВЕРЖДЕНИЕ ТЕЛЕПОРТА", 18)
	title.Position = UDim2.fromOffset(0, 2)
	title.Size = UDim2.new(1, 0, 0, 32)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Font = Enum.Font.GothamBold
	title.ZIndex = 22

	local message = makeText(
		travelConfirm,
		string.format("Вы действительно желаете переместиться в %s за %d Luna?", destinationName, cost),
		15
	)
	message.Position = UDim2.fromOffset(0, 56)
	message.Size = UDim2.new(1, 0, 0, 84)
	message.TextXAlignment = Enum.TextXAlignment.Center
	message.TextYAlignment = Enum.TextYAlignment.Center
	message.ZIndex = 22

	local confirm = makeButton(travelConfirm, "Переместиться")
	confirm.Position = UDim2.new(0, 0, 1, -48)
	confirm.Size = UDim2.new(0.48, 0, 0, 40)
	confirm.ZIndex = 22

	local cancel = makeButton(travelConfirm, "Отмена")
	cancel.AnchorPoint = Vector2.new(1, 0)
	cancel.Position = UDim2.new(1, 0, 1, -48)
	cancel.Size = UDim2.new(0.48, 0, 0, 40)
	cancel.ZIndex = 22

	table.insert(connections, confirm.Activated:Connect(function()
		if travelConfirm ~= nil then travelConfirm.Visible = false end
		if dialogue ~= nil then dialogue.Visible = true end
		travelRequest:FireServer(topic.travelId, value.npcId)
	end))
	table.insert(connections, cancel.Activated:Connect(function()
		if travelConfirm ~= nil then travelConfirm.Visible = false end
		if dialogue ~= nil then dialogue.Visible = true end
	end))
end

local function openDialogue(value: any): ()
	if dialogue == nil then return end
	clearChildren(dialogue)
	dialogue.Visible = true
	if questOffer ~= nil then questOffer.Visible = false end
	if travelConfirm ~= nil then travelConfirm.Visible = false end

	local close = HudLayout.makeCloseButton(dialogue, 12)
	table.insert(connections, close.Activated:Connect(function()
		if dialogue ~= nil then dialogue.Visible = false end
	end))

	local content = Instance.new("Frame")
	content.Name = "DialogueContent"
	content.Position = UDim2.fromOffset(18, 16)
	content.Size = UDim2.new(1, -70, 1, -32)
	content.BackgroundTransparency = 1
	content.Parent = dialogue

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 9)
	layout.Parent = content

	local header = makeText(content, "ДИАЛОГ — " .. string.upper(value.displayName), 18)
	header.Size = UDim2.new(1, 0, 0, 42)
	header.Font = Enum.Font.GothamBold

	if typeof(value.message) == "string" and value.message ~= "" then
		local body = makeText(content, value.message, 14)
		body.Size = UDim2.new(1, 0, 0, 70)
		body.TextYAlignment = Enum.TextYAlignment.Top
	end

	local questTopic = nil
	for _, topic in value.topics or {} do
		if topic.kind == "AcceptQuest" or topic.kind == "TurnInQuest" then
			questTopic = topic
			break
		end
	end

	if questTopic ~= nil then
		local questButton = makeButton(content, "Квест")
		questButton.Size = UDim2.new(1, 0, 0, 46)
		table.insert(connections, questButton.Activated:Connect(function()
			showQuestOffer(value, questTopic)
		end))
	end

	for _, topic in value.topics or {} do
		if topic.kind ~= "Travel" then continue end
		local travelButton = makeButton(
			content,
			string.format("Телепорт: %s · %d Luna", topic.destinationName or "?", topic.costLuna or 0)
		)
		travelButton.Size = UDim2.new(1, 0, 0, 46)
		table.insert(connections, travelButton.Activated:Connect(function()
			showTravelConfirm(value, topic)
		end))
	end
end

local function rebuildMarkers(): ()
	for _, marker in markerGuis do marker:Destroy() end
	table.clear(markerGuis)

	for _, markerData in snapshot.markers or {} do
		local definition = NpcDefinitions[markerData.npcId]
		if definition == nil then continue end

		local model = workspace:FindFirstChild(definition.modelName, true)
		if model == nil or not model:IsA("Model") then continue end

		local adornee = model:FindFirstChild("Head") or model:FindFirstChild("Body") or model.PrimaryPart
		if adornee == nil or not adornee:IsA("BasePart") then continue end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "QuestMarker"
		billboard.Adornee = adornee
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 160
		billboard.Size = UDim2.fromOffset(48, 54)
		billboard.StudsOffset = Vector3.new(0, 5.6, 0)
		billboard.Parent = adornee

		local plate = Instance.new("Frame")
		plate.Size = UDim2.fromScale(1, 1)
		plate.BackgroundColor3 = Color3.fromRGB(24, 25, 29)
		plate.BackgroundTransparency = 0.42
		plate.BorderSizePixel = 0
		plate.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = plate

		local label = makeText(plate, markerData.symbol, 36)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextColor3 = if markerData.symbol == "?"
			then Color3.fromRGB(124, 232, 142)
			else Color3.fromRGB(255, 210, 70)
		label.TextStrokeColor3 = Color3.fromRGB(25, 20, 8)
		label.TextStrokeTransparency = 0.12
		label.ZIndex = 30

		table.insert(markerGuis, billboard)
	end
end

local function setSnapshot(value: any): ()
	if typeof(value) ~= "table" or typeof(value.quests) ~= "table" then return end
	firstSnapshotReceived = true
	snapshot = value
	syncActiveQuestState()
	buildJournal()
	rebuildMarkers()
end

local function ensureWaypointLabel(questId: string): TextLabel?
	if gui == nil then return nil end
	local existing = waypointLabels[questId]
	if existing ~= nil then return existing end

	local label = makeText(gui, "", 13)
	label.Name = "QuestWaypoint_" .. questId
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(82, 28)
	label.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
	label.BackgroundTransparency = 0.58
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextStrokeColor3 = Color3.fromRGB(10, 10, 10)
	label.TextStrokeTransparency = 0.5
	label.Visible = false
	label.ZIndex = 14

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = label

	waypointLabels[questId] = label
	return label
end

local function ensureMapQuestDot(questId: string): TextLabel?
	if mapCanvas == nil then return nil end
	local existing = mapQuestDots[questId]
	if existing ~= nil then return existing end

	local dot = makeText(mapCanvas, "◆", 16)
	dot.Name = "QuestTarget_" .. questId
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.fromOffset(24, 24)
	dot.TextXAlignment = Enum.TextXAlignment.Center
	dot.TextColor3 = Color3.fromRGB(255, 213, 76)
	dot.TextStrokeColor3 = Color3.fromRGB(30, 22, 4)
	dot.TextStrokeTransparency = 0.2
	dot.Visible = false
	dot.ZIndex = 13
	mapQuestDots[questId] = dot
	return dot
end

local function updateNavigation(): ()
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = workspace.CurrentCamera
	if root == nil or not root:IsA("BasePart") or camera == nil then
		for _, label in waypointLabels do label.Visible = false end
		return
	end

	if mapFrame ~= nil and mapFrame.Visible and playerDot ~= nil then
		playerDot.Position = mapPosition(root.Position)
		playerDot.Visible = true
	end
	if mapCanvas ~= nil and dungeonEntranceLabel == nil then
		dungeonEntranceLabel = makeText(mapCanvas, "◆ Ruins of Selene", 11)
		dungeonEntranceLabel.Name = "RuinsOfSeleneMapMarker"
		dungeonEntranceLabel.AnchorPoint = Vector2.new(0, 0.5)
		dungeonEntranceLabel.Position = mapPosition(WorldLayout.RuinsOfSeleneEntranceQuery)
		dungeonEntranceLabel.Size = UDim2.fromOffset(145, 20)
		dungeonEntranceLabel.TextColor3 = Color3.fromRGB(150, 174, 255)
		dungeonEntranceLabel.TextStrokeColor3 = Color3.fromRGB(12, 16, 24)
		dungeonEntranceLabel.TextStrokeTransparency = 0.35
		dungeonEntranceLabel.ZIndex = 13
	end
	if dungeonEntranceLabel ~= nil then
		dungeonEntranceLabel.Visible = mapFrame ~= nil and mapFrame.Visible
			and player:GetAttribute("RuinsOfSeleneUnlocked") == true
	end

	local visibleQuestIds: { [string]: boolean } = {}
	local activeIndex = 0

	for _, quest in snapshot.quests or {} do
		if activeQuestIds[quest.id] ~= true then continue end
		activeIndex += 1
		visibleQuestIds[quest.id] = true

		local target = activeTargetForQuest(quest)
		local waypoint = ensureWaypointLabel(quest.id)
		local mapDot = ensureMapQuestDot(quest.id)
		if target == nil then
			if waypoint ~= nil then waypoint.Visible = false end
			if mapDot ~= nil then mapDot.Visible = false end
			continue
		end

		local distanceStuds = (root.Position - target).Magnitude
		local closeEnough = distanceStuds < WAYPOINT_HIDE_DISTANCE

		if mapDot ~= nil then
			mapDot.Visible = mapFrame ~= nil and mapFrame.Visible and not closeEnough
			if mapDot.Visible then mapDot.Position = mapPosition(target) end
		end

		if waypoint == nil or closeEnough then
			if waypoint ~= nil then waypoint.Visible = false end
			continue
		end

		local meters = math.max(1, math.floor(distanceStuds / STUDS_PER_METER + 0.5))
		local screen, onScreen = camera:WorldToViewportPoint(target + Vector3.new(0, 6, 0))
		waypoint.Visible = true
		waypoint.Text = string.format("%d m", meters)

		if onScreen and screen.Z > 0 then
			waypoint.Position = UDim2.fromOffset(screen.X, screen.Y + (activeIndex - 1) * 30)
		else
			local center = camera.ViewportSize / 2
			local direction = Vector2.new(screen.X, screen.Y) - center
			if direction.Magnitude < 1 then direction = Vector2.new(0, -1) end
			direction = direction.Unit
			waypoint.Position = UDim2.fromOffset(
				center.X + direction.X * math.max(120, center.X - 150),
				center.Y + direction.Y * math.max(80, center.Y - 110) + (activeIndex - 1) * 28
			)
			waypoint.Text = "➤ " .. waypoint.Text
		end
	end

	for questId, label in waypointLabels do
		if visibleQuestIds[questId] ~= true then label.Visible = false end
	end
	for questId, dot in mapQuestDots do
		if visibleQuestIds[questId] ~= true then dot.Visible = false end
	end
end

function QuestController.toggleMap(): ()
	if mapFrame ~= nil then
		mapFrame.Visible = not mapFrame.Visible
		syncWorkspaceHud()
	end
end

function QuestController.toggleJournal(): ()
	if journal ~= nil then
		journal.Visible = not journal.Visible
		if journal.Visible then buildJournal() end
		syncWorkspaceHud()
	end
end

function QuestController.start(): ()
	QuestController.stop()

	local rootGui = Instance.new("ScreenGui")
	rootGui.Name = "QuestUi"
	rootGui.ResetOnSpawn = false
	rootGui.IgnoreGuiInset = false
	rootGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	rootGui.DisplayOrder = 8
	rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	rootGui.Parent = player:WaitForChild("PlayerGui")
	gui = rootGui
	local blocker = Instance.new("TextButton")
	blocker.Name = "ModalBlocker"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundColor3 = Color3.new(0, 0, 0)
	-- Keep modal behaviour without a fullscreen dark veil. Each dialog/panel is
	-- responsible for its own readable background.
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.Active = true
	blocker.Modal = true
	blocker.Visible = false
	blocker.ZIndex = 1
	blocker.Parent = rootGui
	modalBlocker = blocker

	local dialogueFrame = Instance.new("Frame")
	dialogueFrame.Name = "DialogueShell"
	dialogueFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	dialogueFrame.Position = UDim2.fromScale(0.5, 0.48)
	dialogueFrame.Size = UDim2.fromScale(0.42, 0.40)
	HudLayout.applyPanelStyle(dialogueFrame)
	dialogueFrame.BackgroundTransparency = 0.03
	dialogueFrame.Visible = false
	dialogueFrame.ZIndex = 10
	dialogueFrame.Parent = rootGui
	dialogue = dialogueFrame

	local offerFrame = Instance.new("Frame")
	offerFrame.Name = "QuestOffer"
	offerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	offerFrame.Position = UDim2.fromScale(0.5, 0.48)
	offerFrame.Size = UDim2.fromOffset(560, 360)
	HudLayout.applyPanelStyle(offerFrame)
	offerFrame.BackgroundTransparency = 0.03
	offerFrame.Visible = false
	offerFrame.ZIndex = 20
	offerFrame.Parent = rootGui
	questOffer = offerFrame

	local travelFrame = Instance.new("Frame")
	travelFrame.Name = "TravelConfirm"
	travelFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	travelFrame.Position = UDim2.fromScale(0.5, 0.48)
	travelFrame.Size = UDim2.fromOffset(520, 250)
	HudLayout.applyPanelStyle(travelFrame)
	travelFrame.BackgroundTransparency = 0.03
	travelFrame.Visible = false
	travelFrame.ZIndex = 24
	travelFrame.Parent = rootGui
	travelConfirm = travelFrame

	journal = buildJournalFrame(rootGui)
	mapFrame = buildMap(rootGui)
	stopObserving = ResponsiveLayout.observe(applyMobileLayout)
	local function syncModalBlocker(): ()
		if modalBlocker == nil then return end
		modalBlocker.Visible = (dialogue ~= nil and dialogue.Visible)
			or (questOffer ~= nil and questOffer.Visible)
			or (travelConfirm ~= nil and travelConfirm.Visible)
			or (journal ~= nil and journal.Visible)
			or (mapFrame ~= nil and mapFrame.Visible)
	end
	for _, modal in { dialogueFrame, offerFrame, travelFrame, journal :: Frame, mapFrame :: Frame } do
		table.insert(connections, modal:GetPropertyChangedSignal("Visible"):Connect(syncModalBlocker))
	end
	syncModalBlocker()

	table.insert(connections, snapshotEvent.OnClientEvent:Connect(setSnapshot))
	table.insert(connections, dialogueEvent.OnClientEvent:Connect(openDialogue))
	table.insert(connections, travelResult.OnClientEvent:Connect(function(result)
		if typeof(result) ~= "table" then return end
		if result.ok == true then
			if dialogue ~= nil then dialogue.Visible = false end
			if travelConfirm ~= nil then travelConfirm.Visible = false end
			return
		end
		if dialogue == nil or not dialogue.Visible then return end
		local content = dialogue:FindFirstChild("DialogueContent")
		if content == nil then return end
		local status = content:FindFirstChild("TravelStatus")
		if status == nil then
			status = makeText(content, "", 13)
			status.Name = "TravelStatus"
			status.Size = UDim2.new(1, 0, 0, 30)
			status.TextColor3 = Color3.fromRGB(235, 150, 130)
		end
		local messages = {
			InsufficientLuna = "Недостаточно Luna для телепорта.",
			Locked = "Этот маршрут ещё не открыт.",
			TooFar = "Подойдите ближе к NPC.",
			DestinationUnavailable = "Точка назначения сейчас недоступна.",
			TeleportFailed = "Телепорт не сработал. Luna возвращена.",
		}
		status.Text = messages[result.reason] or "Телепорт сейчас недоступен."
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if UserInputService:GetFocusedTextBox() ~= nil then return end
		-- Y is kept away from Roblox camera controls; treat it as a dedicated UI hotkey.
		if input.KeyCode == Enum.KeyCode.Y then
			QuestController.toggleJournal()
			return
		end
		if processed then return end
		if input.KeyCode == Enum.KeyCode.M then QuestController.toggleMap() end
	end))
	table.insert(connections, workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then task.defer(rebuildMarkers) end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(updateNavigation))


	task.delay(0.8, rebuildMarkers)
	firstSnapshotReceived = false
	snapshotRequest:FireServer()
	for _, delaySeconds in { 0.35, 0.9, 1.8, 3.0 } do
		task.delay(delaySeconds, function()
			if gui ~= nil and not firstSnapshotReceived then
				snapshotRequest:FireServer()
			end
		end)
	end
end

function QuestController.stop(): ()
	if stopObserving ~= nil then stopObserving(); stopObserving = nil end
	if gui ~= nil then MobileOverlayCoordinator.release(gui) end
	firstSnapshotReceived = false
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)

	for _, marker in markerGuis do marker:Destroy() end
	table.clear(markerGuis)

	for _, label in waypointLabels do label:Destroy() end
	table.clear(waypointLabels)
	table.clear(mapQuestDots)
	dungeonEntranceLabel = nil

	if gui ~= nil then gui:Destroy() end
	gui = nil
	dialogue = nil
	questOffer = nil
	travelConfirm = nil
	journal = nil
	journalList = nil
	mapFrame = nil
	modalBlocker = nil
	mapCanvas = nil
	playerDot = nil
end

return QuestController
