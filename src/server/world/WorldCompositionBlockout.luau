--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local Grounding = require(script.Parent.TerrainGrounding)
local P = require(script.Parent.BlockoutPrimitives)

local WorldCompositionBlockout = {}

local COLORS = {
	timber = Color3.fromRGB(91, 67, 49),
	darkTimber = Color3.fromRGB(57, 46, 38),
	roof = Color3.fromRGB(68, 65, 66),
	foliage = Color3.fromRGB(49, 73, 48),
	darkFoliage = Color3.fromRGB(39, 59, 42),
	deadWood = Color3.fromRGB(67, 61, 54),
	stone = Color3.fromRGB(87, 90, 88),
	ancientStone = Color3.fromRGB(112, 112, 106),
	field = Color3.fromRGB(137, 120, 75),
}

local function poiPositions(): { [string]: Vector3 }
	local result: { [string]: Vector3 } = {}
	for _, poi in ipairs(WorldLayout.PointsOfInterest) do
		result[poi.id] = poi.position
	end
	return result
end

local function attrs(category: string): { [string]: any }
	return {
		Decorative = true,
		CompositionPass = "v01",
		ReplacementCategory = category,
	}
end

local function createTree(
	parent: Instance,
	name: string,
	position: Vector3,
	height: number,
	crownScale: number,
	dead: boolean?
)
	local ground, plantable = Grounding.treeSurfaceAt(position)
	if not plantable or ground == nil then
		return
	end

	local model = P.model(parent, name)
	model:SetAttribute("ReplacementCategory", if dead then "dead_tree" else "tree")
	P.part(
		model,
		"Trunk",
		Vector3.new(4.5, height, 4.5),
		CFrame.new(ground + Vector3.new(0, height / 2, 0)),
		Enum.Material.Wood,
		if dead then COLORS.deadWood else COLORS.darkTimber,
		{
			canCollide = true,
			attributes = attrs(if dead then "dead_tree" else "tree"),
		}
	)

	if dead then
		P.segment(
			model,
			"BranchA",
			ground + Vector3.new(0, height * 0.65, 0),
			ground + Vector3.new(9, height * 0.82, 4),
			1.0,
			1.0,
			Enum.Material.Wood,
			COLORS.deadWood,
			{ canCollide = false, attributes = attrs("dead_tree") }
		)
		P.segment(
			model,
			"BranchB",
			ground + Vector3.new(0, height * 0.72, 0),
			ground + Vector3.new(-7, height * 0.87, -3),
			1.0,
			1.0,
			Enum.Material.Wood,
			COLORS.deadWood,
			{ canCollide = false, attributes = attrs("dead_tree") }
		)
	else
		P.part(
			model,
			"Crown",
			Vector3.new(18, 20, 18) * crownScale,
			CFrame.new(ground + Vector3.new(0, height + 6 * crownScale, 0)),
			Enum.Material.Grass,
			if crownScale > 1.1 then COLORS.darkFoliage else COLORS.foliage,
			{
				canCollide = false,
				shape = Enum.PartType.Ball,
				attributes = attrs("tree"),
			}
		)
	end
end

local function createTreeBelt(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	count: number,
	lateralAmplitude: number,
	dead: boolean?
)
	local belt = P.model(parent, name)
	local horizontal = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local direction = horizontal.Unit
	local lateral = Vector3.new(-direction.Z, 0, direction.X)

	for index = 1, count do
		local alpha = if count == 1 then 0.5 else (index - 1) / (count - 1)
		local wave = math.sin(index * 1.73) * lateralAmplitude
		local authored = fromPosition:Lerp(toPosition, alpha) + lateral * wave
		createTree(
			belt,
			string.format("Tree%02d", index),
			authored,
			27 + (index % 5) * 4,
			0.9 + (index % 4) * 0.08,
			dead
		)
	end
end

