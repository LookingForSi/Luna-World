--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local Grounding = require(script.Parent.TerrainGrounding)
local P = require(script.Parent.BlockoutPrimitives)

local WorldDressingBlockout = {}

local COLORS = {
	stone = Color3.fromRGB(88, 90, 86),
	lightStone = Color3.fromRGB(122, 123, 116),
	darkStone = Color3.fromRGB(60, 62, 59),
	timber = Color3.fromRGB(92, 67, 46),
	darkTimber = Color3.fromRGB(61, 48, 38),
	deadWood = Color3.fromRGB(74, 66, 55),
	foliage = Color3.fromRGB(53, 78, 51),
	dryGrass = Color3.fromRGB(132, 116, 69),
	cloth = Color3.fromRGB(100, 76, 56),
}

local function poiPositions(): { [string]: Vector3 }
	local result: { [string]: Vector3 } = {}
	for _, poi in ipairs(WorldLayout.PointsOfInterest) do
		result[poi.id] = poi.position
	end
	return result
end

local function decorativeOptions(canCollide: boolean?)
	return {
		canCollide = if canCollide == nil then true else canCollide,
		attributes = {
			Decorative = true,
			DressingPass = "v01",
		},
	}
end

local function createRock(parent: Instance, name: string, position: Vector3, size: Vector3, yaw: number)
	local rock = P.groundedPart(
		parent,
		name,
		position,
		size,
		Enum.Material.Rock,
		COLORS.darkStone,
		decorativeOptions(true)
	)
	rock.CFrame *= CFrame.Angles(math.rad(5), math.rad(yaw), math.rad(-4))
end

local function createRockCluster(parent: Instance, name: string, center: Vector3, scale: number)
	local cluster = P.model(parent, name)
	for index, entry in ipairs({
		{ Vector3.new(-12, 0, -5), Vector3.new(13, 9, 11), -18 },
		{ Vector3.new(1, 0, 5), Vector3.new(9, 7, 8), 22 },
		{ Vector3.new(13, 0, -2), Vector3.new(7, 5, 9), 48 },
	}) do
		createRock(
			cluster,
			string.format("Rock%02d", index),
			center + (entry[1] :: Vector3) * scale,
			(entry[2] :: Vector3) * scale,
			entry[3] :: number
		)
	end
end

local function createStump(parent: Instance, name: string, position: Vector3, height: number)
	local stump = P.groundedPart(
		parent,
		name,
		position,
		Vector3.new(5.5, height, 5.5),
		Enum.Material.Wood,
		COLORS.deadWood,
		decorativeOptions(true)
	)
	stump.CFrame *= CFrame.Angles(math.rad(4), math.rad((position.X + position.Z) % 90), math.rad(2))
end

local function createTree(parent: Instance, name: string, position: Vector3, height: number, dead: boolean?)
	local model = P.model(parent, name)
	local ground = Grounding.surfaceAt(position)
	local trunkColor = if dead then COLORS.deadWood else COLORS.darkTimber

	P.part(
		model,
		"Trunk",
		Vector3.new(4.5, height, 4.5),
		CFrame.new(ground + Vector3.new(0, height / 2, 0)),
		Enum.Material.Wood,
		trunkColor,
		decorativeOptions(true)
	)

	if dead then
		P.segment(
			model,
			"DeadBranchA",
			ground + Vector3.new(0, height * 0.7, 0),
			ground + Vector3.new(8, height * 0.83, 3),
			1.1,
			1.1,
			Enum.Material.Wood,
			trunkColor,
			decorativeOptions(false)
		)
		P.segment(
			model,
			"DeadBranchB",
			ground + Vector3.new(0, height * 0.62, 0),
			ground + Vector3.new(-7, height * 0.76, -2),
			1.0,
			1.0,
			Enum.Material.Wood,
			trunkColor,
			decorativeOptions(false)
		)
	else
		P.part(
			model,
			"Crown",
			Vector3.new(17, 19, 17),
			CFrame.new(ground + Vector3.new(0, height + 5, 0)),
			Enum.Material.Grass,
			COLORS.foliage,
			{
				canCollide = false,
				shape = Enum.PartType.Ball,
				attributes = {
					Decorative = true,
					DressingPass = "v01",
				},
			}
		)
	end
end

