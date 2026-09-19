--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local Grounding = require(script.Parent.TerrainGrounding)
local P = require(script.Parent.BlockoutPrimitives)

local VillageAndMeadowsBlockout = {}

local COLORS = {
	stone = Color3.fromRGB(105, 106, 101),
	darkStone = Color3.fromRGB(72, 74, 72),
	timber = Color3.fromRGB(104, 75, 50),
	darkTimber = Color3.fromRGB(72, 54, 40),
	roof = Color3.fromRGB(70, 65, 67),
	road = Color3.fromRGB(122, 106, 82),
	water = Color3.fromRGB(48, 94, 108),
	hay = Color3.fromRGB(174, 151, 76),
	sheep = Color3.fromRGB(224, 220, 205),
	wolf = Color3.fromRGB(96, 98, 101),
	npc = Color3.fromRGB(103, 139, 151),
}

local function poiPositions(): { [string]: Vector3 }
	local result: { [string]: Vector3 } = {}
	for _, poi in ipairs(WorldLayout.PointsOfInterest) do
		result[poi.id] = poi.position
	end
	return result
end

local function spawnPositions(): { [string]: Vector3 }
	local result: { [string]: Vector3 } = {}
	for _, spawn in ipairs(WorldLayout.SpawnMarkers) do
		result[spawn.id] = spawn.position
	end
	return result
end

local function rotate(part: BasePart, yawDegrees: number)
	part.CFrame *= CFrame.Angles(0, math.rad(yawDegrees), 0)
end

local function createHouse(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	yaw: number
): Model
	local model = P.model(parent, name)
	local body = P.groundedPart(model, "Body", position, size, Enum.Material.WoodPlanks, COLORS.timber)
	rotate(body, yaw)

	local roofPosition = position + Vector3.new(0, size.Y, 0)
	local roof = P.groundedPart(
		model,
		"Roof",
		roofPosition,
		Vector3.new(size.X + 4, 4, size.Z + 4),
		Enum.Material.Slate,
		COLORS.roof,
		{ canCollide = false }
	)
	roof.CFrame = body.CFrame * CFrame.new(0, size.Y / 2 + 2, 0)

	return model
end

local function createSimpleNpc(parent: Instance, name: string, position: Vector3)
	local model = P.model(parent, name)
	local ground = Grounding.surfaceAt(position)
	P.part(
		model,
		"Body",
		Vector3.new(3, 5, 2),
		CFrame.new(ground + Vector3.new(0, 3.5, 0)),
		Enum.Material.SmoothPlastic,
		COLORS.npc,
		{ canCollide = false, attributes = { Decorative = true } }
	)
	P.part(
		model,
		"Head",
		Vector3.new(2.4, 2.4, 2.4),
		CFrame.new(ground + Vector3.new(0, 7, 0)),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(190, 166, 142),
		{ canCollide = false, shape = Enum.PartType.Ball, attributes = { Decorative = true } }
	)
end

local function createSheep(parent: Instance, name: string, position: Vector3)
	local model = P.model(parent, name)
	local ground = Grounding.surfaceAt(position)
	P.part(
		model,
		"Body",
		Vector3.new(6, 4, 8),
		CFrame.new(ground + Vector3.new(0, 3, 0)),
		Enum.Material.SmoothPlastic,
		COLORS.sheep,
		{ canCollide = false, attributes = { Decorative = true } }
	)
	P.part(
		model,
		"Head",
		Vector3.new(3, 3, 3),
		CFrame.new(ground + Vector3.new(0, 3.3, -5)),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(82, 78, 74),
		{ canCollide = false, shape = Enum.PartType.Ball, attributes = { Decorative = true } }
	)
end

local function createWolf(parent: Instance, name: string, position: Vector3, yaw: number)
	local model = P.model(parent, name)
	model:SetAttribute("Purpose", "MobPlaceholder")
	model:SetAttribute("MobId", "mob_young_wolf")

	local ground = Grounding.surfaceAt(position)
	local body = P.part(
		model,
		"Body",
		Vector3.new(4.5, 3.3, 8),
		CFrame.new(ground + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(yaw), 0),
		Enum.Material.SmoothPlastic,
		COLORS.wolf,
		{ canCollide = false }
	)
	P.part(
		model,
		"Head",
		Vector3.new(3.2, 3.2, 3.2),
		body.CFrame * CFrame.new(0, 0.7, -5),
		Enum.Material.SmoothPlastic,
		COLORS.wolf,
		{ canCollide = false, shape = Enum.PartType.Ball }
	)
	for index, offset in ipairs({
		Vector3.new(-1.5, -2.2, -2.2),
		Vector3.new(1.5, -2.2, -2.2),
		Vector3.new(-1.5, -2.2, 2.2),
		Vector3.new(1.5, -2.2, 2.2),
	}) do
		P.part(
			model,
			string.format("Leg%02d", index),
			Vector3.new(1, 3.5, 1),
			body.CFrame * CFrame.new(offset),
			Enum.Material.SmoothPlastic,
			COLORS.wolf,
			{ canCollide = false }
		)
	end