local function createRock(parent: Instance, name: string, position: Vector3, scale: number)
	local rock = P.groundedPart(
		parent,
		name,
		position,
		Vector3.new(14, 10, 12) * scale,
		Enum.Material.Rock,
		COLORS.stone,
		{
			canCollide = true,
			shape = Enum.PartType.Ball,
			attributes = attrs("rock"),
		}
	)
	rock.CFrame *= CFrame.Angles(math.rad(5), math.rad((position.X + position.Z) % 85), math.rad(-6))
end

local function createRockLine(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	count: number,
	scale: number
)
	local model = P.model(parent, name)
	for index = 1, count do
		local alpha = if count == 1 then 0.5 else (index - 1) / (count - 1)
		local pos = fromPosition:Lerp(toPosition, alpha)
		local offset = Vector3.new(math.sin(index * 2.2) * 8, 0, math.cos(index * 1.4) * 8)
		createRock(model, string.format("Rock%02d", index), pos + offset, scale * (0.85 + (index % 3) * 0.12))
	end
end

local function createSilhouetteHouse(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	yaw: number
)
	local model = P.model(parent, name)
	model:SetAttribute("ReplacementCategory", "village_house")

	local body = P.groundedPart(
		model,
		"Body",
		position,
		size,
		Enum.Material.WoodPlanks,
		COLORS.timber,
		{
			canCollide = true,
			attributes = attrs("village_house"),
		}
	)
	body.CFrame *= CFrame.Angles(0, math.rad(yaw), 0)

	P.part(
		model,
		"Roof",
		Vector3.new(size.X + 5, 4, size.Z + 5),
		body.CFrame * CFrame.new(0, size.Y / 2 + 2.5, 0),
		Enum.Material.Slate,
		COLORS.roof,
		{
			canCollide = false,
			attributes = attrs("village_roof"),
		}
	)
end

local function createRuinPillar(
	parent: Instance,
	name: string,
	position: Vector3,
	height: number,
	width: number
)
	local pillar = P.groundedPart(
		parent,
		name,
		position,
		Vector3.new(width, height, width),
		Enum.Material.Limestone,
		COLORS.ancientStone,
		{
			canCollide = true,
			attributes = attrs("ancient_ruin"),
		}
	)
	pillar.CFrame *= CFrame.Angles(math.rad((position.Z % 5) - 2), math.rad((position.X + position.Z) % 20 - 10), math.rad(2))
end

local function createPine(parent: Instance, name: string, position: Vector3, height: number)
	local ground, plantable = Grounding.treeSurfaceAt(position)
	if not plantable or ground == nil then
		return
	end

	local model = P.model(parent, name)
	model:SetAttribute("ReplacementCategory", "conifer")

	P.part(
		model,
		"Trunk",
		Vector3.new(3.8, height, 3.8),
		CFrame.new(ground + Vector3.new(0, height / 2 - 0.5, 0)),
		Enum.Material.Wood,
		COLORS.darkTimber,
		{ canCollide = true, attributes = attrs("conifer") }
	)

	for layer = 1, 3 do
		local width = 18 - (layer - 1) * 4
		local y = height * 0.48 + (layer - 1) * 6.5
		P.part(
			model,
			string.format("Crown%02d", layer),
			Vector3.new(width, 10, width),
			CFrame.new(ground + Vector3.new(0, y, 0)),
			Enum.Material.Grass,
			COLORS.darkFoliage,
			{
				canCollide = false,
				shape = Enum.PartType.Ball,
				attributes = attrs("conifer"),
			}
		)
	end
end