local function createFenceLine(parent: Instance, name: string, fromPosition: Vector3, toPosition: Vector3, postSpacing: number)
	local fence = P.model(parent, name)
	local horizontal = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local length = horizontal.Magnitude
	local segments = math.max(1, math.ceil(length / postSpacing))

	local groundedPoints: { Vector3 } = {}
	for index = 0, segments do
		local authored = fromPosition:Lerp(toPosition, index / segments)
		local ground = Grounding.surfaceAt(authored)
		table.insert(groundedPoints, ground)

		P.part(
			fence,
			string.format("Post%02d", index + 1),
			Vector3.new(2.2, 8, 2.2),
			CFrame.new(ground + Vector3.new(0, 4, 0)),
			Enum.Material.Wood,
			COLORS.darkTimber,
			decorativeOptions(true)
		)
	end

	for index = 1, #groundedPoints - 1 do
		local a = groundedPoints[index]
		local b = groundedPoints[index + 1]
		for railIndex, y in ipairs({ 3.0, 6.0 }) do
			P.segment(
				fence,
				string.format("Rail_%02d_%02d", index, railIndex),
				a + Vector3.new(0, y, 0),
				b + Vector3.new(0, y, 0),
				1.2,
				1.2,
				Enum.Material.Wood,
				COLORS.timber,
				decorativeOptions(false)
			)
		end
	end
end

local function createLowStoneWall(parent: Instance, name: string, fromPosition: Vector3, toPosition: Vector3)
	local wall = P.model(parent, name)
	local horizontal = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local segments = math.max(1, math.ceil(horizontal.Magnitude / 24))

	for index = 1, segments do
		local a = fromPosition:Lerp(toPosition, (index - 1) / segments)
		local b = fromPosition:Lerp(toPosition, index / segments)
		local groundA = Grounding.surfaceAt(a)
		local groundB = Grounding.surfaceAt(b)
		P.segment(
			wall,
			string.format("Stone%02d", index),
			groundA + Vector3.new(0, 2.4, 0),
			groundB + Vector3.new(0, 2.4, 0),
			4.5,
			4.5,
			Enum.Material.Cobblestone,
			COLORS.stone,
			decorativeOptions(true)
		)
	end
end

local function createCrateStack(parent: Instance, name: string, position: Vector3, count: number)
	local stack = P.model(parent, name)
	local ground = Grounding.surfaceAt(position)
	for index = 1, count do
		local x = ((index - 1) % 2) * 7
		local layer = math.floor((index - 1) / 2)
		P.part(
			stack,
			string.format("Crate%02d", index),
			Vector3.new(6, 6, 6),
			CFrame.new(ground + Vector3.new(x, 3 + layer * 6, 0))
				* CFrame.Angles(0, math.rad((index * 13) % 30 - 15), 0),
			Enum.Material.WoodPlanks,
			COLORS.timber,
			decorativeOptions(true)
		)
	end
end

local function createLogPile(parent: Instance, name: string, position: Vector3)
	local pile = P.model(parent, name)
	local ground = Grounding.surfaceAt(position)
	for index = 1, 4 do
		local y = 1.7 + math.floor((index - 1) / 2) * 2.5
		local x = ((index - 1) % 2) * 4 - 2
		P.part(
			pile,
			string.format("Log%02d", index),
			Vector3.new(3, 3, 16),
			CFrame.new(ground + Vector3.new(x, y, 0)) * CFrame.Angles(0, math.rad(12), math.rad(90)),
			Enum.Material.Wood,
			COLORS.darkTimber,
			decorativeOptions(true)
		)
	end
end

