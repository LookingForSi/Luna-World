--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local GreyboxPrimitives = require(script.Parent.GreyboxPrimitives)

type PointOfInterestDefinition = typeof(WorldLayout.PointsOfInterest[1])

local MODEL_NAME = "SpiderHollow"
local ZONE_ID = "zone_spider_hollow"

local COLORS = {
	ground = Color3.fromRGB(65, 76, 61),
	path = Color3.fromRGB(91, 82, 70),
	stone = Color3.fromRGB(65, 69, 68),
	darkStone = Color3.fromRGB(45, 49, 49),
	tree = Color3.fromRGB(50, 46, 39),
	root = Color3.fromRGB(62, 49, 37),
}

local SpiderHollowGreybox = {}

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
	error(string.format("Spider Hollow requires WorldLayout POI '%s'", stableId))
end

local function createTrail(
	parent: Instance,
	name: string,
	route: { Vector3 },
	groundWidth: number,
	pathWidth: number
)
	local ground = createFolder(parent, name .. "Ground")
	local path = createFolder(parent, name .. "Path")

	for index = 1, #route - 1 do
		local from = route[index]
		local to = route[index + 1]

		local groundSection = GreyboxPrimitives.createSegment(
			ground,
			string.format("%sGround%02d", name, index),
			from - Vector3.new(0, 5, 0),
			to - Vector3.new(0, 5, 0),
			groundWidth,
			10
		)
		groundSection.Material = Enum.Material.Grass
		groundSection.Color = COLORS.ground

		local pathSection = GreyboxPrimitives.createSegment(
			path,
			string.format("%sPath%02d", name, index),
			from + Vector3.new(0, 0.45, 0),
			to + Vector3.new(0, 0.45, 0),
			pathWidth,
			0.9
		)
		pathSection.Material = Enum.Material.Ground
		pathSection.Color = COLORS.path
	end
end

local function createHollow(parent: Instance, definition: PointOfInterestDefinition)
	local hollow = createModel(parent, "HollowBasin", definition.id)
	local position = definition.position

	createColoredBlock(
		hollow,
		"HollowFloor",
		Vector3.new(320, 10, 300),
		CFrame.new(position - Vector3.new(0, 5, 0)),
		Enum.Material.Grass,
		COLORS.ground
	)
	createColoredBlock(
		hollow,
		"BroodClearing",
		Vector3.new(105, 1, 90),
		CFrame.new(position + Vector3.new(35, -0.5, 70)),
		Enum.Material.Ground,
		COLORS.path
	)

	local rockWalls = {
		{ offset = Vector3.new(-145, 0, -35), size = Vector3.new(30, 35, 120), angle = 12 },
		{ offset = Vector3.new(-115, 0, 115), size = Vector3.new(95, 28, 28), angle = -18 },
		{ offset = Vector3.new(125, 0, -70), size = Vector3.new(28, 38, 110), angle = -10 },
		{ offset = Vector3.new(125, 0, 95), size = Vector3.new(70, 31, 28), angle = 16 },
	}

	for index, wall in ipairs(rockWalls) do
		local block = createGroundedBlock(
			hollow,
			string.format("RockWall%02d", index),
			position + wall.offset,
			wall.size,
			Enum.Material.Slate,
			COLORS.stone
		)
		block.CFrame *= CFrame.Angles(0, math.rad(wall.angle), math.rad((index % 2 == 0) and 3 or -4))
	end

	for index, offset in ipairs({
		Vector3.new(-78, 0, -88),
		Vector3.new(-34, 0, 118),
		Vector3.new(74, 0, -102),
		Vector3.new(108, 0, 46),
		Vector3.new(8, 0, 138),
	}) do
		local tree = createGroundedBlock(
			hollow,
			string.format("MassiveTree%02d", index),
			position + offset,
			Vector3.new(12, 34 + index * 3, 12),
			Enum.Material.Wood,
			COLORS.tree
		)
		tree.CFrame *= CFrame.Angles(math.rad(if index % 2 == 0 then 4 else -3), 0, math.rad(if index % 2 == 0 then -4 else 5))

		local root = GreyboxPrimitives.createSegment(
			hollow,
			string.format("Root%02d", index),
			position + offset + Vector3.new(0, 1.5, 0),
			position + offset + Vector3.new(if index % 2 == 0 then 22 else -22, 1.5, 18),
			4,
			3
		)
		root.Material = Enum.Material.Wood
		root.Color = COLORS.root
	end
end

local function createCaveMouth(parent: Instance, definition: PointOfInterestDefinition)
	local cave = createModel(parent, "SpiderCaveMouth", definition.id)
	local position = definition.position

	createGroundedBlock(
		cave,
		"CavePillarWest",
		position + Vector3.new(-15, 0, 0),
		Vector3.new(15, 28, 18),
		Enum.Material.Slate,
		COLORS.darkStone
	)
	createGroundedBlock(
		cave,
		"CavePillarEast",
		position + Vector3.new(15, 0, 0),
		Vector3.new(15, 28, 18),
		Enum.Material.Slate,
		COLORS.darkStone
	)
	createColoredBlock(
		cave,
		"CaveLintel",
		Vector3.new(44, 13, 20),
		CFrame.new(position + Vector3.new(0, 25, 0)),
		Enum.Material.Slate,
		COLORS.darkStone
	)
	local darkness = createColoredBlock(
		cave,
		"CaveDarkness",
		Vector3.new(24, 20, 2),
		CFrame.new(position + Vector3.new(0, 10, 7)),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(23, 25, 25)
	)
	darkness.CanCollide = false
	GreyboxPrimitives.createLabel(darkness, definition.id)
end

local function createSpawnMarkers(parent: Instance)
	local markers = createFolder(parent, "SpawnMarkers")
	local count = 0
	for _, definition in ipairs(WorldLayout.SpawnMarkers) do
		if definition.zoneId == ZONE_ID then
			count += 1
			GreyboxPrimitives.createMarker(markers, definition.id, definition.position, {
				StableId = definition.id,
				MobId = definition.mobId,
				Radius = definition.radius,
				ZoneId = definition.zoneId,
				SpawnEnabled = definition.spawnEnabled ~= false,
			})
		end
	end
	assert(count == 3, string.format("Spider Hollow requires 3 spawn markers, got %d", count))
end

function SpiderHollowGreybox.build(parent: Instance): Model
	local model = createModel(parent, MODEL_NAME, nil)
	model:SetAttribute("ZoneId", ZONE_ID)

	createTrail(model, "Descent", WorldLayout.SpiderHollowRoute, 180, 13)
	createTrail(model, "Return", WorldLayout.SpiderReturnRoute, 120, 11)
	createHollow(model, getPoi("poi_spider_hollow"))
	createCaveMouth(model, getPoi("poi_spider_cave_mouth"))
	createSpawnMarkers(model)

	return model
end

return table.freeze(SpiderHollowGreybox)