end

local function createGroundedRoad(parent: Instance, name: string, points: { Vector3 }, width: number)
	local folder = P.folder(parent, name)
	local segmentIndex = 0

	for routeIndex = 1, #points - 1 do
		local start = points[routeIndex]
		local finish = points[routeIndex + 1]
		local horizontal = Vector3.new(finish.X - start.X, 0, finish.Z - start.Z)
		local divisions = math.max(1, math.ceil(horizontal.Magnitude / 70))

		for step = 1, divisions do
			local alpha0 = (step - 1) / divisions
			local alpha1 = step / divisions
			local authoredA = start:Lerp(finish, alpha0)
			local authoredB = start:Lerp(finish, alpha1)
			segmentIndex += 1
			P.paintTerrainStrip(authoredA, authoredB, width + 6, Enum.Material.Ground)
			P.groundedSegment(
				folder,
				string.format("Road%03d", segmentIndex),
				authoredA,
				authoredB,
				width,
				0.35,
				Enum.Material.Ground,
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
		local height = postHeight + ((index % 3) - 1) * 0.8
		P.part(
			wall,
			string.format("Stake%03d", index + 1),
			Vector3.new(3.1, height, 3.1),
			CFrame.new(ground + Vector3.new(0, height / 2 - 0.5, 0)),
			Enum.Material.Wood,
			COLORS.darkTimber
		)
	end
end

local function createVillage(parent: Instance, positions: { [string]: Vector3 })
	local village = P.model(parent, "LunaVillage")
	village:SetAttribute("ZoneId", "zone_luna_village")

	local gate = positions.poi_main_gate
	P.groundedPart(village, "GatePostLeft", gate + Vector3.new(-13, 0, 0), Vector3.new(5, 20, 5), Enum.Material.Wood, COLORS.darkTimber)
	P.groundedPart(village, "GatePostRight", gate + Vector3.new(13, 0, 0), Vector3.new(5, 20, 5), Enum.Material.Wood, COLORS.darkTimber)
	local gateGround = Grounding.surfaceAt(gate)
	P.part(village, "GateLintel", Vector3.new(31, 4, 6), CFrame.new(gateGround + Vector3.new(0, 18, 0)), Enum.Material.Wood, COLORS.darkTimber)

	-- Luna Village is a visibly protected safe settlement. The perimeter uses the
	-- same visual height as the gate while preserving a clear main entrance.
	local westFront = gate + Vector3.new(-310, 0, 0)
	local eastFront = gate + Vector3.new(310, 0, 0)
	local westRear = gate + Vector3.new(-310, 0, -520)
	local eastRear = gate + Vector3.new(310, 0, -520)
	createPalisadeLine(village, "VillagePalisadeNorthWest", westFront, gate + Vector3.new(-24, 0, 0), 18)
	createPalisadeLine(village, "VillagePalisadeNorthEast", gate + Vector3.new(24, 0, 0), eastFront, 18)
	createPalisadeLine(village, "VillagePalisadeWest", westFront, westRear, 18)
	createPalisadeLine(village, "VillagePalisadeEast", eastFront, eastRear, 18)
	createPalisadeLine(village, "VillagePalisadeSouth", westRear, eastRear, 18)

	local square = positions.poi_village_square
	P.groundedPart(village, "Square", square, Vector3.new(58, 0.8, 52), Enum.Material.Cobblestone, COLORS.stone, { canCollide = false })
	P.groundedPart(village, "WellBase", square + Vector3.new(0, 0, 4), Vector3.new(10, 4, 10), Enum.Material.Cobblestone, COLORS.stone)
	P.groundedPart(village, "WellPost", square + Vector3.new(0, 0, 4), Vector3.new(2, 8, 2), Enum.Material.Wood, COLORS.darkTimber)

	createHouse(village, "Blacksmith", positions.poi_blacksmith, Vector3.new(38, 19, 28), -12)
	createHouse(village, "ElderHouse", positions.poi_elder_house, Vector3.new(42, 23, 32), 8)
	createHouse(village, "ResidenceA", positions.poi_residential + Vector3.new(-18, 0, 0), Vector3.new(26, 17, 22), -8)
	createHouse(village, "ResidenceB", positions.poi_residential + Vector3.new(18, 0, 16), Vector3.new(24, 16, 20), 10)

	local merchant = positions.poi_merchant
	P.groundedPart(village, "MerchantCounter", merchant, Vector3.new(24, 7, 14), Enum.Material.WoodPlanks, COLORS.timber)
	local canopy = P.groundedPart(village, "MerchantCanopy", merchant + Vector3.new(0, 8, 0), Vector3.new(28, 2, 18), Enum.Material.Fabric, Color3.fromRGB(132, 93, 66), { canCollide = false })
	local merchantGround = Grounding.surfaceAt(merchant)
	canopy.CFrame = CFrame.new(merchantGround + Vector3.new(0, 10, 0))

	local training = positions.poi_training_ground
	for index, dx in ipairs({ -16, 0, 16 }) do
		P.groundedPart(village, string.format("TrainingPost%02d", index), training + Vector3.new(dx, 0, 0), Vector3.new(2, 9, 2), Enum.Material.Wood, COLORS.darkTimber)
	end

	local shrine = positions.poi_shrine
	P.groundedPart(village, "VillageShrine", shrine, Vector3.new(22, 12, 18), Enum.Material.Limestone, Color3.fromRGB(136, 136, 128))

	createSimpleNpc(village, "VillageNpc01", square + Vector3.new(16, 0, -12))
	createSimpleNpc(village, "VillageNpc02", merchant + Vector3.new(-10, 0, 12))
end

local function createFenceLine(parent: Instance, name: string, fromPosition: Vector3, toPosition: Vector3)
	local fence = P.model(parent, name)
	local horizontal = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	local segments = math.max(1, math.ceil(horizontal.Magnitude / 14))
	local groundedPoints: { Vector3 } = {}

	for index = 0, segments do
		local authored = fromPosition:Lerp(toPosition, index / segments)
		local ground = Grounding.surfaceAt(authored)
		table.insert(groundedPoints, ground)
		P.part(
			fence,
			string.format("Post%02d", index + 1),
			Vector3.new(1.5, 6.5, 1.5),
			CFrame.new(ground + Vector3.new(0, 3.0, 0)),
			Enum.Material.Wood,
			COLORS.darkTimber
		)
	end

	for index = 1, #groundedPoints - 1 do
		local a = groundedPoints[index]
		local b = groundedPoints[index + 1]
		for railIndex, y in ipairs({ 2.2, 4.5 }) do
			P.segment(
				fence,
				string.format("Rail_%02d_%02d", index, railIndex),
				a + Vector3.new(0, y, 0),
				b + Vector3.new(0, y, 0),
				0.65,
				0.65,
				Enum.Material.Wood,
				COLORS.timber,
				{ canCollide = false }
			)
		end
	end
end

local function createFarm(parent: Instance, positions: { [string]: Vector3 }, spawns: { [string]: Vector3 })
	local farm = P.model(parent, "MoonfallFarm")
	farm:SetAttribute("StableId", "poi_moonfall_farm")
	local center = positions.poi_moonfall_farm

	createHouse(farm, "Farmhouse", center + Vector3.new(-42, 0, -26), Vector3.new(38, 18, 28), -8)
	createHouse(farm, "Barn", center + Vector3.new(44, 0, -18), Vector3.new(48, 22, 34), 5)
	P.groundedPart(farm, "Well", center + Vector3.new(-54, 0, 30), Vector3.new(10, 5, 10), Enum.Material.Cobblestone, COLORS.stone)

	local penCenter = center + Vector3.new(14, 0, 46)
	local halfX, halfZ = 42, 31
	local corners = {
		penCenter + Vector3.new(-halfX, 0, -halfZ),
		penCenter + Vector3.new(halfX, 0, -halfZ),
		penCenter + Vector3.new(halfX, 0, halfZ),
		penCenter + Vector3.new(-halfX, 0, halfZ),
	}
	for index = 1, 4 do
		local nextIndex = index % 4 + 1
		createFenceLine(
			farm,
			string.format("PenFence%02d", index),
			corners[index],
			corners[nextIndex]
		)
	end

	for index, offset in ipairs({
		Vector3.new(-18, 0, 38),
		Vector3.new(4, 0, 50),
		Vector3.new(24, 0, 38),
	}) do
		createSheep(farm, string.format("Sheep%02d", index), center + offset)
	end

	for index, offset in ipairs({
		Vector3.new(-5, 0, -4),
		Vector3.new(21, 0, 8),
	}) do
		createSimpleNpc(farm, string.format("FarmNpc%02d", index), center + offset)
	end

	for index, offset in ipairs({
		Vector3.new(-70, 0, 22),
		Vector3.new(62, 0, 42),
		Vector3.new(76, 0, -34),
	}) do
		P.groundedPart(
			farm,
			string.format("Hay%02d", index),
			center + offset,
			Vector3.new(11, 8, 9),
			Enum.Material.Grass,
			COLORS.hay
		)
	end

	local wolfCenter = spawns.spawn_young_wolf_farm
	if wolfCenter ~= nil then
		createWolf(farm, "YoungWolf01", wolfCenter + Vector3.new(-18, 0, 8), 20)
		createWolf(farm, "YoungWolf02", wolfCenter + Vector3.new(20, 0, -8), -35)
		createWolf(farm, "YoungWolf03", wolfCenter + Vector3.new(8, 0, 24), 150)
	end
end

local function createRiver(parent: Instance, positions: { [string]: Vector3 })
	local river = P.model(parent, "RiverAndBridge")
	local bridge = positions.poi_meadow_bridge
	local terrain = Workspace.Terrain

	local WATER_SURFACE_Y = 4
	local WATER_DEPTH = 5
	local WATER_WIDTH = 124
	local RECOVERY_WIDTH = 94
	local RECOVERY_TOP_Y = 7

	terrain.WaterColor = COLORS.water
	terrain.WaterTransparency = 0.28
	terrain.WaterReflectance = 0.08
	terrain.WaterWaveSize = 0.12
	terrain.WaterWaveSpeed = 7

	local function riverZ(x: number): number
		return bridge.Z + 0.065 * (x - bridge.X) + 28 * math.sin((x + 180) / 280)
	end

	local previous = Vector3.new(-1240, WATER_SURFACE_Y, riverZ(-1240))
	local index = 0
	for x = -1160, 1240, 80 do
		index += 1
		local current = Vector3.new(x, WATER_SURFACE_Y, riverZ(x))
		local offset = current - previous
		local midpoint = previous + offset / 2

		-- Use actual Roblox Terrain water for the preview instead of a bright glass ribbon.
		-- Short overlapping segments hide seams while keeping the authored river curve.
		local fillCenter = Vector3.new(midpoint.X, WATER_SURFACE_Y - WATER_DEPTH / 2, midpoint.Z)
		local fillTarget = Vector3.new(current.X, fillCenter.Y, current.Z)
		terrain:FillBlock(
			CFrame.lookAt(fillCenter, fillTarget),
			Vector3.new(WATER_WIDTH, WATER_DEPTH, offset.Magnitude + 12),
			Enum.Material.Water
		)

		-- Invisible recovery volume. A player who falls into the river is returned to the
		-- most recent grounded safe position rather than being trapped below the banks.
		local recoveryCenterY = RECOVERY_TOP_Y - 12
		P.segment(
			river,
			string.format("WaterRecovery%02d", index),
			Vector3.new(previous.X, recoveryCenterY, previous.Z),
			Vector3.new(current.X, recoveryCenterY, current.Z),
			RECOVERY_WIDTH,
			24,
			Enum.Material.SmoothPlastic,
			Color3.new(1, 1, 1),
			{
				canCollide = false,
				transparency = 1,
				attributes = {
					WaterRecovery = true,
					WaterSurfaceY = WATER_SURFACE_Y,
				},
			}
		)
		previous = current
	end

	-- Two broad sandy access points break up the otherwise continuous grass bank.
	-- They are terrain material swaps only: geometry and the river route remain unchanged.
	for _, beach in ipairs({
		{ name = "RiverSandApproachWest", x = -720, bankOffset = -72 },
		{ name = "RiverSandApproachEast", x = 650, bankOffset = 74 },
	}) do
		local beachCenter = Vector3.new(beach.x, 6, riverZ(beach.x) + beach.bankOffset)
		P.replaceTerrainMaterials(
			beachCenter,
			Vector3.new(230, 28, 180),
			{ Enum.Material.Grass, Enum.Material.LeafyGrass, Enum.Material.Ground },
			Enum.Material.Sand
		)
		river:SetAttribute(beach.name, true)
	end

	-- The bridge is deliberately overbuilt into both banks. The dirt aprons overlap
	-- terrain and the wider wooden approaches overlap the deck, so there is no
	-- character-sized crack that can trap a no-jump player.
	local southApronOuter = bridge + Vector3.new(0, 0, -118)
	local southApronInner = bridge + Vector3.new(0, 0, -78)
	local northApronInner = bridge + Vector3.new(0, 0, 78)
	local northApronOuter = bridge + Vector3.new(0, 0, 118)

	P.groundedSegment(
		river,
		"BridgeBankApronSouth",
		southApronOuter,
		southApronInner,
		50,
		1.8,
		Enum.Material.Ground,
		COLORS.road
	)
	P.groundedSegment(
		river,
		"BridgeBankApronNorth",
		northApronInner,
		northApronOuter,
		50,
		1.8,
		Enum.Material.Ground,
		COLORS.road
	)

	local southBank = Grounding.surfaceAt(bridge + Vector3.new(0, 0, -86))
	local northBank = Grounding.surfaceAt(bridge + Vector3.new(0, 0, 86))
	local deckCenterY = math.max(southBank.Y, northBank.Y) + 2.2
	local deckSouth = Vector3.new(bridge.X, deckCenterY, bridge.Z - 46)
	local deckNorth = Vector3.new(bridge.X, deckCenterY, bridge.Z + 46)

	P.segment(river, "BridgeDeck", deckSouth, deckNorth, 36, 3.2, Enum.Material.WoodPlanks, COLORS.timber)
	P.segment(
		river,
		"BridgeApproachSouth",
		southBank + Vector3.new(0, 1.6, 0),
		deckSouth,
		42,
		3.2,
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
	P.segment(
		river,
		"BridgeApproachNorth",
		deckNorth,
		northBank + Vector3.new(0, 1.6, 0),
		42,
		3.2,
		Enum.Material.WoodPlanks,
		COLORS.timber
	)

	for _, sideX in ipairs({ -15, 15 }) do
		P.segment(
			river,
			"BridgeRail",
			Vector3.new(bridge.X + sideX, deckCenterY + 4, bridge.Z - 45),
			Vector3.new(bridge.X + sideX, deckCenterY + 4, bridge.Z + 45),
			1.5,
			3,
			Enum.Material.Wood,
			COLORS.darkTimber,
			{ canCollide = false }
		)
	end
end

local function createStoneCircle(parent: Instance, positions: { [string]: Vector3 }, spawns: { [string]: Vector3 })
	local center = positions.poi_stone_circle
	local circle = P.model(parent, "StoneCircle")
	for index = 1, 7 do
		local angle = (index - 1) * math.pi * 2 / 7
		local offset = Vector3.new(math.cos(angle) * 28, 0, math.sin(angle) * 28)
		local stone = P.groundedPart(
			circle,
			string.format("StandingStone%02d", index),
			center + offset,
			Vector3.new(6, 17 + (index % 3) * 2, 7),
			Enum.Material.Slate,
			COLORS.stone
		)
		stone.CFrame *= CFrame.Angles(math.rad((index % 2) * 4), -angle, math.rad((index % 3 - 1) * 3))
	end

	local wolfCenter = spawns.spawn_wolf_stone_circle
	if wolfCenter ~= nil then
		createWolf(circle, "GreyWolf01", wolfCenter + Vector3.new(-16, 0, 4), 30)
		createWolf(circle, "GreyWolf02", wolfCenter + Vector3.new(18, 0, -10), -80)
	end
end

local function createSpawn(parent: Instance, positions: { [string]: Vector3 }): SpawnLocation
	local spawnPosition = positions.poi_village_square
	local ground = Grounding.surfaceAt(spawnPosition)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LunaVillageSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	local spawnCenter = ground + Vector3.new(0, 1.2, 0)
	local facingTarget = positions.poi_main_gate
	spawn.CFrame = CFrame.lookAt(
		spawnCenter,
		Vector3.new(facingTarget.X, spawnCenter.Y, facingTarget.Z)
	)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = parent
	return spawn
end

function VillageAndMeadowsBlockout.build(parent: Instance): SpawnLocation
	local positions = poiPositions()
	local spawns = spawnPositions()
	local south = P.model(parent, "SouthWorld")

	createGroundedRoad(south, "VillageMeadowsRoad", WorldLayout.Route, 20)
	createRiver(south, positions)
	createVillage(south, positions)
	createFarm(south, positions, spawns)
	createStoneCircle(south, positions, spawns)

	return createSpawn(south, positions)
end

return table.freeze(VillageAndMeadowsBlockout)
