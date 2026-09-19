--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	water = Color3.fromRGB(74, 135, 165),
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

local function createVillage(parent: Instance, positions: { [string]: Vector3 })
	local village = P.model(parent, "LunaVillage")
	village:SetAttribute("ZoneId", "zone_luna_village")

	local gate = positions.poi_main_gate
	P.groundedPart(village, "GatePostLeft", gate + Vector3.new(-13, 0, 0), Vector3.new(5, 20, 5), Enum.Material.Wood, COLORS.darkTimber)
	P.groundedPart(village, "GatePostRight", gate + Vector3.new(13, 0, 0), Vector3.new(5, 20, 5), Enum.Material.Wood, COLORS.darkTimber)
	local gateGround = Grounding.surfaceAt(gate)
	P.part(village, "GateLintel", Vector3.new(31, 4, 6), CFrame.new(gateGround + Vector3.new(0, 18, 0)), Enum.Material.Wood, COLORS.darkTimber)

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
		P.groundedSegment(
			farm,
			string.format("PenFence%02d", index),
			corners[index],
			corners[nextIndex],
			2,
			5,
			Enum.Material.Wood,
			COLORS.darkTimber
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
	local function riverZ(x: number): number
		return bridge.Z + 0.065 * (x - bridge.X) + 28 * math.sin((x + 180) / 280)
	end

	local previous = Vector3.new(-1240, 3.6, riverZ(-1240))
	local index = 0
	for x = -1080, 1240, 160 do
		index += 1
		local current = Vector3.new(x, 3.6, riverZ(x))
		P.segment(
			river,
			string.format("Water%02d", index),
			previous,
			current,
			76,
			0.45,
			Enum.Material.Glass,
			COLORS.water,
			{ canCollide = false, transparency = 0.25, attributes = { TemporaryWater = true } }
		)
		previous = current
	end

	local southBank = Grounding.surfaceAt(bridge + Vector3.new(0, 0, -62))
	local northBank = Grounding.surfaceAt(bridge + Vector3.new(0, 0, 62))
	local deckCenterY = math.max(southBank.Y, northBank.Y) + 1.7
	local deckSouth = Vector3.new(bridge.X, deckCenterY, bridge.Z - 38)
	local deckNorth = Vector3.new(bridge.X, deckCenterY, bridge.Z + 38)

	P.segment(river, "BridgeDeck", deckSouth, deckNorth, 30, 2.6, Enum.Material.WoodPlanks, COLORS.timber)
	P.segment(
		river,
		"BridgeApproachSouth",
		southBank + Vector3.new(0, 1.3, 0),
		deckSouth,
		30,
		2.6,
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
	P.segment(
		river,
		"BridgeApproachNorth",
		deckNorth,
		northBank + Vector3.new(0, 1.3, 0),
		30,
		2.6,
		Enum.Material.WoodPlanks,
		COLORS.timber
	)

	for _, sideX in ipairs({ -13, 13 }) do
		P.segment(
			river,
			"BridgeRail",
			Vector3.new(bridge.X + sideX, deckCenterY + 3.5, bridge.Z - 37),
			Vector3.new(bridge.X + sideX, deckCenterY + 3.5, bridge.Z + 37),
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
	spawn.CFrame = CFrame.new(ground + Vector3.new(0, 1.2, 0))
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