local function createMixedForestPatch(
	parent: Instance,
	name: string,
	center: Vector3,
	halfX: number,
	halfZ: number,
	count: number
)
	local forest = P.model(parent, name)
	forest:SetAttribute("ReplacementCategory", "mixed_forest")
	local columns = math.max(2, math.ceil(math.sqrt(count)))

	for index = 1, count do
		local col = (index - 1) % columns
		local row = math.floor((index - 1) / columns)
		local rows = math.max(1, math.ceil(count / columns))
		local u = if columns == 1 then 0 else col / (columns - 1) * 2 - 1
		local v = if rows == 1 then 0 else row / (rows - 1) * 2 - 1
		local jitterX = math.sin(index * 2.17) * math.min(28, halfX * 0.12)
		local jitterZ = math.cos(index * 1.61) * math.min(28, halfZ * 0.12)
		local pos = center + Vector3.new(u * halfX + jitterX, 0, v * halfZ + jitterZ)

		if index % 3 == 0 or index % 7 == 0 then
			createPine(forest, string.format("Pine%03d", index), pos, 30 + (index % 5) * 4)
		else
			createTree(
				forest,
				string.format("Broadleaf%03d", index),
				pos,
				27 + (index % 5) * 4,
				0.88 + (index % 4) * 0.08,
				false
			)
		end
	end
end

local function shapeFallenShrineSouthCliff(shrine: Vector3)
	local terrain = Workspace.Terrain
	local summit = Grounding.surfaceAt(shrine)
	local southSample = Grounding.surfaceAt(shrine + Vector3.new(0, 0, -390))
	local lowerY = math.min(southSample.Y, summit.Y - 46)
	local faceBaseZ = shrine.Z - 245
	local carveTopY = summit.Y + 24
	local carveHeight = math.max(32, carveTopY - lowerY)

	-- Remove the former climbable grassy ramp while keeping the low southern
	-- terrain. The resulting cut is then backed by Terrain Rock, not Parts.
	terrain:FillBlock(
		CFrame.new(shrine.X, lowerY + carveHeight / 2, faceBaseZ - 120),
		Vector3.new(600, carveHeight, 250),
		Enum.Material.Air
	)

	for index, xOffset in ipairs({ -240, -120, 0, 120, 240 }) do
		local faceZ = faceBaseZ + ((index % 3) - 1) * 12
		local width = 132
		local height = summit.Y - lowerY + 8
		terrain:FillBlock(
			CFrame.new(shrine.X + xOffset, lowerY + height / 2, faceZ + 22),
			Vector3.new(width, height, 58),
			Enum.Material.Rock
		)
	end
end
local function buildVillageHill(parent: Instance, p: { [string]: Vector3 })
	local village = P.model(parent, "VillageHillComposition")
	local square = p.poi_village_square

	for index, spec in ipairs({
		{ offset = Vector3.new(-255, 0, -55), size = Vector3.new(34, 18, 26), yaw = -18 },
		{ offset = Vector3.new(-225, 0, -155), size = Vector3.new(30, 17, 24), yaw = 12 },
		{ offset = Vector3.new(-125, 0, -250), size = Vector3.new(36, 20, 28), yaw = 8 },
		{ offset = Vector3.new(125, 0, -255), size = Vector3.new(34, 19, 27), yaw = -6 },
		{ offset = Vector3.new(235, 0, -150), size = Vector3.new(32, 18, 24), yaw = -14 },
		{ offset = Vector3.new(260, 0, -35), size = Vector3.new(38, 20, 29), yaw = 16 },
	}) do
		createSilhouetteHouse(
			village,
			string.format("OuterHouse%02d", index),
			square + spec.offset,
			spec.size,
			spec.yaw
		)
	end

	createTreeBelt(
		village,
		"VillageWestTreeBelt",
		square + Vector3.new(-390, 0, -260),
		square + Vector3.new(-430, 0, 210),
		10,
		18
	)
	createTreeBelt(
		village,
		"VillageEastTreeBelt",
		square + Vector3.new(390, 0, -250),
		square + Vector3.new(430, 0, 180),
		10,
		18
	)
	createRockLine(
		village,
		"VillageHillRocksWest",
		square + Vector3.new(-330, 0, 100),
		square + Vector3.new(-420, 0, 320),
		6,
		1.0
	)
	createRockLine(
		village,
		"VillageHillRocksEast",
		square + Vector3.new(330, 0, 90),
		square + Vector3.new(420, 0, 300),
		6,
		1.0
	)
end

