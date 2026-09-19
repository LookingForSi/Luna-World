--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local GreyboxPrimitives = require(script.Parent.GreyboxPrimitives)

type PointOfInterestDefinition = typeof(WorldLayout.PointsOfInterest[1])
type SpawnMarkerDefinition = typeof(WorldLayout.SpawnMarkers[1])

local MEADOWS_MODEL_NAME = "Meadows"
local GROUND_CONTAINER_NAME = "Ground"
local ROAD_CONTAINER_NAME = "Road"
local LANDMARK_CONTAINER_NAME = "Landmarks"
local SPAWN_CONTAINER_NAME = "SpawnMarkers"
local EXPECTED_SPAWN_MARKER_COUNT = 3
local SAFE_TRANSITION_END_ROUTE_INDEX = 3

local REQUIRED_POI_IDS = {
	farm = "poi_moonfall_farm",
	bridge = "poi_meadow_bridge",
	stoneCircle = "poi_stone_circle",
	exit = "exit_moonfall_road",
}

local GROUND = {
	width = 440,
	thickness = 8,
}

local ROAD = {
	width = 20,
	thickness = 1,
}

local STREAM = {
	length = 250,
	width = 24,
	thickness = 0.4,
	transparency = 0.25,
}

local BRIDGE = {
	length = 34,
	width = 22,
	thickness = 2,
	elevation = 1.5,
}

local FARM = {
	farmhouseOffset = Vector3.new(-30, 0, -24),
	farmhouseSize = Vector3.new(34, 18, 26),
	barnOffset = Vector3.new(30, 0, -16),
	barnSize = Vector3.new(40, 22, 30),
	penCenterOffset = Vector3.new(2, 0, 30),
	penSize = Vector2.new(58, 42),
	fenceHeight = 5,
	fenceThickness = 1.5,
	wellOffset = Vector3.new(-42, 0, 24),
	wellSize = Vector3.new(10, 5, 10),
	sheepOffsets = {
		Vector3.new(-15, 0, 24),
		Vector3.new(0, 0, 34),
		Vector3.new(16, 0, 27),
	},
	npcOffsets = {
		Vector3.new(-18, 0, -8),
		Vector3.new(20, 0, 0),
		Vector3.new(-34, 0, 16),
	},
}

local STONE_CIRCLE = {
	stoneCount = 6,
	radius = 22,
	stoneSize = Vector3.new(5, 15, 6),
}

local SPIDER_POCKET = {
	treeOffsets = {
		Vector3.new(-30, 0, -18),
		Vector3.new(-8, 0, 24),
		Vector3.new(26, 0, 18),
		Vector3.new(34, 0, -20),
	},
	rockOffsets = {
		Vector3.new(-20, 0, 8),
		Vector3.new(17, 0, -9),
		Vector3.new(4, 0, 30),
	},
}

local COLORS = {
	ground = Color3.fromRGB(105, 126, 74),
	road = Color3.fromRGB(126, 108, 82),
	water = Color3.fromRGB(71, 132, 154),
	timber = Color3.fromRGB(103, 72, 47),
	roof = Color3.fromRGB(76, 63, 58),
	stone = Color3.fromRGB(92, 96, 91),
	darkStone = Color3.fromRGB(57, 61, 60),
	darkWood = Color3.fromRGB(55, 48, 40),
	sheep = Color3.fromRGB(218, 216, 199),
	npcMarker = Color3.fromRGB(94, 171, 207),
}

local LunaMeadowsGreybox = {}