local function buildVillageAndMeadows(parent: Instance, positions: { [string]: Vector3 })
	local dressing = P.model(parent, "VillageAndMeadowsDressing")

	local village = positions.poi_village_square
	createLowStoneWall(
		dressing,
		"VillageRetainingWallWest",
		village + Vector3.new(-210, 0, 55),
		village + Vector3.new(-155, 0, 180)
	)
	createLowStoneWall(
		dressing,
		"VillageRetainingWallEast",
		village + Vector3.new(210, 0, 55),
		village + Vector3.new(155, 0, 180)
	)
	createFenceLine(
		dressing,
		"VillagePastureFence",
		village + Vector3.new(-250, 0, 230),
		village + Vector3.new(-390, 0, 345),
		34
	)
	createRockCluster(dressing, "VillageRockClusterA", village + Vector3.new(260, 0, 145), 1.3)
	createRockCluster(dressing, "VillageRockClusterB", village + Vector3.new(-275, 0, 115), 1.0)

	local farm = positions.poi_moonfall_farm
	createFenceLine(
		dressing,
		"FarmRoadFenceA",
		farm + Vector3.new(-190, 0, -120),
		farm + Vector3.new(-145, 0, 145),
		30
	)
	createFenceLine(
		dressing,
		"FarmRoadFenceB",
		farm + Vector3.new(175, 0, -95),
		farm + Vector3.new(155, 0, 125),
		30
	)
	createLogPile(dressing, "FarmLogPile", farm + Vector3.new(96, 0, -62))
	createCrateStack(dressing, "FarmCrates", farm + Vector3.new(-105, 0, -58), 3)
	createRockCluster(dressing, "FarmFieldRocks", farm + Vector3.new(-185, 0, 165), 0.8)

	local bridge = positions.poi_meadow_bridge
	createRockCluster(dressing, "RiverRockClusterWest", bridge + Vector3.new(-145, 0, 28), 1.0)
	createRockCluster(dressing, "RiverRockClusterEast", bridge + Vector3.new(150, 0, -34), 1.15)

	local circle = positions.poi_stone_circle
	for index, offset in ipairs({
		Vector3.new(95, 0, -85),
		Vector3.new(140, 0, 20),
		Vector3.new(100, 0, 120),
		Vector3.new(-105, 0, 105),
	}) do
		createTree(dressing, string.format("MeadowTree%02d", index), circle + offset, 25 + index * 2)
	end
	createRockCluster(dressing, "StoneCircleOuterRocks", circle + Vector3.new(-110, 0, -100), 0.9)
end

local function buildMoonfallAndEncounters(parent: Instance, positions: { [string]: Vector3 })
	local dressing = P.model(parent, "MoonfallEncounterDressing")

	local crossroads = positions.poi_moonfall_crossroads
	createFenceLine(
		dressing,
		"MoonfallBrokenFenceWest",
		crossroads + Vector3.new(-170, 0, -130),
		crossroads + Vector3.new(-260, 0, 70),
		38
	)
	createFenceLine(
		dressing,
		"MoonfallBrokenFenceEast",
		crossroads + Vector3.new(165, 0, -120),
		crossroads + Vector3.new(245, 0, 55),
		38
	)
	createRockCluster(dressing, "CrossroadsRocksA", crossroads + Vector3.new(-135, 0, 115), 1.0)
	createRockCluster(dressing, "CrossroadsRocksB", crossroads + Vector3.new(155, 0, 100), 1.1)
	createStump(dressing, "CrossroadsStumpA", crossroads + Vector3.new(-200, 0, 150), 7)
	createStump(dressing, "CrossroadsStumpB", crossroads + Vector3.new(205, 0, 145), 6)

	local goblin = positions.poi_goblin_camp
	for index, offset in ipairs({
		Vector3.new(-155, 0, -90),
		Vector3.new(-145, 0, 105),
		Vector3.new(135, 0, -105),
		Vector3.new(165, 0, 90),
	}) do
		createStump(dressing, string.format("GoblinStake%02d", index), goblin + offset, 11 + index)
	end
	createCrateStack(dressing, "GoblinSupplyCrates", goblin + Vector3.new(88, 0, 20), 5)
	createLogPile(dressing, "GoblinLogPile", goblin + Vector3.new(-92, 0, 42))
	createRockCluster(dressing, "GoblinOuterRocksA", goblin + Vector3.new(205, 0, -150), 1.25)
	createRockCluster(dressing, "GoblinOuterRocksB", goblin + Vector3.new(-210, 0, 165), 1.0)

	local spider = positions.poi_spider_hollow
	for index, offset in ipairs({
		Vector3.new(-195, 0, -135),
		Vector3.new(-205, 0, 95),
		Vector3.new(175, 0, -145),
		Vector3.new(205, 0, 85),
		Vector3.new(15, 0, 210),
	}) do
		createTree(dressing, string.format("SpiderDeadTree%02d", index), spider + offset, 26 + index * 3, true)
	end
	createRockCluster(dressing, "SpiderOuterRocksA", spider + Vector3.new(-225, 0, 25), 1.35)
	createRockCluster(dressing, "SpiderOuterRocksB", spider + Vector3.new(220, 0, -10), 1.25)

	local darkGate = positions.poi_dark_woodland_gate
	for index, offset in ipairs({
		Vector3.new(-310, 0, -120),
		Vector3.new(-270, 0, 80),
		Vector3.new(-220, 0, 180),
		Vector3.new(225, 0, 175),
		Vector3.new(275, 0, 70),
		Vector3.new(315, 0, -115),
	}) do
		createTree(dressing, string.format("WoodlandMassTree%02d", index), darkGate + offset, 32 + index * 3)
	end
	createRockCluster(dressing, "WoodlandThresholdRocksA", darkGate + Vector3.new(-125, 0, 100), 1.0)
	createRockCluster(dressing, "WoodlandThresholdRocksB", darkGate + Vector3.new(130, 0, 95), 1.05)