local function buildFarmAndMeadows(parent: Instance, p: { [string]: Vector3 })
	local meadows = P.model(parent, "FarmAndMeadowsComposition")
	local farm = p.poi_moonfall_farm
	local bridge = p.poi_meadow_bridge
	local circle = p.poi_stone_circle

	P.replaceTerrainMaterials(
		circle + Vector3.new(245, 0, 35),
		Vector3.new(250, 26, 190),
		{ Enum.Material.Grass, Enum.Material.LeafyGrass },
		Enum.Material.Rock
	)
	createRockLine(
		meadows,
		"MeadowHillScree",
		circle + Vector3.new(170, 0, -30),
		circle + Vector3.new(315, 0, 95),
		9,
		0.72
	)

	createMixedForestPatch(
		meadows,
		"WolfRiverMixedForest",
		circle + Vector3.new(35, 0, -255),
		245,
		135,
		28
	)
	createMixedForestPatch(
		meadows,
		"WolfGoblinMixedForest",
		circle + Vector3.new(250, 0, 420),
		300,
		290,
		36
	)

	createTreeBelt(
		meadows,
		"RiverTreeBeltWest",
		bridge + Vector3.new(-520, 0, 105),
		bridge + Vector3.new(-210, 0, 80),
		8,
		22
	)
	createTreeBelt(
		meadows,
		"RiverTreeBeltEast",
		bridge + Vector3.new(250, 0, -95),
		bridge + Vector3.new(610, 0, -70),
		9,
		24
	)
	createRockLine(
		meadows,
		"MeadowStoneSpine",
		circle + Vector3.new(175, 0, -190),
		circle + Vector3.new(320, 0, 170),
		6,
		0.9
	)
	createTreeBelt(
		meadows,
		"MeadowOuterTrees",
		circle + Vector3.new(290, 0, -260),
		circle + Vector3.new(390, 0, 260),
		9,
		30
	)
end

local function buildCombatBlock(parent: Instance, p: { [string]: Vector3 })
	local combat = P.model(parent, "CombatBlockComposition")
	local crossroads = p.poi_moonfall_crossroads
	local goblin = p.poi_goblin_camp
	local spider = p.poi_spider_hollow
	local darkGate = p.poi_dark_woodland_gate

	P.replaceTerrainMaterials(
		goblin + Vector3.new(250, 0, -5),
		Vector3.new(260, 28, 245),
		{ Enum.Material.Grass, Enum.Material.LeafyGrass },
		Enum.Material.Rock
	)
	createTreeBelt(
		combat,
		"MoonfallWestScreen",
		crossroads + Vector3.new(-780, 0, -230),
		crossroads + Vector3.new(-840, 0, 230),
		10,
		35
	)
	createTreeBelt(
		combat,
		"MoonfallEastScreen",
		crossroads + Vector3.new(780, 0, -230),
		crossroads + Vector3.new(840, 0, 230),
		10,
		35
	)

	createMixedForestPatch(
		combat,
		"GoblinCemeteryEastForest",
		goblin:Lerp(p.poi_old_cemetery, 0.5) + Vector3.new(540, 0, 10),
		165,
		400,
		30
	)
	createMixedForestPatch(
		combat,
		"GoblinCemeteryRoadsideForest",
		goblin:Lerp(p.poi_old_cemetery, 0.5) + Vector3.new(-300, 0, 5),
		170,
		360,
		26
	)
	createMixedForestPatch(
		combat,
		"GoblinOuterForest",
		goblin + Vector3.new(300, 0, 80),
		250,
		230,
		28
	)

	-- The boundary-facing side of the Goblin Camp is now a continuous terrain shelf; no rock-wall edge.
	createTreeBelt(
		combat,
		"GoblinRearTrees",
		goblin + Vector3.new(-170, 0, 205),
		goblin + Vector3.new(215, 0, 230),
		8,
		28
	)

	createRockLine(
		combat,
		"SpiderBasinWestRocks",
		spider + Vector3.new(-245, 0, -175),
		spider + Vector3.new(-285, 0, 190),
		7,
		1.0
	)
	createTreeBelt(
		combat,
		"SpiderBasinRearDeadwood",
		spider + Vector3.new(-300, 0, 250),
		spider + Vector3.new(-160, 0, 320),
		8,
		24,
		true
	)

	createTreeBelt(
		combat,
		"DarkWoodlandWestMass",
		darkGate + Vector3.new(-520, 0, -120),
		darkGate + Vector3.new(-350, 0, 280),
		15,
		45
	)
	createTreeBelt(
		combat,
		"DarkWoodlandEastMass",
		darkGate + Vector3.new(520, 0, -120),
		darkGate + Vector3.new(350, 0, 280),
		15,
		45
	)
