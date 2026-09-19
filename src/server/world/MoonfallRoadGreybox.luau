--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local GreyboxPrimitives = require(script.Parent.GreyboxPrimitives)

type PointOfInterestDefinition = typeof(WorldLayout.PointsOfInterest[1])
type SpawnMarkerDefinition = typeof(WorldLayout.SpawnMarkers[1])

local MODEL_NAME = "MoonfallRoad"
local GROUND_WIDTH = 360
local GROUND_THICKNESS = 8
local ROAD_WIDTH = 18
local ROAD_THICKNESS = 1

local COLORS = {
	ground = Color3.fromRGB(89, 105, 72),
	road = Color3.fromRGB(112, 100, 83),
	stone = Color3.fromRGB(77, 82, 80),
	darkStone = Color3.fromRGB(57, 61, 60),
	timber = Color3.fromRGB(91, 65, 45),
	darkWood = Color3.fromRGB(48, 45, 39),
	wagon = Color3.fromRGB(103, 72, 47),
}

local REQUIRED_POI_IDS = {
	brokenWagon = "poi_broken_wagon",
	crossroads = "poi_moonfall_crossroads",
	waystone = "poi_old_waystone",
	darkGate = "poi_dark_woodland_gate",
	darkEntry = "entry_dark_woodland",
}

local MoonfallRoadGreybox = {}

local function createModel(parent: Instance, name: string, stableId: string?): Model
	local model = Instance.new("Model")
	model.Name = name
	if stableId ~= nil then
		model:SetAttribute("StableId", stableId)
	end
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
	position: Vector3,
	size: Vector3,
	material: Enum.Material,
	color: Color3
): BasePart
	return createColoredBlock(
		parent,
		name,
		size,
		CFrame.new(position + Vector3.new(0, size.Y / 2, 0)),
		material,
		color
	)
end

local function getPoi(stableId: string): PointOfInterestDefinition
	for _, definition in ipairs(WorldLayout.PointsOfInterest) do
		if definition.id == stableId then
			return definition
		end
	end
	error(string.format("Moonfall Road requires WorldLayout POI '%s'", stableId))
end

local function getSpawn(stableId: string): SpawnMarkerDefinition
	for _, definition in ipairs(WorldLayout.SpawnMarkers) do
		if definition.id == stableId then
			return definition
		end
	end
	error(string.format("Moonfall Road requires WorldLayout spawn '%s'", stableId))
end

local function createRouteGeometry(parent: Instance)
	local ground = createFolder(parent, "Ground")
	local road = createFolder(parent, "Road")
	local groundOffset = Vector3.new(0, -GROUND_THICKNESS / 2, 0)
	local roadOffset = Vector3.new(0, ROAD_THICKNESS / 2, 0)

	for index = 1, #WorldLayout.MoonfallRoadRoute - 1 do
		local from = WorldLayout.MoonfallRoadRoute[index]
		local to = WorldLayout.MoonfallRoadRoute[index + 1]

		local groundSection = GreyboxPrimitives.createSegment(
			ground,
			string.format("MoonfallGround%02d", index),
			from + groundOffset,
			to + groundOffset,
			GROUND_WIDTH,
			GROUND_THICKNESS
		)
		groundSection.Material = Enum.Material.Grass
		groundSection.Color = COLORS.ground

		local roadSection = GreyboxPrimitives.createSegment(
			road,
			string.format("MoonfallRoad%02d", index),
			from + roadOffset,
			to + roadOffset,
			ROAD_WIDTH,
			ROAD_THICKNESS
		)
		roadSection.Material = Enum.Material.Ground
		roadSection.Color = COLORS.road
	end
end

local function createBrokenWagon(parent: Instance, definition: PointOfInterestDefinition)
	local wagon = createModel(parent, "BrokenWagon", definition.id)
	local body = createGroundedBlock(
		wagon,
		"WagonBed",
		definition.position,
		Vector3.new(18, 4, 10),
		Enum.Material.WoodPlanks,
		COLORS.wagon
	)
	body.CFrame *= CFrame.Angles(0, math.rad(24), math.rad(6))

	for index, offset in ipairs({
		Vector3.new(-7, 2, -6),
		Vector3.new(7, 2, 6),
	}) do
		local wheel = createColoredBlock(
			wagon,
			string.format("BrokenWheel%02d", index),
			Vector3.new(1.8, 9, 9),
			CFrame.new(definition.position + offset) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Wood,
			COLORS.timber
		)
		wheel.Shape = Enum.PartType.Cylinder
	end

	createGroundedBlock(
		wagon,
		"BrokenAxle",
		definition.position + Vector3.new(10, 0, -5),
		Vector3.new(16, 2, 2),
		Enum.Material.Wood,
		COLORS.timber
	)
end