end

local function buildUpperValley(parent: Instance, positions: { [string]: Vector3 })
	local dressing = P.model(parent, "UpperValleyDressing")

	local cemetery = positions.poi_old_cemetery
	createLowStoneWall(
		dressing,
		"CemeteryBoundarySouthA",
		cemetery + Vector3.new(-145, 0, -120),
		cemetery + Vector3.new(-42, 0, -120)
	)
	createLowStoneWall(
		dressing,
		"CemeteryBoundarySouthB",
		cemetery + Vector3.new(42, 0, -120),
		cemetery + Vector3.new(145, 0, -120)
	)
	createLowStoneWall(
		dressing,
		"CemeteryBoundaryWest",
		cemetery + Vector3.new(-145, 0, -120),
		cemetery + Vector3.new(-145, 0, 110)
	)
	createLowStoneWall(
		dressing,
		"CemeteryBoundaryEast",
		cemetery + Vector3.new(145, 0, -120),
		cemetery + Vector3.new(145, 0, 110)
	)
	createTree(dressing, "CemeteryDeadTreeA", cemetery + Vector3.new(-115, 0, 75), 34, true)
	createTree(dressing, "CemeteryDeadTreeB", cemetery + Vector3.new(120, 0, 70), 30, true)
	createRockCluster(dressing, "CemeteryRubble", cemetery + Vector3.new(115, 0, -75), 0.9)

	local shrine = positions.poi_fallen_shrine
	for index, offset in ipairs({
		Vector3.new(-125, 0, -105),
		Vector3.new(118, 0, -95),
		Vector3.new(-140, 0, 80),
		Vector3.new(145, 0, 95),
	}) do
		createRockCluster(dressing, string.format("ShrineRubble%02d", index), shrine + offset, 0.8 + index * 0.08)
	end
	for index, offset in ipairs({
		Vector3.new(-95, 0, 55),
		Vector3.new(95, 0, 60),
	}) do
		createStump(dressing, string.format("ShrineDeadStump%02d", index), shrine + offset, 8)
	end

	local approach = positions.poi_ancient_approach
	for index, zOffset in ipairs({ -300, -180, -60, 70, 205 }) do
		createRockCluster(
			dressing,
			string.format("ApproachRoadsideRocksLeft%02d", index),
			approach + Vector3.new(-150 - index * 5, 0, zOffset),
			0.8 + index * 0.05
		)
		createRockCluster(
			dressing,
			string.format("ApproachRoadsideRocksRight%02d", index),
			approach + Vector3.new(150 + index * 5, 0, zOffset + 20),
			0.8 + index * 0.05
		)
	end

	createLowStoneWall(
		dressing,
		"ApproachRuinedWallLeft",
		approach + Vector3.new(-210, 0, -250),
		approach + Vector3.new(-235, 0, 130)
	)
	createLowStoneWall(
		dressing,
		"ApproachRuinedWallRight",
		approach + Vector3.new(210, 0, -250),
		approach + Vector3.new(235, 0, 130)
	)
end

function WorldDressingBlockout.build(parent: Instance)
	local positions = poiPositions()
	local root = P.model(parent, "EnvironmentDressing")
	root:SetAttribute("Purpose", "ReplaceableBlockoutDressing")
	root:SetAttribute("ArtReplacementTarget", "BlenderModularKits")

	buildVillageAndMeadows(root, positions)
	buildMoonfallAndEncounters(root, positions)
	buildUpperValley(root, positions)
end

return table.freeze(WorldDressingBlockout)
