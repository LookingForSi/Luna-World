--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local Grounding = require(script.Parent.TerrainGrounding)
local P = require(script.Parent.BlockoutPrimitives)

local NorthernZonesBlockout = {}

local COLORS = {
	road = Color3.fromRGB(118, 101, 78),
	stone = Color3.fromRGB(92, 94, 91),
	darkStone = Color3.fromRGB(58, 61, 61),
	ancientStone = Color3.fromRGB(116, 116, 111),
	timber = Color3.fromRGB(94, 66, 45),
	darkTimber = Color3.fromRGB(57, 46, 37),
	goblinCloth = Color3.fromRGB(98, 74, 52),
	fire = Color3.fromRGB(219, 132, 50),
	tree = Color3.fromRGB(64, 52, 42),
	foliage = Color3.fromRGB(45, 70, 49),
	deadTree = Color3.fromRGB(64, 58, 52),
	web = Color3.fromRGB(202, 206, 210),
	goblin = Color3.fromRGB(91, 112, 67),
	spider = Color3.fromRGB(48, 43, 47),
}

local function poiPositions(): { [string]: Vector3 }
	local result: { [string]: Vector3 } = {}
	for _, poi in ipairs(WorldLayout.PointsOfInterest) do
		result[poi.id] = poi.position
	end
	return result
end

local function createGroundedRoad(parent: Instance, name: string, points: { Vector3 }, width: number, material: Enum.Material?)
	local folder = P.folder(parent, name)
	local segmentIndex = 0
	for routeIndex = 1, #points - 1 do
		local start = points[routeIndex]
		local finish = points[routeIndex + 1]
		local horizontal = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
		local divisions = math.max(1, math.ceil(horizontal.Magnitude / 65))
		for step = 1, divisions do
			local a = start:Lerp(finish, (step - 1) / divisions)
			local b = start:Lerp(finish, step / divisions)
			segmentIndex += 1
			P.paintTerrainStrip(a, b, width + 6, material or Enum.Material.Ground)
			P.groundedSegment(
				folder,
				string.format("Segment%03d", segmentIndex),
				a,
				b,
				width,
				0.35,
				material or Enum.Material.Ground,
				COLORS.road,
				{ canCollide = false, attributes = { DecorativeRoad = true } }
			)
		end
	end
end

local function createPalisadeLine(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	postHeight: number
)
	local wall = P.model(parent, name)
	local horizontal = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local postSpacing = 6.5
	local segments = math.max(1, math.ceil(horizontal.Magnitude / postSpacing))

	for index = 0, segments do
		local alpha = index / segments
		local authored = fromPosition:Lerp(toPosition, alpha)
		local ground = Grounding.surfaceAt(authored)
		local height = postHeight + ((index % 4) - 1.5) * 0.7
		P.part(
			wall,
			string.format("Stake%03d", index + 1),
			Vector3.new(3.0, height, 3.0),
			CFrame.new(ground + Vector3.new(0, height / 2 - 0.5, 0)),
			Enum.Material.Wood,
			COLORS.darkTimber
		)
	end
end

local function createRock(parent: Instance, name: string, position: Vector3, size: Vector3)
	local rock = P.groundedPart(
		parent,
		name,
		position,
		size,
		Enum.Material.Rock,
		COLORS.darkStone,
		{ shape = Enum.PartType.Ball }
	)
	rock.CFrame *= CFrame.Angles(math.rad(7), math.rad((position.X + position.Z) % 70), math.rad(-5))
end

local function createTree(parent: Instance, name: string, position: Vector3, height: number, dead: boolean?)
	local ground, plantable = Grounding.treeSurfaceAt(position)
	if not plantable or ground == nil then
		return
	end

	local model = P.model(parent, name)
	local trunkColor = if dead then COLORS.deadTree else COLORS.tree
	P.part(
		model,
		"Trunk",
		Vector3.new(4.5, height, 4.5),
		CFrame.new(ground + Vector3.new(0, height / 2, 0)),
		Enum.Material.Wood,
		trunkColor
	)
	if not dead then
		P.part(
			model,
			"Crown",
			Vector3.new(16, 18, 16),
			CFrame.new(ground + Vector3.new(0, height + 5, 0)),
			Enum.Material.Grass,
			COLORS.foliage,
			{ canCollide = false, shape = Enum.PartType.Ball }
		)
	else
		for index, side in ipairs({ -1, 1 }) do
			P.segment(
				model,
				string.format("Branch%02d", index),
				ground + Vector3.new(0, height * 0.7, 0),
				ground + Vector3.new(side * 8, height * 0.83, 2),
				1.2,
				1.2,
				Enum.Material.Wood,
				trunkColor,
				{ canCollide = false }
			)
		end
	end