end

local function buildUpperValley(parent: Instance, p: { [string]: Vector3 })
	local upper = P.model(parent, "UpperValleyComposition")
	local cemetery = p.poi_old_cemetery
	local shrine = p.poi_fallen_shrine
	local approach = p.poi_ancient_approach

	-- Fallen Shrine sits on a real terrain promontory: the gentle southern
	-- grass ramp is carved away and replaced by a steep rock face.
	shapeFallenShrineSouthCliff(shrine)
	createRockLine(
		upper,
		"FallenShrineCliffScree",
		shrine + Vector3.new(-250, 0, -355),
		shrine + Vector3.new(250, 0, -350),
		14,
		0.78
	)

	P.replaceTerrainMaterials(
		cemetery + Vector3.new(190, 0, -145),
		Vector3.new(235, 28, 175),
		{ Enum.Material.Grass, Enum.Material.LeafyGrass },
		Enum.Material.Rock
	)

	createTreeBelt(
		upper,
		"CemeteryRearDeadwood",
		cemetery + Vector3.new(-210, 0, 180),
		cemetery + Vector3.new(220, 0, 190),
		8,
		30,
		true
	)
	createRockLine(
		upper,
		"CemeteryOuterRocks",
		cemetery + Vector3.new(190, 0, -160),
		cemetery + Vector3.new(245, 0, 135),
		6,
		1.05
	)

	createRockLine(
		upper,
		"ShrinePromontoryRocks",
		shrine + Vector3.new(-250, 0, -150),
		shrine + Vector3.new(-210, 0, 170),
		7,
		1.15
	)
	createTreeBelt(
		upper,
		"ShrineRearDeadwood",
		shrine + Vector3.new(-190, 0, 190),
		shrine + Vector3.new(210, 0, 200),
		7,
		28,
		true
	)

	for index, z in ipairs({ -300, -150, 10, 170, 320 }) do
		createRuinPillar(
			upper,
			string.format("ApproachOuterPillarLeft%02d", index),
			approach + Vector3.new(-270, 0, z),
			22 + index * 5,
			10 + index
		)
		createRuinPillar(
			upper,
			string.format("ApproachOuterPillarRight%02d", index),
			approach + Vector3.new(270, 0, z + 15),
			24 + index * 5,
			10 + index
		)
	end

	createRockLine(
		upper,
		"ApproachWestEscarpment",
		approach + Vector3.new(-340, 0, -300),
		approach + Vector3.new(-420, 0, 320),
		9,
		1.3
	)
	createRockLine(
		upper,
		"ApproachEastEscarpment",
		approach + Vector3.new(340, 0, -300),
		approach + Vector3.new(420, 0, 320),
		9,
		1.3
	)
end

function WorldCompositionBlockout.build(parent: Instance)
	local positions = poiPositions()
	local root = P.model(parent, "MacroComposition")
	root:SetAttribute("Purpose", "SpatialDensityAndSightlineBlockout")
	root:SetAttribute("ArtReplacementTarget", "BlenderStudioAssetPass")

	buildVillageHill(root, positions)
	buildFarmAndMeadows(root, positions)
	buildCombatBlock(root, positions)
	buildUpperValley(root, positions)
end

return table.freeze(WorldCompositionBlockout)
