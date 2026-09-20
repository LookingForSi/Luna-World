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

local function createCampPalisadeLine(
	parent: Instance,
	name: string,
	fromPosition: Vector3,
	toPosition: Vector3,
	postHeight: number
)
	local wall = P.model(parent, name)
	local horizontal = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local postSpacing = 4.0
	local segments = math.max(1, math.ceil(horizontal.Magnitude / postSpacing))
	local groundedPoints: { Vector3 } = {}

	for index = 0, segments do
		local authored = fromPosition:Lerp(toPosition, index / segments)
		local ground = Grounding.surfaceAt(authored)
		table.insert(groundedPoints, ground)
		local height = postHeight + ((index % 4) - 1.5) * 0.7
		P.part(
			wall,
			string.format("Stake%03d", index + 1),
			Vector3.new(3.4, height, 3.4),
			CFrame.new(ground + Vector3.new(0, height / 2 - 0.5, 0)),
			Enum.Material.Wood,
			COLORS.darkTimber
		)
	end

	for index = 1, #groundedPoints - 1 do
		local a = groundedPoints[index]
		local b = groundedPoints[index + 1]
		P.segment(
			wall,
			string.format("PalisadeCollision_%03d", index),
			a + Vector3.new(0, postHeight * 0.45, 0),
			b + Vector3.new(0, postHeight * 0.45, 0),
			2.0,
			postHeight * 0.9,
			Enum.Material.SmoothPlastic,
			Color3.new(1, 1, 1),
			{
				canCollide = true,
				transparency = 1,
				attributes = { PalisadeCollision = true },
			}
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
	local gateHalfWidth = 32

	-- Keep one readable guarded entrance on the authored road (west side).
	-- The wolf/forest side stays closed; this is a palisade, not the low rail fence
	-- that was removed in the previous pass.
	local fenceSegments = {
		{ center + Vector3.new(-halfX, 0, -halfZ), center + Vector3.new(halfX, 0, -halfZ) },
		{ center + Vector3.new(-halfX, 0, -halfZ), center + Vector3.new(-halfX, 0, -gateHalfWidth) },
		{ center + Vector3.new(-halfX, 0, gateHalfWidth), center + Vector3.new(-halfX, 0, halfZ) },
		{ center + Vector3.new(halfX, 0, -halfZ), center + Vector3.new(halfX, 0, halfZ) },
		{ center + Vector3.new(-halfX, 0, halfZ), center + Vector3.new(halfX, 0, halfZ) },
	}
	for index, endpoints in fenceSegments do
		createCampPalisadeLine(
			camp,
			string.format("CampPalisade%02d", index),
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

	-- Keep the accepted combat-floor elevation, but reshape the Hollow from a
	-- rectangular basin into a long rounded pocket following the east-west road.
	-- The central block gives the encounter a stable fighting surface; the two
	-- cylinders round the ends so the mud footprint reads as an oval/capsule from above.
	local floorDepth = 20
	local floorHalfLength = 170
	local floorRadius = 135
	terrain:FillBlock(
		CFrame.new(center.X, floorTopY - floorDepth / 2, center.Z),
		Vector3.new(floorHalfLength * 2, floorDepth, floorRadius * 2),
		Enum.Material.Mud
	)
	for _, xOffset in ipairs({ -floorHalfLength, floorHalfLength }) do
		terrain:FillCylinder(
			CFrame.new(center.X + xOffset, floorTopY - floorDepth / 2, center.Z),
			floorDepth,
			floorRadius,
			Enum.Material.Mud
		)
	end

	-- Shape each long side as one continuous curved hill rather than a row of
	-- visually separate mounds. Dense overlapping caps follow a gentle arc; the
	-- spacing is deliberately much smaller than the radius so the silhouette
	-- reads as one ridge from inside the Hollow and from the road.
	local function fillCurvedRidge(points: { Vector3 }, radius: number, rise: number): ()
		for index = 1, #points - 1 do
			local a = points[index]
			local b = points[index + 1]
			local horizontal = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
			local steps = math.max(1, math.ceil(horizontal.Magnitude / 42))
			for step = 0, steps - 1 do
				local alpha = step / steps
				local point = a:Lerp(b, alpha)
				terrain:FillBall(
					Vector3.new(point.X, floorTopY + rise - radius, point.Z),
					radius,
					Enum.Material.Ground
				)
			end
		end
		local last = points[#points]
		terrain:FillBall(
			Vector3.new(last.X, floorTopY + rise - radius, last.Z),
			radius,
			Enum.Material.Ground
		)
	end

	local northRidge = {
		center + Vector3.new(-250, 0, 175),
		center + Vector3.new(-165, 0, 205),
		center + Vector3.new(-55, 0, 218),
		center + Vector3.new(60, 0, 212),
		center + Vector3.new(155, 0, 182),
	}
	local southRidge = {
		center + Vector3.new(-250, 0, -170),
		center + Vector3.new(-165, 0, -202),
		center + Vector3.new(-55, 0, -216),
		center + Vector3.new(60, 0, -207),
		center + Vector3.new(155, 0, -176),
	}
	fillCurvedRidge(northRidge, 205, 27)
	fillCurvedRidge(southRidge, 200, 25)

	-- One broad western connector closes the back of the oval while keeping the
	-- eastern road entrance low and readable.
	fillCurvedRidge({
		center + Vector3.new(-235, 0, -155),
		center + Vector3.new(-292, 0, -78),
		center + Vector3.new(-310, 0, 0),
		center + Vector3.new(-292, 0, 82),
		center + Vector3.new(-235, 0, 160),
	}, 210, 29)

	-- Blend the northern shoulder into the Fallen Shrine mass with overlapping
	-- smooth terrain instead of a hard ridge. This preserves the geological link
	-- between the two zones without making the Hollow feel like a square crater.
	local northDistance = shrine.Z - center.Z
	for index, alpha in ipairs({ 0.46, 0.64, 0.81 }) do
		local z = center.Z + northDistance * alpha
		local radius = 175 + index * 18
		local rise = 28 + index * 9
		terrain:FillBall(
			Vector3.new(center.X - 55 + index * 22, floorTopY + rise - radius, z),
			radius,
			if index >= 3 then Enum.Material.Rock else Enum.Material.Ground
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

local function prepareGoblinCampBoundaryShelf(positions: { [string]: Vector3 })
	local terrain = Workspace.Terrain
	local center = positions.poi_goblin_camp
	local bounds = WorldLayout.WorldBounds
	local campGround = Grounding.surfaceAt(center)
	local shelfTopY = campGround.Y

	-- Keep the raised camp-side plateau at its accepted elevation all the way to
	-- the outer map boundary. The inner/lake-facing edge is then blended down with
	-- broad overlapping terrain caps instead of ending as a vertical FillBlock wall.
	local shelfStartX = center.X + 145
	local shelfEndX = bounds.maxX - 12
	local shelfCenterX = (shelfStartX + shelfEndX) / 2
	local shelfWidth = shelfEndX - shelfStartX
	local shelfMinZ = center.Z - 250
	local shelfMaxZ = center.Z + 165
	local shelfDepth = shelfMaxZ - shelfMinZ

	terrain:FillBlock(
		CFrame.new(shelfCenterX, shelfTopY + 28, (shelfMinZ + shelfMaxZ) / 2),
		Vector3.new(shelfWidth, 56, shelfDepth),
		Enum.Material.Air
	)
	terrain:FillBlock(
		CFrame.new(shelfCenterX, shelfTopY - 45, (shelfMinZ + shelfMaxZ) / 2),
		Vector3.new(shelfWidth, 90, shelfDepth),
		Enum.Material.Grass
	)

	-- A continuous gentle shoulder from plateau level down toward the lake.
	-- Dense overlap makes the result read as one long natural slope rather than
	-- terraces or a row of separate mounds.
	local slopeRadius = 105
	local slopeRows = {
		{ x = shelfStartX + 25, top = shelfTopY + 1 },
		{ x = shelfStartX - 35, top = shelfTopY - 5 },
		{ x = shelfStartX - 95, top = shelfTopY - 13 },
		{ x = shelfStartX - 155, top = shelfTopY - 23 },
		{ x = shelfStartX - 205, top = shelfTopY - 32 },
	}
	for _, row in ipairs(slopeRows) do
		for z = shelfMinZ - 25, shelfMaxZ + 25, 58 do
			terrain:FillBall(
				Vector3.new(row.x, row.top - slopeRadius, z),
				slopeRadius,
				Enum.Material.Grass
			)
		end
	end
end

local function carveLakeDisc(
	terrain: Terrain,
	position: Vector3,
	radius: number,
	waterSurfaceY: number,
	waterDepth: number,
	clearDepth: number,
	airClearance: number,
	shoreMargin: number
)
	-- Excavate slightly beyond the water radius so grass/rock never survives
	-- immediately under the transparent water surface.
	local totalClearHeight = clearDepth + airClearance
	local clearCenterY = waterSurfaceY + (airClearance - clearDepth) / 2
	terrain:FillCylinder(
		CFrame.new(position.X, clearCenterY, position.Z),
		totalClearHeight,
		radius + shoreMargin,
		Enum.Material.Air
	)
	terrain:FillCylinder(
		CFrame.new(position.X, waterSurfaceY - waterDepth / 2, position.Z),
		waterDepth,
		radius,
		Enum.Material.Water
	)
end

local function fillContinuousLakePath(
	terrain: Terrain,
	points: { { position: Vector3, radius: number } },
	waterSurfaceY: number,
	waterDepth: number,
	clearDepth: number,
	airClearance: number,
	shoreMargin: number
)
	for index = 1, #points - 1 do
		local a = points[index]
		local b = points[index + 1]
		local delta = Vector3.new(
			b.position.X - a.position.X,
			0,
			b.position.Z - a.position.Z
		)
		-- Sample much more densely than the local radius. Overlap is intentional:
		-- Terrain.Water becomes one body with no dry seam between generated parts.
		local steps = math.max(1, math.ceil(delta.Magnitude / 34))
		for step = 0, steps - 1 do
			local alpha = step / steps
			local point = a.position:Lerp(b.position, alpha)
			local radius = a.radius + (b.radius - a.radius) * alpha
			carveLakeDisc(
				terrain,
				point,
				radius,
				waterSurfaceY,
				waterDepth,
				clearDepth,
				airClearance,
				shoreMargin
			)
		end
	end
	local last = points[#points]
	carveLakeDisc(
		terrain,
		last.position,
		last.radius,
		waterSurfaceY,
		waterDepth,
		clearDepth,
		airClearance,
		shoreMargin
	)
end

local function createGoblinCemeteryLake(parent: Instance, positions: { [string]: Vector3 })
	local lake = P.model(parent, "GoblinCemeteryLake")
	lake:SetAttribute("Purpose", "SwimmableWater")
	local terrain = Workspace.Terrain

	local goblin = positions.poi_goblin_camp
	local cemetery = positions.poi_old_cemetery
	local center = goblin:Lerp(cemetery, 0.52) + Vector3.new(85, 0, 0)
	local ground = Grounding.surfaceAt(center)
	local bounds = WorldLayout.WorldBounds
	local LAKE_SURFACE_DROP = 8
	local LAKE_WATER_DEPTH = 30
	local LAKE_BASIN_CLEAR_DEPTH = 42
	local LAKE_AIR_CLEARANCE_HEIGHT = 48
	local LAKE_SHORE_CLEAR_MARGIN = 18
	local waterSurfaceY = ground.Y - LAKE_SURFACE_DROP

	-- One organic shoreline/path from the camp side through the original lake and
	-- out to the invisible map boundary. Different radii bend the shoreline and
	-- deliberately avoid a rectangular silhouette.
	local edgeX = bounds.maxX + 80
	local lakePath = {
		{ position = goblin + Vector3.new(205, 0, 175), radius = 115 },
		{ position = center + Vector3.new(-155, 0, -105), radius = 155 },
		{ position = center + Vector3.new(-55, 0, 10), radius = 205 },
		{ position = center + Vector3.new(55, 0, 105), radius = 220 },
		{ position = center + Vector3.new(150, 0, 190), radius = 185 },
		{ position = Vector3.new(edgeX - 145, center.Y, center.Z + 225), radius = 205 },
		{ position = Vector3.new(edgeX, center.Y, center.Z + 195), radius = 235 },
	}
	fillContinuousLakePath(
		terrain,
		lakePath,
		waterSurfaceY,
		LAKE_WATER_DEPTH,
		LAKE_BASIN_CLEAR_DEPTH,
		LAKE_AIR_CLEARANCE_HEIGHT,
		LAKE_SHORE_CLEAR_MARGIN
	)

	-- Widen the central swimming pocket without introducing another independent
	-- water rectangle; these discs heavily overlap the same continuous body.
	local swimmingPocket = {
		{ position = center + Vector3.new(-95, 0, 85), radius = 175 },
		{ position = center + Vector3.new(20, 0, 145), radius = 205 },
		{ position = center + Vector3.new(115, 0, 115), radius = 175 },
	}
	fillContinuousLakePath(
		terrain,
		swimmingPocket,
		waterSurfaceY,
		LAKE_WATER_DEPTH,
		LAKE_BASIN_CLEAR_DEPTH,
		LAKE_AIR_CLEARANCE_HEIGHT,
		LAKE_SHORE_CLEAR_MARGIN
	)

	lake:SetAttribute("ExtendsToWorldEdge", true)
	lake:SetAttribute("ContinuousWaterBody", true)
	lake:SetAttribute("OrganicShoreline", true)
	lake:SetAttribute("WaterSurfaceDrop", LAKE_SURFACE_DROP)
	lake:SetAttribute("WaterDepth", LAKE_WATER_DEPTH)
	lake:SetAttribute("DeepBasinExcavated", true)
	lake:SetAttribute("OpenWaterBoundary", true)
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
	prepareGoblinCampBoundaryShelf(positions)
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
