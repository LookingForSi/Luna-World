--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local GreyboxPrimitives = require(script.Parent.GreyboxPrimitives)

type PointOfInterestDefinition = typeof(WorldLayout.PointsOfInterest[1])

local MODEL_NAME = "GoblinCamp"
local ZONE_ID = "zone_goblin_camp"

local COLORS = {
	ground = Color3.fromRGB(83, 94, 66),
	path = Color3.fromRGB(105, 89, 70),
	timber = Color3.fromRGB(82, 58, 40),
	darkTimber = Color3.fromRGB(61, 45, 35),
	stone = Color3.fromRGB(76, 77, 70),
	fire = Color3.fromRGB(207, 107, 47),
	clutter = Color3.fromRGB(96, 68, 44),
}

local GoblinCampGreybox = {}

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
	error(string.format("Goblin Camp requires WorldLayout POI '%s'", stableId))
end

local function createApproach(parent: Instance)
	local ground = createFolder(parent, "ApproachGround")
	local path = createFolder(parent, "ApproachPath")

	for index = 1, #WorldLayout.GoblinCampRoute - 1 do
		local from = WorldLayout.GoblinCampRoute[index]
		local to = WorldLayout.GoblinCampRoute[index + 1]

		local groundSection = GreyboxPrimitives.createSegment(
			ground,
			string.format("GoblinSlope%02d", index),
			from - Vector3.new(0, 4, 0),
			to - Vector3.new(0, 4, 0),
			170,
			8
		)
		groundSection.Material = Enum.Material.Grass
		groundSection.Color = COLORS.ground

		local pathSection = GreyboxPrimitives.createSegment(
			path,
			string.format("GoblinPath%02d", index),
			from + Vector3.new(0, 0.5, 0),
			to + Vector3.new(0, 0.5, 0),
			14,
			1
		)
		pathSection.Material = Enum.Material.Ground
		pathSection.Color = COLORS.path
	end
end

local function createPalisade(parent: Instance, campPosition: Vector3)
	local sections = {
		{ from = campPosition + Vector3.new(-115, 5, -70), to = campPosition + Vector3.new(-42, 5, -92) },
		{ from = campPosition + Vector3.new(42, 5, -92), to = campPosition + Vector3.new(115, 5, -68) },
		{ from = campPosition + Vector3.new(-118, 5, -65), to = campPosition + Vector3.new(-124, 5, 78) },
		{ from = campPosition + Vector3.new(118, 5, -62), to = campPosition + Vector3.new(120, 5, 72) },
		{ from = campPosition + Vector3.new(-118, 5, 82), to = campPosition + Vector3.new(-52, 5, 105) },
		{ from = campPosition + Vector3.new(52, 5, 105), to = campPosition + Vector3.new(118, 5, 78) },
	}

	for index, section in ipairs(sections) do
		local wall = GreyboxPrimitives.createSegment(
			parent,
			string.format("Palisade%02d", index),
			section.from,
			section.to,
			4,
			10
		)
		wall.Material = Enum.Material.Wood
		wall.Color = COLORS.darkTimber
	end
end

local function createHut(parent: Instance, name: string, position: Vector3, size: Vector3)
	createGroundedBlock(parent, name .. "Volume", position, size, Enum.Material.WoodPlanks, COLORS.timber)
	local roof = createGroundedBlock(
		parent,
		name .. "Roof",
		position + Vector3.new(0, size.Y, 0),
		Vector3.new(size.X + 5, 4, size.Z + 5),
		Enum.Material.Wood,
		COLORS.darkTimber
	)
	roof.CFrame *= CFrame.Angles(0, 0, math.rad(4))
end

local function createCampInterior(parent: Instance, campDefinition: PointOfInterestDefinition)
	local camp = createModel(parent, "CampInterior", campDefinition.id)
	local position = campDefinition.position

	createGroundedBlock(
		camp,
		"CampTerrace",
		position - Vector3.new(0, 4, 0),
		Vector3.new(300, 8, 260),
		Enum.Material.Grass,
		COLORS.ground
	)
	createColoredBlock(
		camp,
		"CentralClearing",
		Vector3.new(92, 1, 82),
		CFrame.new(position - Vector3.new(0, 0.5, -18)),
		Enum.Material.Ground,
		COLORS.path
	)

	createPalisade(camp, position)
	createHut(camp, "ScoutHut", position + Vector3.new(-72, 0, 18), Vector3.new(38, 17, 30))
	createHut(camp, "WarriorHut", position + Vector3.new(70, 0, 24), Vector3.new(42, 20, 32))
	createHut(camp, "StorageShelter", position + Vector3.new(48, 0, 78), Vector3.new(34, 14, 24))

	local fire = createGroundedBlock(
		camp,
		"CampfireBlockout",
		position + Vector3.new(0, 0, -10),
		Vector3.new(10, 2, 10),
		Enum.Material.Neon,
		COLORS.fire
	)
	fire.Shape = Enum.PartType.Cylinder

	for index, offset in ipairs({
		Vector3.new(-42, 0, 58),
		Vector3.new(-31, 0, 68),
		Vector3.new(78, 0, -42),
		Vector3.new(89, 0, -31),
		Vector3.new(-88, 0, -26),
	}) do
		createGroundedBlock(
			camp,
			string.format("CampClutter%02d", index),
			position + offset,
			Vector3.new(9, 7, 9),
			Enum.Material.WoodPlanks,
			COLORS.clutter
		)
	end
end

local function createLookout(parent: Instance, definition: PointOfInterestDefinition)
	local lookout = createModel(parent, "GoblinLookout", definition.id)
	local position = definition.position
	for index, offset in ipairs({
		Vector3.new(-8, 0, -8),
		Vector3.new(8, 0, -8),
		Vector3.new(-8, 0, 8),
		Vector3.new(8, 0, 8),
	}) do
		createGroundedBlock(
			lookout,
			string.format("LookoutPost%02d", index),
			position + offset,
			Vector3.new(3, 20, 3),
			Enum.Material.Wood,
			COLORS.darkTimber
		)
	end
	createGroundedBlock(
		lookout,
		"LookoutPlatform",
		position + Vector3.new(0, 18, 0),
		Vector3.new(24, 3, 24),
		Enum.Material.WoodPlanks,
		COLORS.timber
	)
	GreyboxPrimitives.createLabel(lookout.LookoutPlatform :: BasePart, definition.id)
end

local function createSpawnMarkers(parent: Instance)
	local markers = createFolder(parent, "SpawnMarkers")
	local count = 0
	for _, definition in ipairs(WorldLayout.SpawnMarkers) do
		if definition.zoneId == ZONE_ID then
			count += 1
			local marker = GreyboxPrimitives.createMarker(markers, definition.id, definition.position, {
				StableId = definition.id,
				MobId = definition.mobId,
				Radius = definition.radius,
				ZoneId = definition.zoneId,
			})
			if definition.id == "spawn_goblin_camp_elite_future" then
				marker:SetAttribute("Purpose", "FutureEliteReservation")
			end
		end
	end
	assert(count == 3, string.format("Goblin Camp requires 3 spawn markers, got %d", count))
end

function GoblinCampGreybox.build(parent: Instance): Model
	local model = createModel(parent, MODEL_NAME, nil)
	model:SetAttribute("ZoneId", ZONE_ID)

	createApproach(model)
	createCampInterior(model, getPoi("poi_goblin_camp"))
	createLookout(model, getPoi("poi_goblin_lookout"))
	createSpawnMarkers(model)

	return model
end

return table.freeze(GoblinCampGreybox)
