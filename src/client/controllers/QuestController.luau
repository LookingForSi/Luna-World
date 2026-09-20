--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local NpcDefinitions = require(ReplicatedStorage.Shared.definitions.NpcDefinitions)

local QuestController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local acceptRemote = remotes:WaitForChild("QuestAcceptRequest") :: RemoteEvent
local turnInRemote = remotes:WaitForChild("QuestTurnInRequest") :: RemoteEvent
local snapshotRequest = remotes:WaitForChild("QuestSnapshotRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("QuestSnapshot") :: RemoteEvent
local dialogueEvent = remotes:WaitForChild("DialogueOpen") :: RemoteEvent

local gui: ScreenGui? = nil
local tracker: Frame? = nil
local dialogue: Frame? = nil
local mapFrame: Frame? = nil
local mapCanvas: Frame? = nil
local waypoint: TextLabel? = nil
local playerDot: TextLabel? = nil
local questDot: TextLabel? = nil

local snapshot: any = { quests = {}, markers = {} }
local connections: { RBXScriptConnection } = {}
local markerGuis: { BillboardGui } = {}

local MAP_POIS = {
	{ id = "poi_main_gate", label = "Luna Village" },
	{ id = "poi_moonfall_farm", label = "Farm" },
	{ id = "poi_stone_circle", label = "Stone Circle" },
	{ id = "poi_moonfall_crossroads", label = "Moonfall" },
	{ id = "poi_goblin_camp", label = "Goblin Camp" },
	{ id = "poi_spider_hollow", label = "Spider Hollow" },
	{ id = "entry_dark_woodland", label = "Dark Woodland" },
	{ id = "poi_old_cemetery", label = "Cemetery" },
	{ id = "poi_fallen_shrine", label = "Fallen Shrine" },
	{ id = "poi_ancient_approach", label = "Ancient Approach" },
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

local function clearChildren(parent: Instance): ()
	for _, child in parent:GetChildren() do
		child:Destroy()
	end
end

local function normalizedMapPoint(position: Vector3): Vector2
	local bounds = WorldLayout.WorldBounds
	local x = (position.X - bounds.minX) / (bounds.maxX - bounds.minX)
	local z = (position.Z - bounds.minZ) / (bounds.maxZ - bounds.minZ)
	return Vector2.new(math.clamp(x, 0, 1), math.clamp(z, 0, 1))
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
			local alpha = step / steps
			addMapDot(parent, a:Lerp(b, alpha), dotSize, color, 0.22)
		end
	end
	if #points > 0 then
		addMapDot(parent, points[#points], dotSize, color, 0.22)
	end
end

local function addZoneBlocks(parent: Instance): ()
	for index, volume in WorldLayout.ZoneVolumes do
		local min = volume.center - volume.size / 2
		local max = volume.center + volume.size / 2
		local p1 = normalizedMapPoint(min)
		local p2 = normalizedMapPoint(max)

		local zone = Instance.new("Frame")
		zone.Position = UDim2.fromScale(0.04 + p1.X * 0.92, 0.04 + p1.Y * 0.92)
		zone.Size = UDim2.fromScale(
			math.max(0.02, (p2.X - p1.X) * 0.92),
			math.max(0.02, (p2.Y - p1.Y) * 0.92)
		)
		zone.BackgroundColor3 = if index % 2 == 0
			then Color3.fromRGB(74, 88, 64)
			else Color3.fromRGB(82, 72, 58)
		zone.BackgroundTransparency = 0.73
		zone.BorderSizePixel = 0
		zone.ZIndex = 1
		zone.Parent = parent

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(126, 132, 112)
		stroke.Transparency = 0.45
		stroke.Thickness = 1
		stroke.Parent = zone

		local zoneDefinition = nil
		for _, candidate in WorldLayout.Zones do
			if candidate.id == volume.zoneId then
				zoneDefinition = candidate
				break
			end
		end
		if zoneDefinition ~= nil then
			local label = makeText(zone, zoneDefinition.displayName, 10)
			label.Position = UDim2.fromOffset(5, 3)
			label.Size = UDim2.new(1, -10, 0, 18)
			label.TextTransparency = 0.18
		end
	end
end

local function addRiver(parent: Instance): ()
	local bridge = poi("poi_meadow_bridge")
	if bridge == nil then return end

	for x = -1240, 1240, 70 do
		local z = bridge.Z + 0.065 * (x - bridge.X) + 28 * math.sin((x + 180) / 280)
		addMapDot(parent, Vector3.new(x, 0, z), 9, Color3.fromRGB(67, 139, 173), 0.12)
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
		label.Size = UDim2.fromOffset(145, 20)
		label.TextColor3 = Color3.fromRGB(232, 222, 188)
		label.TextStrokeColor3 = Color3.fromRGB(12, 16, 18)
		label.TextStrokeTransparency = 0.45
		label.ZIndex = 3
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

	local hint = makeText(frame, "M — закрыть", 11)
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.new(1, -16, 0, 15)
	hint.Size = UDim2.fromOffset(90, 20)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextTransparency = 0.25
	hint.ZIndex = 22

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

	addZoneBlocks(canvas)
	addRiver(canvas)
	addRoutes(canvas)
	addPois(canvas)

	playerDot = makeText(canvas, "● ВЫ", 13)
	playerDot.Size = UDim2.fromOffset(65, 22)
	playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	playerDot.TextColor3 = Color3.fromRGB(104, 220, 255)
	playerDot.TextStrokeColor3 = Color3.fromRGB(8, 20, 26)
	playerDot.TextStrokeTransparency = 0.2
	playerDot.ZIndex = 8

	questDot = makeText(canvas, "◆ ЦЕЛЬ", 13)
	questDot.Size = UDim2.fromOffset(80, 22)
	questDot.AnchorPoint = Vector2.new(0.5, 0.5)
	questDot.TextColor3 = Color3.fromRGB(255, 213, 76)
	questDot.TextStrokeColor3 = Color3.fromRGB(30, 22, 4)
	questDot.TextStrokeTransparency = 0.2
	questDot.Visible = false
	questDot.ZIndex = 9

	return frame
end

local function rebuildTracker(): ()
	if tracker == nil then return end
	clearChildren(tracker)

	local quests = snapshot.quests or {}
	tracker.Visible = #quests > 0
	if #quests == 0 then return end

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.Parent = tracker

	for index, quest in quests do
		if index > 3 then break end

		local lines = { quest.displayName }
		for _, objective in quest.objectives do
			table.insert(
				lines,
				string.format("• %s  %d/%d", objective.displayText or objective.id, objective.progress, objective.required)
			)
		end
		if quest.state == "ReadyToTurnIn" then
			table.insert(lines, "Вернуться к NPC")
		end

		local label = makeText(tracker, table.concat(lines, "\n"), 13)
		label.Size = UDim2.new(1, -12, 0, 30 + #quest.objectives * 19)
		label.TextYAlignment = Enum.TextYAlignment.Top
	end
end

local function npcTargetPosition(npcId: string): Vector3?
	local definition = NpcDefinitions[npcId]
	if definition == nil then return nil end

	local existing = workspace:FindFirstChild(definition.modelName, true)
	if existing ~= nil and existing:IsA("Model") then
		return existing:GetPivot().Position
	end

	local base = poi(definition.poiId)
	return if base ~= nil then base + (definition.positionOffset or Vector3.zero) else nil
end

local function trackedTarget(): (Vector3?, string?)
	local quests = snapshot.quests or {}
	local quest = quests[1]
	if quest == nil then return nil, nil end

	if quest.state == "ReadyToTurnIn" then
		return npcTargetPosition(quest.turnInNpcId), quest.displayName
	end

	for _, objective in quest.objectives do
		if objective.progress >= objective.required then continue end

		if objective.npcId ~= nil then
			return npcTargetPosition(objective.npcId), objective.displayText or quest.displayName
		end
		if objective.poiId ~= nil then
			return poi(objective.poiId), objective.displayText or quest.displayName
		end
		if objective.waypointPoiId ~= nil then
			return poi(objective.waypointPoiId), objective.displayText or quest.displayName
		end
	end
	return nil, nil
end

local function rebuildMarkers(): ()
	for _, marker in markerGuis do marker:Destroy() end
	table.clear(markerGuis)

	if gui == nil then return end

	for _, markerData in snapshot.markers or {} do
		local definition = NpcDefinitions[markerData.npcId]
		if definition == nil then continue end

		local model = workspace:FindFirstChild(definition.modelName, true)
		if model == nil or not model:IsA("Model") then continue end

		local adornee = model:FindFirstChild("Head") or model.PrimaryPart
		if adornee == nil or not adornee:IsA("BasePart") then continue end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "QuestMarker"
		billboard.Adornee = adornee
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 140
		billboard.Size = UDim2.fromOffset(52, 62)
		billboard.StudsOffset = Vector3.new(0, 4.5, 0)
		billboard.Parent = gui

		local label = makeText(billboard, markerData.symbol, 38)
		label.Size = UDim2.fromScale(1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextColor3 = if markerData.symbol == "?"
			then Color3.fromRGB(124, 232, 142)
			else Color3.fromRGB(255, 210, 70)
		label.TextStrokeColor3 = Color3.fromRGB(25, 20, 8)
		label.TextStrokeTransparency = 0.15
		label.ZIndex = 30

		table.insert(markerGuis, billboard)
	end
end

local function setSnapshot(value: any): ()
	if typeof(value) ~= "table" or typeof(value.quests) ~= "table" then return end
	snapshot = value
	rebuildTracker()
	rebuildMarkers()
end

local function openDialogue(value: any): ()
	if dialogue == nil then return end
	clearChildren(dialogue)
	dialogue.Visible = true

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = dialogue

	local header = makeText(dialogue, "ДИАЛОГ — " .. string.upper(value.displayName), 18)
	header.Size = UDim2.new(1, -16, 0, 42)
	header.Font = Enum.Font.GothamBold

	if typeof(value.message) == "string" and value.message ~= "" then
		local body = makeText(dialogue, value.message, 14)
		body.Size = UDim2.new(1, -16, 0, 92)
		body.TextYAlignment = Enum.TextYAlignment.Top
	end

	for _, topic in value.topics do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -16, 0, 45)
		button.BackgroundColor3 = Color3.fromRGB(48, 52, 61)
		button.TextColor3 = Color3.fromRGB(235, 220, 180)
		button.Font = Enum.Font.GothamBold
		button.TextSize = 14
		button.Text = topic.text
		button.Parent = dialogue

		table.insert(connections, button.Activated:Connect(function()
			if topic.kind == "AcceptQuest" then
				acceptRemote:FireServer(topic.questId, value.npcId)
			else
				turnInRemote:FireServer(topic.questId, value.npcId)
			end
		end))
	end

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(1, -16, 0, 36)
	close.Text = "Закрыть"
	close.Parent = dialogue
	table.insert(connections, close.Activated:Connect(function()
		if dialogue ~= nil then dialogue.Visible = false end
	end))
end

local function updateMapAndWaypoint(): ()
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	local camera = workspace.CurrentCamera
	if root == nil or not root:IsA("BasePart") or camera == nil then
		if waypoint ~= nil then waypoint.Visible = false end
		return
	end

	local target, targetName = trackedTarget()

	-- Player position is valuable even before the first quest exists.
	if mapFrame ~= nil and mapFrame.Visible and playerDot ~= nil then
		playerDot.Position = mapPosition(root.Position)
		playerDot.Visible = true

		if questDot ~= nil then
			if target ~= nil then
				questDot.Position = mapPosition(target)
				questDot.Visible = true
			else
				questDot.Visible = false
			end
		end
	end

	if waypoint == nil then return end
	if target == nil then
		waypoint.Visible = false
		return
	end

	local screen, onScreen = camera:WorldToViewportPoint(target + Vector3.new(0, 8, 0))
	local distance = math.floor((root.Position - target).Magnitude)
	waypoint.Visible = true
	waypoint.Text = string.format("◆ %s · %d studs", targetName or "Цель", distance)

	if onScreen and screen.Z > 0 then
		waypoint.Position = UDim2.fromOffset(screen.X, screen.Y)
		return
	end

	local center = camera.ViewportSize / 2
	local direction = Vector2.new(screen.X, screen.Y) - center
	if direction.Magnitude < 1 then direction = Vector2.new(0, -1) end
	direction = direction.Unit

	waypoint.Position = UDim2.fromOffset(
		center.X + direction.X * math.max(120, center.X - 150),
		center.Y + direction.Y * math.max(80, center.Y - 110)
	)
	waypoint.Text = "➤ " .. waypoint.Text
end

function QuestController.toggleMap(): ()
	if mapFrame ~= nil then
		mapFrame.Visible = not mapFrame.Visible
	end
end

function QuestController.start(): ()
	QuestController.stop()

	local rootGui = Instance.new("ScreenGui")
	rootGui.Name = "QuestUi"
	rootGui.ResetOnSpawn = false
	rootGui.IgnoreGuiInset = false
	rootGui.DisplayOrder = 8
	rootGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	rootGui.Parent = player:WaitForChild("PlayerGui")
	gui = rootGui

	local trackerFrame = Instance.new("Frame")
	trackerFrame.Name = "QuestTracker"
	trackerFrame.Position = UDim2.new(1, -305, 0, 220)
	trackerFrame.Size = UDim2.fromOffset(285, 220)
	trackerFrame.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
	trackerFrame.BackgroundTransparency = 0.22
	trackerFrame.BorderSizePixel = 0
	trackerFrame.Visible = false
	trackerFrame.Parent = rootGui
	tracker = trackerFrame

	local dialogueFrame = Instance.new("Frame")
	dialogueFrame.Name = "DialogueShell"
	dialogueFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	dialogueFrame.Position = UDim2.fromScale(0.5, 0.48)
	dialogueFrame.Size = UDim2.fromScale(0.42, 0.56)
	dialogueFrame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
	dialogueFrame.BackgroundTransparency = 0.08
	dialogueFrame.BorderSizePixel = 0
	dialogueFrame.Visible = false
	dialogueFrame.Parent = rootGui
	dialogue = dialogueFrame

	mapFrame = buildMap(rootGui)

	local waypointLabel = makeText(rootGui, "", 15)
	waypointLabel.Name = "QuestWaypoint"
	waypointLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	waypointLabel.Size = UDim2.fromOffset(290, 50)
	waypointLabel.BackgroundTransparency = 0.18
	waypointLabel.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
	waypointLabel.TextXAlignment = Enum.TextXAlignment.Center
	waypointLabel.TextStrokeColor3 = Color3.fromRGB(10, 10, 10)
	waypointLabel.TextStrokeTransparency = 0.4
	waypointLabel.Visible = false
	waypoint = waypointLabel

	table.insert(connections, snapshotEvent.OnClientEvent:Connect(setSnapshot))
	table.insert(connections, dialogueEvent.OnClientEvent:Connect(openDialogue))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.M then
			QuestController.toggleMap()
		end
	end))
	table.insert(connections, workspace.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Model") then
			task.defer(rebuildMarkers)
		end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(updateMapAndWaypoint))

	snapshotRequest:FireServer()
end

function QuestController.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections)

	for _, marker in markerGuis do marker:Destroy() end
	table.clear(markerGuis)

	if gui ~= nil then gui:Destroy() end
	gui = nil
	tracker = nil
	dialogue = nil
	mapFrame = nil
	mapCanvas = nil
	waypoint = nil
	playerDot = nil
	questDot = nil
end

return QuestController