local function createWaystone(parent: Instance, definition: PointOfInterestDefinition)
	local waystone = createModel(parent, "OldWaystone", definition.id)
	createGroundedBlock(
		waystone,
		"WaystoneBase",
		definition.position,
		Vector3.new(10, 4, 9),
		Enum.Material.Slate,
		COLORS.darkStone
	)
	local monolith = createGroundedBlock(
		waystone,
		"DamagedMonolith",
		definition.position + Vector3.new(0, 4, 0),
		Vector3.new(6, 18, 5),
		Enum.Material.Slate,
		COLORS.stone
	)
	monolith.CFrame *= CFrame.Angles(0, math.rad(-12), math.rad(5))
	GreyboxPrimitives.createLabel(monolith, definition.id)
end

local function createCrossroads(parent: Instance, definition: PointOfInterestDefinition)
	local crossroads = createModel(parent, "Crossroads", definition.id)
	createColoredBlock(
		crossroads,
		"CrossroadsClearing",
		Vector3.new(104, 1, 92),
		CFrame.new(definition.position - Vector3.new(0, 0.5, 0)),
		Enum.Material.Ground,
		COLORS.road
	)

	local wallSegments = {
		{
			from = definition.position + Vector3.new(-48, 2, -22),
			to = definition.position + Vector3.new(-24, 2, -35),
		},
		{
			from = definition.position + Vector3.new(32, 2, -30),
			to = definition.position + Vector3.new(50, 2, -12),
		},
		{
			from = definition.position + Vector3.new(-50, 2, 28),
			to = definition.position + Vector3.new(-30, 2, 38),
		},
	}

	for index, segment in ipairs(wallSegments) do
		local wall = GreyboxPrimitives.createSegment(
			crossroads,
			string.format("OldWall%02d", index),
			segment.from,
			segment.to,
			3,
			4
		)
		wall.Material = Enum.Material.Cobblestone
		wall.Color = COLORS.stone
	end
end

local function createDarkWoodlandThreshold(
	parent: Instance,
	gateDefinition: PointOfInterestDefinition,
	entryDefinition: PointOfInterestDefinition
)
	local threshold = createModel(parent, "DarkWoodlandThreshold", gateDefinition.id)
	local gatePosition = gateDefinition.position

	for index, offset in ipairs({
		Vector3.new(-52, 0, -12),
		Vector3.new(-34, 0, 20),
		Vector3.new(-58, 0, 58),
		Vector3.new(52, 0, -6),
		Vector3.new(38, 0, 28),
		Vector3.new(62, 0, 64),
	}) do
		createGroundedBlock(
			threshold,
			string.format("DarkTreeSilhouette%02d", index),
			gatePosition + offset,
			Vector3.new(10, 38 + (index % 3) * 7, 10),
			Enum.Material.Wood,
			COLORS.darkWood
		)
	end

	for index, offset in ipairs({
		Vector3.new(-20, 0, 0),
		Vector3.new(20, 0, 0),
	}) do
		local stone = createGroundedBlock(
			threshold,
			string.format("BoundaryStone%02d", index),
			gatePosition + offset,
			Vector3.new(7, 17, 7),
			Enum.Material.Slate,
			COLORS.darkStone
		)
		stone.CFrame *= CFrame.Angles(0, math.rad(if index == 1 then -8 else 11), math.rad(if index == 1 then -3 else 4))
	end

	local entry = GreyboxPrimitives.createMarker(threshold, entryDefinition.id, entryDefinition.position, {
		StableId = entryDefinition.id,
		Destination = "zone_dark_woodland",
		Purpose = "FutureZoneEntry",
	})
	GreyboxPrimitives.createLabel(entry, "Dark Woodland")
end

local function createRoadSpawnMarker(parent: Instance)
	local definition = getSpawn("spawn_goblin_scout_road")
	GreyboxPrimitives.createMarker(parent, definition.id, definition.position, {
		StableId = definition.id,
		MobId = definition.mobId,
		Radius = definition.radius,
		ZoneId = definition.zoneId,
	})
end

function MoonfallRoadGreybox.build(parent: Instance): Model
	local road = createModel(parent, MODEL_NAME, nil)
	road:SetAttribute("ZoneId", "zone_moonfall_road")

	createRouteGeometry(road)

	local landmarks = createFolder(road, "Landmarks")
	local brokenWagon = getPoi(REQUIRED_POI_IDS.brokenWagon)
	local crossroads = getPoi(REQUIRED_POI_IDS.crossroads)
	local waystone = getPoi(REQUIRED_POI_IDS.waystone)
	local darkGate = getPoi(REQUIRED_POI_IDS.darkGate)
	local darkEntry = getPoi(REQUIRED_POI_IDS.darkEntry)

	createBrokenWagon(landmarks, brokenWagon)
	createCrossroads(landmarks, crossroads)
	createWaystone(landmarks, waystone)
	createDarkWoodlandThreshold(landmarks, darkGate, darkEntry)

	local spawnMarkers = createFolder(road, "SpawnMarkers")
	createRoadSpawnMarker(spawnMarkers)

	return road
end

return table.freeze(MoonfallRoadGreybox)
