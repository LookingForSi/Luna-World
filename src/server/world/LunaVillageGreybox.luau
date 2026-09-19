--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local GreyboxPrimitives = require(script.Parent.GreyboxPrimitives)

type ModelAttributes = { [string]: string }

local VILLAGE_MODEL_NAME = "Village"
local POI_CONTAINER_NAME = "PointsOfInterest"
local TERRACE_CONTAINER_NAME = "Terraces"
local STRUCTURE_CONTAINER_NAME = "LocalStructures"

local TERRACE_BASE_ELEVATION = 0
local TERRACE_DEPTH_RATIOS = {
	lower = 0.35,
	middle = 0.34,
	upper = 0.28,
}

local BUILDING_HEIGHTS = {
	blacksmith = 18,
	elderHouse = 22,
	merchantStall = 11,
	residence = 16,
	shrine = 15,
	trainingGuardhouse = 14,
}

local COLORS = {
	stone = Color3.fromRGB(102, 104, 99),
	darkStone = Color3.fromRGB(74, 77, 75),
	timber = Color3.fromRGB(105, 75, 50),
	roof = Color3.fromRGB(76, 65, 63),
	ground = Color3.fromRGB(104, 118, 78),
	shrine = Color3.fromRGB(132, 132, 125),
}

local REQUIRED_VILLAGE_POI_IDS = {
	"poi_main_gate",
	"poi_training_ground",
	"poi_blacksmith",
	"poi_village_square",
	"poi_merchant",
	"poi_residential",
	"poi_elder_house",
	"poi_shrine",
}

local LunaVillageGreybox = {}

local function createModel(parent: Instance, name: string, attributes: ModelAttributes): Model
	local model = Instance.new("Model")
	model.Name = name
	for attributeName, value in pairs(attributes) do
		model:SetAttribute(attributeName, value)
	end
	model.Parent = parent

	return model
end

local function createPoi(parent: Instance, stableId: string, purpose: string): Model
	return createModel(parent, stableId, {
		StableId = stableId,
		Purpose = purpose,
	})
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
	local center = groundPosition + Vector3.new(0, size.Y / 2, 0)
	return createColoredBlock(parent, name, size, CFrame.new(center), material, color)
end

local function createPoiPositionLookup(): { [string]: Vector3 }
	local positions: { [string]: Vector3 } = {}
	for _, definition in ipairs(WorldLayout.PointsOfInterest) do
		positions[definition.id] = definition.position
	end

	for _, stableId in ipairs(REQUIRED_VILLAGE_POI_IDS) do
		assert(positions[stableId] ~= nil, string.format("Luna Village requires WorldLayout POI '%s'", stableId))
	end

	return positions
end

local function midpoint(first: Vector3, second: Vector3): Vector3
	return (first + second) / 2
end

local function createTerrace(
	parent: Instance,
	name: string,
	centerXZ: Vector3,
	surfaceElevation: number,
	sizeXZ: Vector2
): BasePart
	local thickness = surfaceElevation - TERRACE_BASE_ELEVATION
	assert(thickness > 0, "village terrace surface must be above its base elevation")
	local size = Vector3.new(sizeXZ.X, thickness, sizeXZ.Y)
	local centerY = TERRACE_BASE_ELEVATION + thickness / 2
	local center = Vector3.new(centerXZ.X, centerY, centerXZ.Z)
	return createColoredBlock(parent, name, size, CFrame.new(center), Enum.Material.Grass, COLORS.ground)
end

local function createTerraces(parent: Instance, positions: { [string]: Vector3 })
	local terraces = Instance.new("Folder")
	terraces.Name = TERRACE_CONTAINER_NAME
	terraces.Parent = parent

	local footprint = WorldLayout.Dimensions.VillageFootprint
	local lowerCenter = midpoint(positions.poi_training_ground, positions.poi_blacksmith)
	local middleCenter = positions.poi_village_square
	local upperCenter = midpoint(positions.poi_elder_house, positions.poi_shrine)

	createTerrace(
		terraces,
		"LowerTerrace",
		lowerCenter,
		math.min(positions.poi_training_ground.Y, positions.poi_blacksmith.Y),
		Vector2.new(footprint.X, footprint.Y * TERRACE_DEPTH_RATIOS.lower)
	)
	createTerrace(
		terraces,
		"MiddleTerrace",
		middleCenter,
		positions.poi_village_square.Y,
		Vector2.new(footprint.X, footprint.Y * TERRACE_DEPTH_RATIOS.middle)
	)
	createTerrace(
		terraces,
		"UpperTerrace",
		upperCenter,
		math.min(positions.poi_elder_house.Y, positions.poi_shrine.Y),
		Vector2.new(footprint.X * 0.78, footprint.Y * TERRACE_DEPTH_RATIOS.upper)
	)