end

local function createGoblin(parent: Instance, name: string, position: Vector3)
	local model = P.model(parent, name)
	model:SetAttribute("Purpose", "MobPlaceholder")
	model:SetAttribute("MobId", "mob_goblin_scout")
	local ground = Grounding.surfaceAt(position)
	P.part(
		model,
		"Body",
		Vector3.new(3.5, 5, 2.5),
		CFrame.new(ground + Vector3.new(0, 3.5, 0)),
		Enum.Material.SmoothPlastic,
		COLORS.goblin,
		{ canCollide = false }
	)
	P.part(
		model,
		"Head",
		Vector3.new(3, 3, 3),
		CFrame.new(ground + Vector3.new(0, 7.2, 0)),
		Enum.Material.SmoothPlastic,
		COLORS.goblin,
		{ canCollide = false, shape = Enum.PartType.Ball }
	)
	P.segment(
		model,
		"Spear",
		ground + Vector3.new(2.5, 1.2, 0),
		ground + Vector3.new(2.5, 9, 0),
		0.45,
		0.45,
		Enum.Material.Wood,
		COLORS.timber,
		{ canCollide = false }
	)
end

local function createSpider(parent: Instance, name: string, position: Vector3, scale: number)
	local model = P.model(parent, name)
	model:SetAttribute("Purpose", "MobPlaceholder")
	model:SetAttribute("MobId", "mob_spider")
	local ground = Grounding.surfaceAt(position)
	P.part(
		model,
		"Body",
		Vector3.new(5, 3.5, 6) * scale,
		CFrame.new(ground + Vector3.new(0, 2.5 * scale, 0)),
		Enum.Material.SmoothPlastic,
		COLORS.spider,
		{ canCollide = false, shape = Enum.PartType.Ball }
	)
	for sideIndex, side in ipairs({ -1, 1 }) do
		for leg = 1, 4 do
			local z = (leg - 2.5) * 1.8 * scale
			P.segment(
				model,
				string.format("Leg_%d_%d", sideIndex, leg),
				ground + Vector3.new(side * 1.2 * scale, 2.2 * scale, z),
				ground + Vector3.new(side * (5 + leg) * scale, 0.8 * scale, z),
				0.45 * scale,
				0.45 * scale,
				Enum.Material.SmoothPlastic,
				COLORS.spider,
				{ canCollide = false }
			)
		end
	end
end

local function createHut(parent: Instance, name: string, position: Vector3, yaw: number)
	local model = P.model(parent, name)
	P.groundedPart(
		model,
		"Foundation",
		position,
		Vector3.new(32, 5, 26),
		Enum.Material.Rock,
		COLORS.darkStone
	)
	local body = P.groundedPart(
		model,
		"Body",
		position,
		Vector3.new(28, 12, 22),
		Enum.Material.WoodPlanks,
		COLORS.goblinCloth
	)
	body.CFrame *= CFrame.Angles(0, math.rad(yaw), 0)
	local ground = Grounding.surfaceAt(position)
	P.part(
		model,
		"Roof",
		Vector3.new(32, 3, 26),
		body.CFrame * CFrame.new(0, 7.5, 0),
		Enum.Material.Wood,
		COLORS.darkTimber,
		{ canCollide = false }
	)
end