local function createModel(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	return model
end

local function createFolder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	return folder
end

local function createColoredBlock(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3
): BasePart
	local block = GreyboxPrimitives.createBlock(parent, name, size, cframe, material, {})
	block.Color = color

	return block
end

local function createGroundedBlock(
	parent: Instance,
	name: string,
	groundPosition: Vector3,
	size: Vector3,
	material: Enum.Material,
	color: Color3
): BasePart
	return createColoredBlock(
		parent,
		name,
		size,
		CFrame.new(groundPosition + Vector3.new(0, size.Y / 2, 0)),
		material,
		color
	)
end

local function getPointOfInterest(stableId: string): PointOfInterestDefinition
	for _, definition in ipairs(WorldLayout.PointsOfInterest) do
		if definition.id == stableId then
			return definition
		end
	end

	error(string.format("Luna Meadows requires WorldLayout POI '%s'", stableId))
end

local function getSpiderSpawnDefinition(): SpawnMarkerDefinition
	for _, definition in ipairs(WorldLayout.SpawnMarkers) do
		if definition.zoneId == "zone_luna_meadows" and string.find(definition.mobId, "spider", 1, true) ~= nil then
			return definition
		end
	end

	error("Luna Meadows requires a spider spawn definition in WorldLayout.SpawnMarkers")
end

local function createMeadowGround(parent: Instance)
	local ground = createFolder(parent, GROUND_CONTAINER_NAME)
	local verticalOffset = Vector3.new(0, -GROUND.thickness / 2, 0)

	for index = 1, #WorldLayout.Route - 1 do
		local section = GreyboxPrimitives.createSegment(
			ground,
			string.format("MeadowGround%02d", index),
			WorldLayout.Route[index] + verticalOffset,
			WorldLayout.Route[index + 1] + verticalOffset,
			GROUND.width,
			GROUND.thickness
		)
		section.Material = Enum.Material.Grass
		section.Color = COLORS.ground
	end
end

local function createRoad(parent: Instance)
	local road = createFolder(parent, ROAD_CONTAINER_NAME)
	local verticalOffset = Vector3.new(0, ROAD.thickness / 2, 0)

	for index = 1, #WorldLayout.Route - 1 do
		local section = GreyboxPrimitives.createSegment(
			road,
			string.format("RoadSegment%02d", index),
			WorldLayout.Route[index] + verticalOffset,
			WorldLayout.Route[index + 1] + verticalOffset,
			ROAD.width,
			ROAD.thickness
		)
		section.Material = Enum.Material.Ground
		section.Color = COLORS.road
	end
end

local function findClosestRouteIndex(position: Vector3): number
	local closestIndex = 1
	local closestDistance = math.huge

	for index, routePosition in ipairs(WorldLayout.Route) do
		local offset = Vector3.new(routePosition.X - position.X, 0, routePosition.Z - position.Z)
		if offset.Magnitude < closestDistance then
			closestIndex = index
			closestDistance = offset.Magnitude
		end
	end

	return closestIndex
end

local function getRouteDirection(position: Vector3): Vector3
	local closestIndex = findClosestRouteIndex(position)
	local previousIndex = math.max(1, closestIndex - 1)
	local nextIndex = math.min(#WorldLayout.Route, closestIndex + 1)
	local offset = WorldLayout.Route[nextIndex] - WorldLayout.Route[previousIndex]
	local horizontalOffset = Vector3.new(offset.X, 0, offset.Z)
	assert(horizontalOffset.Magnitude > 0, "WorldLayout route direction must have non-zero XZ length")

	return horizontalOffset.Unit
end

local function createStreamAndBridge(parent: Instance, definition: PointOfInterestDefinition)
	local landmark = createModel(parent, "MeadowBridge")
	local routeDirection = getRouteDirection(definition.position)
	local streamDirection = Vector3.new(-routeDirection.Z, 0, routeDirection.X)
	local streamCenter = definition.position - Vector3.new(0, STREAM.thickness / 2, 0)

	local stream = GreyboxPrimitives.createSegment(
		landmark,
		"ShallowStream",
		streamCenter - streamDirection * STREAM.length / 2,
		streamCenter + streamDirection * STREAM.length / 2,
		STREAM.width,
		STREAM.thickness
	)
	stream.Material = Enum.Material.Glass
	stream.Color = COLORS.water
	stream.Transparency = STREAM.transparency
	stream.CanCollide = false

	local bridgeCenter = definition.position + Vector3.new(0, BRIDGE.elevation, 0)
	local bridge = GreyboxPrimitives.createSegment(
		landmark,
		"BridgeDeck",
		bridgeCenter - routeDirection * BRIDGE.length / 2,
		bridgeCenter + routeDirection * BRIDGE.length / 2,
		BRIDGE.width,
		BRIDGE.thickness
	)
	bridge.Material = Enum.Material.WoodPlanks
	bridge.Color = COLORS.timber
	bridge:SetAttribute("StableId", definition.id)
	GreyboxPrimitives.createLabel(bridge, definition.id)
end

local function createFarmFence(parent: Instance, center: Vector3)
	local halfWidth = FARM.penSize.X / 2
	local halfDepth = FARM.penSize.Y / 2
	local elevation = FARM.fenceHeight / 2

	local fenceSections = {
		{
			name = "PenFenceNorth",
			from = center + Vector3.new(-halfWidth, elevation, -halfDepth),
			to = center + Vector3.new(halfWidth, elevation, -halfDepth),
		},
		{
			name = "PenFenceSouth",
			from = center + Vector3.new(-halfWidth, elevation, halfDepth),
			to = center + Vector3.new(halfWidth, elevation, halfDepth),
		},
		{
			name = "PenFenceWest",
			from = center + Vector3.new(-halfWidth, elevation, -halfDepth),
			to = center + Vector3.new(-halfWidth, elevation, halfDepth),
		},
		{
			name = "PenFenceEast",
			from = center + Vector3.new(halfWidth, elevation, -halfDepth),
			to = center + Vector3.new(halfWidth, elevation, halfDepth),
		},
	}

	for _, section in ipairs(fenceSections) do
		local fence = GreyboxPrimitives.createSegment(
			parent,
			section.name,
			section.from,
			section.to,
			FARM.fenceThickness,
			FARM.fenceHeight
		)
		fence.Material = Enum.Material.Wood
		fence.Color = COLORS.timber
	end
end

local function createSheepPlaceholders(parent: Instance, farmPosition: Vector3)
	local sheep = createFolder(parent, "SheepPlaceholders")

	for index, offset in ipairs(FARM.sheepOffsets) do
		local placeholder = createGroundedBlock(
			sheep,
			string.format("SheepPlaceholder%02d", index),
			farmPosition + offset,
			Vector3.new(6, 4, 9),
			Enum.Material.SmoothPlastic,
			COLORS.sheep
		)
		placeholder:SetAttribute("Decorative", true)
	end
end

local function createFutureNpcMarkers(parent: Instance, farmPosition: Vector3)
	local markers = createFolder(parent, "FutureNpcMarkers")

	for index, offset in ipairs(FARM.npcOffsets) do
		local marker = createGroundedBlock(
			markers,
			string.format("FutureNpcMarker%02d", index),
			farmPosition + offset,
			Vector3.new(3, 6, 3),
			Enum.Material.Neon,
			COLORS.npcMarker
		)
		marker.CanCollide = false
		marker:SetAttribute("Purpose", "FutureNPC")
		GreyboxPrimitives.createLabel(marker, "Future NPC")
	end
end

local function createFarm(parent: Instance, definition: PointOfInterestDefinition)
	local farm = createModel(parent, "Farm")
	farm:SetAttribute("StableId", definition.id)

	createGroundedBlock(
		farm,
		"Farmhouse",
		definition.position + FARM.farmhouseOffset,
		FARM.farmhouseSize,
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
	createGroundedBlock(
		farm,
		"FarmhouseRoofBlockout",
		definition.position + FARM.farmhouseOffset + Vector3.new(0, FARM.farmhouseSize.Y, 0),
		Vector3.new(FARM.farmhouseSize.X + 4, 4, FARM.farmhouseSize.Z + 4),
		Enum.Material.Slate,
		COLORS.roof
	)
	createGroundedBlock(
		farm,
		"Barn",
		definition.position + FARM.barnOffset,
		FARM.barnSize,
		Enum.Material.WoodPlanks,
		COLORS.timber
	)

	local pen = createModel(farm, "FencedPen")
	createFarmFence(pen, definition.position + FARM.penCenterOffset)

	createGroundedBlock(
		farm,
		"Well",
		definition.position + FARM.wellOffset,
		FARM.wellSize,
		Enum.Material.Cobblestone,
		COLORS.stone
	)

	createSheepPlaceholders(farm, definition.position)
	createFutureNpcMarkers(farm, definition.position)
end

local function createStoneCircle(parent: Instance, definition: PointOfInterestDefinition)
	local stoneCircle = createModel(parent, "StoneCircle")
	stoneCircle:SetAttribute("StableId", definition.id)

	for index = 1, STONE_CIRCLE.stoneCount do
		local angle = (index - 1) * math.pi * 2 / STONE_CIRCLE.stoneCount
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * STONE_CIRCLE.radius
		local stone = createGroundedBlock(
			stoneCircle,
			string.format("StandingStone%02d", index),
			definition.position + offset,
			STONE_CIRCLE.stoneSize,
			Enum.Material.Slate,
			COLORS.stone
		)
		stone.CFrame *= CFrame.Angles(0, -angle, 0)
	end
end

local function createSpiderPocket(parent: Instance, definition: SpawnMarkerDefinition)
	local pocket = createModel(parent, "SpiderPocket")
	pocket:SetAttribute("Purpose", "SpiderHabitatBlockout")

	for index, offset in ipairs(SPIDER_POCKET.treeOffsets) do
		createGroundedBlock(
			pocket,
			string.format("DarkTreeBlockout%02d", index),
			definition.position + offset,
			Vector3.new(7, 24, 7),
			Enum.Material.Wood,
			COLORS.darkWood
		)
	end

	for index, offset in ipairs(SPIDER_POCKET.rockOffsets) do
		createGroundedBlock(
			pocket,
			string.format("DarkRockBlockout%02d", index),
			definition.position + offset,
			Vector3.new(10, 7, 9),
			Enum.Material.Slate,
			COLORS.darkStone
		)
	end
end

local function createSpawnMarkers(parent: Instance): string
	local markers = createFolder(parent, SPAWN_CONTAINER_NAME)
	local safeTransitionEnd = WorldLayout.Route[SAFE_TRANSITION_END_ROUTE_INDEX]
	local meadowsSpawnCount = 0
	assert(safeTransitionEnd ~= nil, "WorldLayout route must define the calm transition after the gate")

	for _, definition in ipairs(WorldLayout.SpawnMarkers) do
		if definition.zoneId == "zone_luna_meadows" then
			meadowsSpawnCount += 1
			assert(
				definition.position.Z >= safeTransitionEnd.Z,
				string.format("Spawn marker '%s' must remain beyond the calm gate transition", definition.id)
			)

			GreyboxPrimitives.createMarker(markers, definition.id, definition.position, {
				StableId = definition.id,
				MobId = definition.mobId,
				Radius = definition.radius,
				ZoneId = definition.zoneId,
			})
		end
	end

	assert(
		meadowsSpawnCount == EXPECTED_SPAWN_MARKER_COUNT,
		string.format(
			"Luna Meadows requires exactly %d spawn definitions, got %d",
			EXPECTED_SPAWN_MARKER_COUNT,
			meadowsSpawnCount
		)
	)
	return "zone_luna_meadows"
end

local function createExitMarker(parent: Instance, definition: PointOfInterestDefinition)
	GreyboxPrimitives.createMarker(parent, definition.id, definition.position, {
		StableId = definition.id,
		Destination = "zone_moonfall_road",
	})
end

function LunaMeadowsGreybox.build(parent: Instance): Model
	local farmDefinition = getPointOfInterest(REQUIRED_POI_IDS.farm)
	local bridgeDefinition = getPointOfInterest(REQUIRED_POI_IDS.bridge)
	local stoneCircleDefinition = getPointOfInterest(REQUIRED_POI_IDS.stoneCircle)
	local exitDefinition = getPointOfInterest(REQUIRED_POI_IDS.exit)
	local spiderDefinition = getSpiderSpawnDefinition()

	local meadows = createModel(parent, MEADOWS_MODEL_NAME)
	createMeadowGround(meadows)
	createRoad(meadows)

	local landmarks = createFolder(meadows, LANDMARK_CONTAINER_NAME)
	createStreamAndBridge(landmarks, bridgeDefinition)
	createFarm(landmarks, farmDefinition)
	createStoneCircle(landmarks, stoneCircleDefinition)
	createSpiderPocket(landmarks, spiderDefinition)
	createExitMarker(landmarks, exitDefinition)

	local zoneId = createSpawnMarkers(meadows)
	meadows:SetAttribute("ZoneId", zoneId)

	return meadows
end

return table.freeze(LunaMeadowsGreybox)