end

local function createVillagePaths(parent: Instance, positions: { [string]: Vector3 })
	local paths = Instance.new("Folder")
	paths.Name = "WalkablePaths"
	paths.Parent = parent

	local upperCenter = midpoint(positions.poi_elder_house, positions.poi_shrine)
	local sections = {
		{
			name = "GateToSquareRamp",
			from = positions.poi_main_gate + Vector3.new(0, 1, -4),
			to = positions.poi_village_square + Vector3.new(0, 1, 18),
			width = 22,
		},
		{
			name = "SquareToUpperRamp",
			from = positions.poi_village_square + Vector3.new(0, 1, -20),
			to = upperCenter + Vector3.new(0, 1, 18),
			width = 20,
		},
	}

	for _, section in ipairs(sections) do
		local ramp = GreyboxPrimitives.createSegment(
			paths,
			section.name,
			section.from,
			section.to,
			section.width,
			2
		)
		ramp.Material = Enum.Material.Cobblestone
		ramp.Color = COLORS.stone
	end
end

local function createHouseVolume(parent: Instance, name: string, position: Vector3, size: Vector3)
	createGroundedBlock(parent, name, position, size, Enum.Material.WoodPlanks, COLORS.timber)
end

local function createMainGate(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_main_gate", "MainGateAndGuardPoint")

	createGroundedBlock(
		poi,
		"GatePostWest",
		position + Vector3.new(-11, 0, 0),
		Vector3.new(4, 18, 4),
		Enum.Material.Wood,
		COLORS.timber
	)
	createGroundedBlock(
		poi,
		"GatePostEast",
		position + Vector3.new(11, 0, 0),
		Vector3.new(4, 18, 4),
		Enum.Material.Wood,
		COLORS.timber
	)
	createColoredBlock(
		poi,
		"GateLintel",
		Vector3.new(26, 4, 5),
		CFrame.new(position + Vector3.new(0, 16, 0)),
		Enum.Material.Wood,
		COLORS.timber
	)
	createGroundedBlock(
		poi,
		"GuardTower",
		position + Vector3.new(25, 0, -8),
		Vector3.new(13, 27, 13),
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
end

local function createTrainingGround(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_training_ground", "TrainingGround")
	createGroundedBlock(
		poi,
		"GuardhouseVolume",
		position + Vector3.new(-12, 0, -5),
		Vector3.new(22, BUILDING_HEIGHTS.trainingGuardhouse, 16),
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
	for index, offsetX in ipairs({ -10, 0, 10 }) do
		createGroundedBlock(
			poi,
			string.format("TrainingPost%d", index),
			position + Vector3.new(offsetX, 0, 12),
			Vector3.new(2, 8, 2),
			Enum.Material.Wood,
			COLORS.timber
		)
	end
end

local function createBlacksmith(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_blacksmith", "Blacksmith")
	createHouseVolume(
		poi,
		"BlacksmithVolume",
		position,
		Vector3.new(34, BUILDING_HEIGHTS.blacksmith, 24)
	)
	createGroundedBlock(
		poi,
		"ForgePlaceholder",
		position + Vector3.new(-22, 0, 4),
		Vector3.new(8, 6, 8),
		Enum.Material.Slate,
		COLORS.darkStone
	)
end

local function createVillageSquare(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_village_square", "VillageSquare")
	createColoredBlock(
		poi,
		"SquarePlatform",
		Vector3.new(48, 1, 42),
		CFrame.new(position - Vector3.new(0, 0.5, 0)),
		Enum.Material.Cobblestone,
		COLORS.stone
	)
	createGroundedBlock(
		poi,
		"SquareLandmark",
		position,
		Vector3.new(5, 10, 5),
		Enum.Material.Slate,
		COLORS.darkStone
	)
end

local function createMerchant(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_merchant", "Merchant")
	createGroundedBlock(
		poi,
		"MerchantStallVolume",
		position,
		Vector3.new(22, BUILDING_HEIGHTS.merchantStall, 14),
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
end

local function createResidential(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_residential", "Residential")
	createHouseVolume(
		poi,
		"HouseVolumeA",
		position + Vector3.new(-12, 0, -5),
		Vector3.new(20, BUILDING_HEIGHTS.residence, 18)
	)
	createHouseVolume(
		poi,
		"HouseVolumeB",
		position + Vector3.new(13, 0, 7),
		Vector3.new(18, BUILDING_HEIGHTS.residence, 16)
	)
end

local function createElderHouse(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_elder_house", "ElderHouseQuestHub")
	createHouseVolume(
		poi,
		"ElderHouseVolume",
		position,
		Vector3.new(38, BUILDING_HEIGHTS.elderHouse, 28)
	)
	createGroundedBlock(
		poi,
		"ElderHouseRoofBlockout",
		position + Vector3.new(0, BUILDING_HEIGHTS.elderHouse, 0),
		Vector3.new(42, 5, 32),
		Enum.Material.Slate,
		COLORS.roof
	)
end

local function createShrine(parent: Instance, position: Vector3)
	local poi = createPoi(parent, "poi_shrine", "Shrine")
	createGroundedBlock(
		poi,
		"ShrineVolume",
		position,
		Vector3.new(24, BUILDING_HEIGHTS.shrine, 20),
		Enum.Material.Limestone,
		COLORS.shrine
	)
	createGroundedBlock(
		poi,
		"ShrineFocus",
		position + Vector3.new(0, 0, 14),
		Vector3.new(4, 9, 4),
		Enum.Material.Marble,
		COLORS.shrine
	)
end

local function createViewpoint(parent: Instance, shrinePosition: Vector3)
	local viewpointPosition = shrinePosition + Vector3.new(-24, 0, 10)
	local viewpoint = GreyboxPrimitives.createBlock(
		parent,
		"FutureRuinsViewpoint",
		Vector3.new(20, 1, 16),
		CFrame.new(viewpointPosition - Vector3.new(0, 0.5, 0)),
		Enum.Material.Slate,
		{
			Purpose = "Viewpoint",
			LooksToward = "ruins_of_selene_future",
		}
	)
	viewpoint.Color = COLORS.darkStone
	GreyboxPrimitives.createLabel(viewpoint, "Viewpoint: future Ruins of Selene")
end

local function createLocalStructures(parent: Instance, positions: { [string]: Vector3 })
	local structures = Instance.new("Folder")
	structures.Name = STRUCTURE_CONTAINER_NAME
	structures.Parent = parent

	local gatePosition = positions.poi_main_gate
	local squarePosition = positions.poi_village_square
	local elderPosition = positions.poi_elder_house
	local shrinePosition = positions.poi_shrine

	local sections = {
		{
			name = "GatePalisadeWest",
			from = gatePosition + Vector3.new(-45, 4, -4),
			to = gatePosition + Vector3.new(-15, 4, -2),
			material = Enum.Material.Wood,
			color = COLORS.timber,
		},
		{
			name = "GatePalisadeEast",
			from = gatePosition + Vector3.new(15, 4, -2),
			to = gatePosition + Vector3.new(45, 4, -4),
			material = Enum.Material.Wood,
			color = COLORS.timber,
		},
		{
			name = "MiddleRetainingWall",
			from = squarePosition + Vector3.new(-48, -1, 28),
			to = squarePosition + Vector3.new(48, -1, 28),
			material = Enum.Material.Slate,
			color = COLORS.stone,
		},
		{
			name = "UpperRetainingWallWest",
			from = shrinePosition + Vector3.new(-28, -2, 24),
			to = midpoint(shrinePosition, elderPosition) + Vector3.new(-8, -2, 27),
			material = Enum.Material.Slate,
			color = COLORS.stone,
		},
	}

	for _, section in ipairs(sections) do
		local block = GreyboxPrimitives.createSegment(structures, section.name, section.from, section.to, 3, 8)
		block.Material = section.material
		block.Color = section.color
	end
end

function LunaVillageGreybox.build(parent: Instance): Model
	local positions = createPoiPositionLookup()
	local village = createModel(parent, VILLAGE_MODEL_NAME, {
		ZoneId = "zone_luna_village",
	})

	createTerraces(village, positions)
	createVillagePaths(village, positions)

	local pointsOfInterest = Instance.new("Folder")
	pointsOfInterest.Name = POI_CONTAINER_NAME
	pointsOfInterest.Parent = village

	createMainGate(pointsOfInterest, positions.poi_main_gate)
	createTrainingGround(pointsOfInterest, positions.poi_training_ground)
	createBlacksmith(pointsOfInterest, positions.poi_blacksmith)
	createVillageSquare(pointsOfInterest, positions.poi_village_square)
	createMerchant(pointsOfInterest, positions.poi_merchant)
	createResidential(pointsOfInterest, positions.poi_residential)
	createElderHouse(pointsOfInterest, positions.poi_elder_house)
	createShrine(pointsOfInterest, positions.poi_shrine)

	createViewpoint(village, positions.poi_shrine)
	createLocalStructures(village, positions)

	return village
end

return table.freeze(LunaVillageGreybox)