local function createGoblinCamp(parent: Instance, positions: { [string]: Vector3 })
	local camp = P.model(parent, "GoblinCamp")
	camp:SetAttribute("ZoneId", "zone_goblin_camp")
	local center = positions.poi_goblin_camp
	local halfX, halfZ = 137, 110

	-- The authored road approaches from the west. Keep the southern/wolf-facing
	-- palisade closed and put the real guarded entrance on the road side.
	local gateHalfWidth = 32
	local fenceSegments = {
		{ center + Vector3.new(-halfX, 0, -halfZ), center + Vector3.new(halfX, 0, -halfZ) },
		{ center + Vector3.new(-halfX, 0, -halfZ), center + Vector3.new(-halfX, 0, -gateHalfWidth) },
		{ center + Vector3.new(-halfX, 0, gateHalfWidth), center + Vector3.new(-halfX, 0, halfZ) },
		{ center + Vector3.new(halfX, 0, -halfZ), center + Vector3.new(halfX, 0, halfZ) },
		{ center + Vector3.new(-halfX, 0, halfZ), center + Vector3.new(halfX, 0, halfZ) },
	}
	for index, endpoints in ipairs(fenceSegments) do
		createPalisadeLine(
			camp,
			string.format("Palisade%02d", index),
			endpoints[1],
			endpoints[2],
			18
		)
	end

	createHut(camp, "Hut01", center + Vector3.new(-65, 0, 22), 18)
	createHut(camp, "Hut02", center + Vector3.new(63, 0, 38), -22)
	createHut(camp, "Hut03", center + Vector3.new(45, 0, -54), 10)

	local ground = Grounding.surfaceAt(center)
	P.part(
		camp,
		"Campfire",
		Vector3.new(9, 2.5, 9),
		CFrame.new(ground + Vector3.new(0, 1.8, 0)),
		Enum.Material.Neon,
		COLORS.fire,
		{ canCollide = false, shape = Enum.PartType.Ball }
	)

	for index, offset in ipairs({
		Vector3.new(-28, 0, -17),
		Vector3.new(27, 0, 14),
		Vector3.new(-9, 0, 54),
	}) do
		createGoblin(camp, string.format("Goblin%02d", index), center + offset)
	end

	local lookout = positions.poi_goblin_lookout
	P.groundedPart(camp, "WatchTowerBase", lookout, Vector3.new(16, 22, 16), Enum.Material.WoodPlanks, COLORS.darkTimber)
	local lookoutGround = Grounding.surfaceAt(lookout)
	P.part(
		camp,
		"WatchPlatform",
		Vector3.new(24, 3, 24),
		CFrame.new(lookoutGround + Vector3.new(0, 23, 0)),
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
end

local function prepareSpiderHollowTerrain(positions: { [string]: Vector3 })
	local center = positions.poi_spider_hollow
	local shrine = positions.poi_fallen_shrine
	local terrain = Workspace.Terrain
	local floorTopY = center.Y + 6

	-- Spider Hollow is a low, damp basin. Keep the combat floor broad enough for
	-- the ten spiders, then build a real raised rim around it instead of leaving
	-- the encounter on the same flat plane as Moonfall Road.
	terrain:FillBlock(
		CFrame.new(center.X, floorTopY - 10, center.Z),
		Vector3.new(600, 20, 500),
		Enum.Material.Mud
	)

	local function ridge(name: string, offset: Vector3, size: Vector3, topOffset: number)
		local topY = floorTopY + topOffset
		terrain:FillBlock(
			CFrame.new(center.X + offset.X, topY - size.Y / 2, center.Z + offset.Z),
			size,
			Enum.Material.Ground
		)
	end

	-- Three closed sides plus two eastern shoulders leave one readable entrance
	-- from Moonfall Road while still reading as a bowl from inside.
	ridge("SpiderBasinRimWest", Vector3.new(-330, 0, 0), Vector3.new(180, 44, 650), 34)
	ridge("SpiderBasinRimSouth", Vector3.new(0, 0, -285), Vector3.new(760, 38, 150), 30)
	ridge("SpiderBasinRimNorth", Vector3.new(0, 0, 285), Vector3.new(760, 50, 170), 40)
	ridge("SpiderBasinRimEastSouth", Vector3.new(315, 0, -190), Vector3.new(155, 34, 230), 27)
	ridge("SpiderBasinRimEastNorth", Vector3.new(315, 0, 190), Vector3.new(155, 38, 230), 31)

	-- The north rim continues into the Fallen Shrine mountain mass so the hollow
	-- feels geologically embedded rather than like a fenced patch in a field.
	local northDistance = shrine.Z - center.Z
	for index, alpha in ipairs({ 0.42, 0.62, 0.80 }) do
		local z = center.Z + northDistance * alpha
		local rise = 42 + index * 13
		local radius = 150 + index * 18
		terrain:FillBall(
			Vector3.new(center.X - 35 + index * 18, floorTopY + rise - radius, z),
			radius,
			if index >= 2 then Enum.Material.Rock else Enum.Material.Ground
		)
	end
end

local function createSpiderWeb(
	parent: Instance,
	name: string,
	center: Vector3,
	yawDegrees: number,
	radius: number
)
	local web = P.model(parent, name)
	web:SetAttribute("Decorative", true)
	local right = CFrame.Angles(0, math.rad(yawDegrees), 0).RightVector
	local up = Vector3.yAxis
	local spokes = 6
	local options = { canCollide = false, transparency = 0.20 }

	local function pointAt(angle: number, r: number): Vector3
		return center + right * math.cos(angle) * r + up * math.sin(angle) * r
	end

	for index = 1, spokes do
		local angle = (index - 1) / spokes * math.pi * 2
		P.segment(
			web,
			string.format("Spoke%02d", index),
			center,
			pointAt(angle, radius),
			0.22,
			0.22,
			Enum.Material.SmoothPlastic,
			COLORS.web,
			options
		)
	end

	for ringIndex, fraction in ipairs({ 0.45, 0.78 }) do
		for index = 1, spokes do
			local a = (index - 1) / spokes * math.pi * 2
			local b = index / spokes * math.pi * 2
			P.segment(
				web,
				string.format("Ring%02d_%02d", ringIndex, index),
				pointAt(a, radius * fraction),
				pointAt(b, radius * fraction),
				0.18,
				0.18,
				Enum.Material.SmoothPlastic,
				COLORS.web,
				options
			)
		end
	end
end

local function createSpiderHollow(parent: Instance, positions: { [string]: Vector3 })
	local hollow = P.model(parent, "SpiderHollow")
	hollow:SetAttribute("ZoneId", "zone_spider_hollow")
	hollow:SetAttribute("BasinFloorFilled", true)
	local center = positions.poi_spider_hollow
	local cave = positions.poi_spider_cave_mouth

	for index, offset in ipairs({
		Vector3.new(-135, 0, -45),
		Vector3.new(-104, 0, 97),
		Vector3.new(-39, 0, 133),
		Vector3.new(81, 0, 117),
		Vector3.new(133, 0, 43),
		Vector3.new(124, 0, -88),
		Vector3.new(45, 0, -137),
		Vector3.new(-79, 0, -126),
	}) do
		createRock(
			hollow,
			string.format("PerimeterRock%02d", index),
			center + offset,
			Vector3.new(18 + index % 3 * 4, 12 + index % 4 * 3, 18 + index % 2 * 5)
		)
	end

	for index, offset in ipairs({
		Vector3.new(-92, 0, 43),
		Vector3.new(74, 0, 61),
		Vector3.new(43, 0, -83),
		Vector3.new(-59, 0, -74),
	}) do
		createTree(hollow, string.format("DeadTree%02d", index), center + offset, 26 + index * 2, true)
	end

	local caveGround = Grounding.surfaceAt(cave)
	P.part(hollow, "CavePillarLeft", Vector3.new(12, 28, 12), CFrame.new(caveGround + Vector3.new(-18, 14, 0)), Enum.Material.Rock, COLORS.darkStone)
	P.part(hollow, "CavePillarRight", Vector3.new(12, 28, 12), CFrame.new(caveGround + Vector3.new(18, 14, 0)), Enum.Material.Rock, COLORS.darkStone)
	P.part(hollow, "CaveLintel", Vector3.new(48, 10, 16), CFrame.new(caveGround + Vector3.new(0, 30, 0)), Enum.Material.Rock, COLORS.darkStone)

	createSpiderWeb(hollow, "Web01", caveGround + Vector3.new(-31, 13, -12), 18, 17)
	createSpiderWeb(hollow, "Web02", caveGround + Vector3.new(31, 12, 9), -22, 15)
	createSpiderWeb(hollow, "Web03", caveGround + Vector3.new(0, 17, 50), 4, 19)

	createSpider(hollow, "Spider01", center + Vector3.new(-27, 0, -9), 1)
	createSpider(hollow, "Spider02", center + Vector3.new(34, 0, 25), 1.1)
	createSpider(hollow, "Spider03", center + Vector3.new(5, 0, 65), 0.9)
end

local function createMoonfallLandmarks(parent: Instance, positions: { [string]: Vector3 })
	local props = P.model(parent, "MoonfallLandmarks")
	local wagon = positions.poi_broken_wagon
	P.groundedPart(props, "BrokenWagonBody", wagon, Vector3.new(18, 5, 10), Enum.Material.WoodPlanks, COLORS.timber)
	for index, dx in ipairs({ -8, 8 }) do
		local wheelPosition = wagon + Vector3.new(dx, 0, 5)
		local ground = Grounding.surfaceAt(wheelPosition)
		local wheel = P.part(
			props,
			string.format("BrokenWheel%02d", index),
			Vector3.new(1.5, 10, 10),
			CFrame.new(ground + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Enum.Material.Wood,
			COLORS.darkTimber,
			{ canCollide = false, shape = Enum.PartType.Cylinder }
		)
		wheel:SetAttribute("Decorative", true)
	end

	local waystone = positions.poi_old_waystone
	P.groundedPart(props, "OldWaystone", waystone, Vector3.new(7, 18, 5), Enum.Material.Slate, COLORS.stone)

	local crossroads = positions.poi_moonfall_crossroads
	P.groundedPart(props, "CrossroadsPost", crossroads + Vector3.new(12, 0, -8), Vector3.new(3, 13, 3), Enum.Material.Wood, COLORS.darkTimber)
end

local function shapeGoblinCemeteryLakeHillCliff(center: Vector3, waterSurfaceY: number)
	local terrain = Workspace.Terrain
	local cliffSegments = {
		{ xOffset = 300, zOffset = -35, zSize = 150 },
		{ xOffset = 320, zOffset = 105, zSize = 170 },
		{ xOffset = 285, zOffset = 235, zSize = 135 },
	}

	for _, spec in ipairs(cliffSegments) do
		local hillSample = Grounding.surfaceAt(
			center + Vector3.new(spec.xOffset + 70, 0, spec.zOffset)
		)
		local cliffBottomY = waterSurfaceY - 5
		local cliffTopY = math.max(hillSample.Y + 6, waterSurfaceY + 28)
		local cliffHeight = cliffTopY - cliffBottomY

		-- Cut away the grassy shelf on the lake side so the hill meets the water
		-- as a readable vertical bank rather than appearing to hover above it.
		terrain:FillBlock(
			CFrame.new(
				center.X + spec.xOffset - 24,
				cliffBottomY + cliffHeight / 2,
				center.Z + spec.zOffset
			),
			Vector3.new(64, cliffHeight, spec.zSize),
			Enum.Material.Air
		)
		terrain:FillBlock(
			CFrame.new(
				center.X + spec.xOffset + 10,
				cliffBottomY + cliffHeight / 2,
				center.Z + spec.zOffset
			),
			Vector3.new(20, cliffHeight, spec.zSize),
			Enum.Material.Rock
		)
	end
end

local function createGoblinCemeteryLake(parent: Instance, positions: { [string]: Vector3 })
	local lake = P.model(parent, "GoblinCemeteryLake")
	lake:SetAttribute("Purpose", "TraversalBarrier")
	local terrain = Workspace.Terrain

	local goblin = positions.poi_goblin_camp
	local cemetery = positions.poi_old_cemetery
	local center = goblin:Lerp(cemetery, 0.52) + Vector3.new(85, 0, 0)
	local ground = Grounding.surfaceAt(center)
	local LAKE_SURFACE_DROP = 8
	local LAKE_WATER_DEPTH = 12
	local LAKE_AIR_CLEARANCE_HEIGHT = 28
	local waterSurfaceY = ground.Y - LAKE_SURFACE_DROP

	local lobes = {
		{ offset = Vector3.new(-90, 0, -35), size = Vector3.new(420, 32, 300), yaw = -8 },
		{ offset = Vector3.new(90, 0, 45), size = Vector3.new(430, 32, 320), yaw = 10 },
		{ offset = Vector3.new(10, 0, 145), size = Vector3.new(330, 32, 240), yaw = -3 },
	}

	for index, spec in ipairs(lobes) do
		local position = center + spec.offset
		local rotation = CFrame.Angles(0, math.rad(spec.yaw), 0)
		terrain:FillBlock(
			CFrame.new(
				position.X,
				waterSurfaceY + LAKE_AIR_CLEARANCE_HEIGHT / 2 - 2,
				position.Z
			) * rotation,
			Vector3.new(spec.size.X, LAKE_AIR_CLEARANCE_HEIGHT, spec.size.Z),
			Enum.Material.Air
		)
		terrain:FillBlock(
			CFrame.new(position.X, waterSurfaceY - LAKE_WATER_DEPTH / 2, position.Z) * rotation,
			Vector3.new(spec.size.X, LAKE_WATER_DEPTH, spec.size.Z),
			Enum.Material.Water
		)

		P.part(
			lake,
			string.format("WaterRecovery%02d", index),
			Vector3.new(spec.size.X - 10, 20, spec.size.Z - 10),
			CFrame.new(position.X, waterSurfaceY - 4, position.Z) * rotation,
			Enum.Material.SmoothPlastic,
			Color3.new(1, 1, 1),
			{
				canCollide = false,
				transparency = 1,
				attributes = {
					WaterRecovery = true,
					WaterSurfaceY = waterSurfaceY,
					HazardKind = "Lake",
				},
			}
		)
	end

	shapeGoblinCemeteryLakeHillCliff(center, waterSurfaceY)
	lake:SetAttribute("WaterSurfaceDrop", LAKE_SURFACE_DROP)
	lake:SetAttribute("HillBankCliff", true)
end

local function createDarkWoodland(parent: Instance, positions: { [string]: Vector3 })
	local woodland = P.model(parent, "DarkWoodlandThreshold")
	woodland:SetAttribute("ZoneId", "zone_dark_woodland")
	local gate = positions.poi_dark_woodland_gate

	-- Apply the rocky threshold before tree placement so foliage validation sees
	-- the final terrain material and never leaves a trunk rooted in rock.
	P.replaceTerrainMaterials(
		gate + Vector3.new(-345, 0, 65),
		Vector3.new(280, 28, 190),
		{ Enum.Material.Grass, Enum.Material.LeafyGrass },
		Enum.Material.Rock
	)

	for index = 1, 11 do
		local x = 105 + (index - 1) * 48
		local zOffset = ((index % 3) - 1) * 26
		createTree(woodland, string.format("TreeLeft%02d", index), gate + Vector3.new(-x, 0, zOffset), 30 + index % 4 * 3)
		createTree(woodland, string.format("TreeRight%02d", index), gate + Vector3.new(x, 0, -zOffset), 31 + index % 5 * 3)
	end

	local entry = positions.entry_dark_woodland
	for index, offsetX in ipairs({ -70, 70 }) do
		P.groundedPart(
			woodland,
			string.format("GateStone%02d", index),
			entry + Vector3.new(offsetX, 0, 8),
			Vector3.new(14, 32, 14),
			Enum.Material.Slate,
			COLORS.darkStone
		)
	end
end

local function createCemetery(parent: Instance, positions: { [string]: Vector3 })
	local cemetery = P.model(parent, "OldCemetery")
	cemetery:SetAttribute("ZoneId", "zone_old_cemetery")
	local center = positions.poi_old_cemetery

	for row = -1, 1 do
		for col = -2, 2 do
			local index = (row + 1) * 5 + col + 3
			local pos = center + Vector3.new(col * 32, 0, row * 38)
			local grave = P.groundedPart(
				cemetery,
				string.format("Grave%02d", index),
				pos,
				Vector3.new(5, 10 + (index % 3) * 2, 3),
				Enum.Material.Slate,
				COLORS.stone
			)
			grave.CFrame *= CFrame.Angles(math.rad((index % 2) * 3), math.rad((index % 5 - 2) * 3), 0)
		end
	end

	local mausoleum = center + Vector3.new(0, 0, 102)
	P.groundedPart(cemetery, "Mausoleum", mausoleum, Vector3.new(46, 24, 32), Enum.Material.Limestone, COLORS.ancientStone)
	local mausoleumGround = Grounding.surfaceAt(mausoleum)
	P.part(
		cemetery,
		"MausoleumRoof",
		Vector3.new(52, 5, 38),
		CFrame.new(mausoleumGround + Vector3.new(0, 26.5, 0)),
		Enum.Material.Slate,
		COLORS.darkStone,
		{ canCollide = false }
	)
end

local function createShrine(parent: Instance, positions: { [string]: Vector3 })
	local shrine = P.model(parent, "FallenShrine")
	shrine:SetAttribute("ZoneId", "zone_fallen_shrine")
	local center = positions.poi_fallen_shrine

	P.groundedPart(shrine, "ShrinePlatform", center, Vector3.new(112, 1.2, 102), Enum.Material.Cobblestone, COLORS.ancientStone, { canCollide = false })
	for index, offset in ipairs({
		Vector3.new(-43, 0, -29),
		Vector3.new(0, 0, -36),
		Vector3.new(43, 0, -29),
		Vector3.new(-41, 0, 32),
		Vector3.new(41, 0, 32),
	}) do
		P.groundedPart(
			shrine,
			string.format("Column%02d", index),
			center + offset,
			Vector3.new(8, 26 - (index % 3) * 5, 8),
			Enum.Material.Limestone,
			COLORS.ancientStone
		)
	end
	P.groundedPart(shrine, "Altar", center + Vector3.new(0, 0, 20), Vector3.new(22, 7, 14), Enum.Material.Marble, COLORS.ancientStone)
end

local function createAncientApproach(parent: Instance, positions: { [string]: Vector3 })
	local approach = P.model(parent, "AncientApproach")
	approach:SetAttribute("ZoneId", "zone_ancient_approach")
	local center = positions.poi_ancient_approach

	for index, zOffset in ipairs({ -210, -120, -30, 70, 165 }) do
		local height = 26 + index * 5
		for _, xOffset in ipairs({ -78, 78 }) do
			P.groundedPart(
				approach,
				string.format("Pylon_%02d_%d", index, xOffset),
				center + Vector3.new(xOffset, 0, zOffset),
				Vector3.new(12 + index, height, 12 + index),
				Enum.Material.Limestone,
				COLORS.ancientStone
			)
		end
	end

	local north = center + Vector3.new(0, 0, 230)
	local northGround = Grounding.surfaceAt(north)
	P.part(approach, "SeleneGateLeft", Vector3.new(18, 52, 18), CFrame.new(northGround + Vector3.new(-46, 26, 0)), Enum.Material.Limestone, COLORS.ancientStone)
	P.part(approach, "SeleneGateRight", Vector3.new(18, 52, 18), CFrame.new(northGround + Vector3.new(46, 26, 0)), Enum.Material.Limestone, COLORS.ancientStone)
	P.part(approach, "SeleneGateLintel", Vector3.new(110, 12, 20), CFrame.new(northGround + Vector3.new(0, 52, 0)), Enum.Material.Limestone, COLORS.ancientStone)

	local horizon = positions.poi_selene_horizon
	for index, x in ipairs({ -95, 0, 95 }) do
		local monolithPosition = horizon + Vector3.new(x, 0, 0)
		P.groundedPart(
			approach,
			string.format("SeleneHorizonMonolith%02d", index),
			monolithPosition,
			Vector3.new(18, 75 + index * 12, 18),
			Enum.Material.Slate,
			COLORS.darkStone,
			{ canCollide = false, transparency = 0.18, attributes = { DistantSilhouette = true } }
		)
	end
end

function NorthernZonesBlockout.build(parent: Instance)
	local positions = poiPositions()
	prepareSpiderHollowTerrain(positions)
	local north = P.model(parent, "NorthWorld")

	createGroundedRoad(north, "MoonfallRoad", WorldLayout.MoonfallRoadRoute, 22)
	createGroundedRoad(north, "GoblinBranch", WorldLayout.GoblinCampRoute, 16)
	createGroundedRoad(north, "SpiderBranch", WorldLayout.SpiderHollowRoute, 16)
	createGroundedRoad(north, "SpiderReturn", WorldLayout.SpiderReturnRoute, 13)
	createGroundedRoad(north, "AncientApproachRoad", WorldLayout.AncientApproachRoute, 26, Enum.Material.Cobblestone)

	createMoonfallLandmarks(north, positions)
	createGoblinCamp(north, positions)
	createSpiderHollow(north, positions)
	createGoblinCemeteryLake(north, positions)
	createDarkWoodland(north, positions)
	createCemetery(north, positions)
	createShrine(north, positions)
	createAncientApproach(north, positions)
end

return table.freeze(NorthernZonesBlockout)
