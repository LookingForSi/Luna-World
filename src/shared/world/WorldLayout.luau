--!strict

export type ZoneDefinition = {
	id: string,
	displayName: string,
	levelMin: number,
	levelMax: number,
	future: boolean?,
}

export type ZoneVolumeDefinition = {
	zoneId: string,
	center: Vector3,
	size: Vector3,
	priority: number,
	minSafeY: number,
}

export type PointOfInterestDefinition = {
	id: string,
	position: Vector3,
}

export type SpawnMarkerDefinition = {
	id: string,
	mobId: string,
	position: Vector3,
	radius: number,
	zoneId: string,
	spawnEnabled: boolean?,
}

export type WorldLayoutDefinition = {
	WorldBounds: {
		minX: number,
		maxX: number,
		minZ: number,
		maxZ: number,
	},
	Dimensions: {
		VillageFootprint: Vector2,
		VillageElevationAboveMeadows: number,
		MeadowsRouteLength: number,
		MoonfallRouteLength: number,
	},
	Zones: { ZoneDefinition },
	ZoneVolumes: { ZoneVolumeDefinition },
	PointsOfInterest: { PointOfInterestDefinition },
	SpawnMarkers: { SpawnMarkerDefinition },
	Route: { Vector3 },
	MoonfallRoadRoute: { Vector3 },
	GoblinCampRoute: { Vector3 },
	SpiderHollowRoute: { Vector3 },
	SpiderReturnRoute: { Vector3 },
	AncientApproachRoute: { Vector3 },
}

local WORLD_DISTANCE_SCALE = 2.0

local function scaleXZ(x: number, y: number, z: number): Vector3
	return Vector3.new(x * WORLD_DISTANCE_SCALE, y, z * WORLD_DISTANCE_SCALE)
end

local function scaleDistance(value: number): number
	return value * WORLD_DISTANCE_SCALE
end

local WorldLayout: WorldLayoutDefinition = {
	WorldBounds = {
		minX = -1300,
		maxX = 1300,
		minZ = -650,
		maxZ = 4150,
	},

	Dimensions = {
		VillageFootprint = Vector2.new(500, 440),
		VillageElevationAboveMeadows = 50,
		MeadowsRouteLength = 1580,
		MoonfallRouteLength = 1280,
	},

	Zones = {
		{
			id = "zone_luna_village",
			displayName = "Luna Village",
			levelMin = 1,
			levelMax = 1,
		},
		{
			id = "zone_luna_meadows",
			displayName = "Luna Meadows",
			levelMin = 1,
			levelMax = 3,
		},
		{
			id = "zone_moonfall_road",
			displayName = "Moonfall Road",
			levelMin = 3,
			levelMax = 7,
		},
		{
			id = "zone_goblin_camp",
			displayName = "Goblin Camp",
			levelMin = 4,
			levelMax = 7,
		},
		{
			id = "zone_spider_hollow",
			displayName = "Spider Hollow",
			levelMin = 4,
			levelMax = 6,
		},
		{
			id = "zone_dark_woodland",
			displayName = "Dark Woodland",
			levelMin = 6,
			levelMax = 8,
			future = true,
		},
		{
			id = "zone_old_cemetery",
			displayName = "Old Cemetery",
			levelMin = 7,
			levelMax = 9,
			future = true,
		},
		{
			id = "zone_fallen_shrine",
			displayName = "Fallen Shrine",
			levelMin = 7,
			levelMax = 9,
			future = true,
		},
		{
			id = "zone_ancient_approach",
			displayName = "Ancient Approach",
			levelMin = 8,
			levelMax = 10,
			future = true,
		},
	},

	ZoneVolumes = {
		{
			zoneId = "zone_luna_village",
			center = scaleXZ(0, 50, -95),
			size = scaleXZ(360, 140, 330),
			priority = 5,
			minSafeY = 26,
		},
		{
			zoneId = "zone_luna_meadows",
			center = scaleXZ(0, 18, 450),
			size = scaleXZ(760, 120, 750),
			priority = 1,
			minSafeY = -2,
		},
		{
			zoneId = "zone_moonfall_road",
			center = scaleXZ(0, 24, 1050),
			size = scaleXZ(560, 150, 725),
			priority = 2,
			minSafeY = -2,
		},
		{
			zoneId = "zone_goblin_camp",
			center = scaleXZ(280, 60, 1100),
			size = scaleXZ(390, 150, 360),
			priority = 10,
			minSafeY = 12,
		},
		{
			zoneId = "zone_spider_hollow",
			center = scaleXZ(-280, 6, 1110),
			size = scaleXZ(400, 120, 370),
			priority = 10,
			minSafeY = -6,
		},
		{
			zoneId = "zone_dark_woodland",
			center = scaleXZ(0, 46, 1450),
			size = scaleXZ(650, 180, 250),
			priority = 6,
			minSafeY = 8,
		},
		{
			zoneId = "zone_old_cemetery",
			center = scaleXZ(280, 102, 1555),
			size = scaleXZ(260, 150, 230),
			priority = 8,
			minSafeY = 40,
		},
		{
			zoneId = "zone_fallen_shrine",
			center = scaleXZ(-280, 108, 1570),
			size = scaleXZ(250, 150, 230),
			priority = 8,
			minSafeY = 40,
		},
		{
			zoneId = "zone_ancient_approach",
			center = scaleXZ(0, 124, 1770),
			size = scaleXZ(380, 170, 360),
			priority = 7,
			minSafeY = 60,
		},
	},

	PointsOfInterest = {
		{ id = "poi_main_gate", position = scaleXZ(0, 48, 0) },
		{ id = "poi_training_ground", position = scaleXZ(-75, 54, -55) },
		{ id = "poi_blacksmith", position = scaleXZ(75, 54, -65) },
		{ id = "poi_village_square", position = scaleXZ(0, 58, -120) },
		{ id = "poi_merchant", position = scaleXZ(68, 58, -125) },
		{ id = "poi_residential", position = scaleXZ(-72, 58, -130) },
		{ id = "poi_elder_house", position = scaleXZ(55, 64, -185) },
		{ id = "poi_shrine", position = scaleXZ(-55, 64, -195) },
		{ id = "poi_moonfall_farm", position = scaleXZ(-180, 8, 365) },
		{ id = "poi_meadow_bridge", position = scaleXZ(-35, 7, 300) },
		{ id = "poi_stone_circle", position = scaleXZ(135, 6, 545) },
		{ id = "exit_moonfall_road", position = scaleXZ(0, 6, 790) },

		{ id = "poi_broken_wagon", position = scaleXZ(-50, 10, 870) },
		{ id = "poi_moonfall_crossroads", position = scaleXZ(0, 18, 970) },
		{ id = "poi_old_waystone", position = scaleXZ(-10, 18, 960) },
		{ id = "poi_goblin_camp", position = scaleXZ(280, 60, 1100) },
		{ id = "poi_goblin_lookout", position = scaleXZ(350, 68, 1185) },
		{ id = "poi_spider_hollow", position = scaleXZ(-280, 4, 1110) },
		{ id = "poi_spider_cave_mouth", position = scaleXZ(-350, 4, 1190) },
		{ id = "poi_dark_woodland_gate", position = scaleXZ(0, 30, 1340) },
		{ id = "entry_dark_woodland", position = scaleXZ(0, 36, 1430) },

		{ id = "poi_old_cemetery", position = scaleXZ(280, 102, 1555) },
		{ id = "poi_fallen_shrine", position = scaleXZ(-280, 108, 1570) },
		{ id = "poi_ancient_approach", position = scaleXZ(0, 124, 1770) },
		{ id = "poi_selene_horizon", position = scaleXZ(0, 150, 2070) },
	},

	SpawnMarkers = {
		{
			id = "spawn_young_wolf_farm",
			mobId = "mob_young_wolf",
			position = scaleXZ(-110, 8, 415),
			radius = scaleDistance(55),
			zoneId = "zone_luna_meadows",
		},
		{
			id = "spawn_wolf_stone_circle",
			mobId = "mob_grey_wolf",
			position = scaleXZ(100, 7, 585),
			radius = scaleDistance(70),
			zoneId = "zone_luna_meadows",
		},
		{
			id = "spawn_spider_meadow_pocket",
			mobId = "mob_meadow_spider",
			position = scaleXZ(220, 8, 690),
			radius = scaleDistance(60),
			zoneId = "zone_luna_meadows",
		},
		{
			id = "spawn_goblin_scout_road",
			mobId = "mob_goblin_scout",
			position = scaleXZ(90, 24, 1010),
			radius = scaleDistance(42),
			zoneId = "zone_moonfall_road",
		},
		{
			id = "spawn_goblin_scout_outer",
			mobId = "mob_goblin_scout",
			position = scaleXZ(200, 48, 1055),
			radius = scaleDistance(48),
			zoneId = "zone_goblin_camp",
		},
		{
			id = "spawn_goblin_warrior_camp",
			mobId = "mob_goblin_warrior",
			position = scaleXZ(280, 60, 1115),
			radius = scaleDistance(55),
			zoneId = "zone_goblin_camp",
		},
		{
			id = "spawn_goblin_camp_elite_future",
			mobId = "mob_goblin_elite_future",
			position = scaleXZ(330, 66, 1175),
			radius = scaleDistance(36),
			zoneId = "zone_goblin_camp",
			spawnEnabled = false,
		},
		{
			id = "spawn_spider_hollow_outer",
			mobId = "mob_meadow_spider",
			position = scaleXZ(-190, 10, 1050),
			radius = scaleDistance(48),
			zoneId = "zone_spider_hollow",
		},
		{
			id = "spawn_spider_hollow_mid",
			mobId = "mob_meadow_spider",
			position = scaleXZ(-280, 4, 1115),
			radius = scaleDistance(55),
			zoneId = "zone_spider_hollow",
		},
		{
			id = "spawn_spider_hollow_brood",
			mobId = "mob_brood_spider",
			position = scaleXZ(-335, 4, 1180),
			radius = scaleDistance(44),
			zoneId = "zone_spider_hollow",
			spawnEnabled = false,
		},
	},

	Route = {
		scaleXZ(0, 48, 0),
		scaleXZ(0, 38, 90),
		scaleXZ(-20, 24, 210),
		scaleXZ(-35, 10, 300),
		scaleXZ(20, 8, 450),
		scaleXZ(80, 7, 560),
		scaleXZ(40, 6, 690),
		scaleXZ(0, 6, 790),
	},

	MoonfallRoadRoute = {
		scaleXZ(0, 6, 790),
		scaleXZ(-20, 8, 850),
		scaleXZ(-10, 12, 910),
		scaleXZ(0, 18, 970),
		scaleXZ(5, 22, 1070),
		scaleXZ(0, 25, 1180),
		scaleXZ(5, 28, 1270),
		scaleXZ(0, 30, 1340),
		scaleXZ(0, 36, 1430),
	},

	GoblinCampRoute = {
		scaleXZ(0, 18, 970),
		scaleXZ(75, 24, 1000),
		scaleXZ(150, 34, 1035),
		scaleXZ(215, 46, 1070),
		scaleXZ(280, 60, 1100),
		scaleXZ(315, 64, 1145),
		scaleXZ(350, 68, 1185),
	},

	SpiderHollowRoute = {
		scaleXZ(0, 18, 970),
		scaleXZ(-80, 15, 1005),
		scaleXZ(-155, 11, 1040),
		scaleXZ(-225, 7, 1080),
		scaleXZ(-280, 4, 1110),
		scaleXZ(-315, 4, 1150),
		scaleXZ(-350, 4, 1190),
	},

	SpiderReturnRoute = {
		scaleXZ(-350, 4, 1190),
		scaleXZ(-305, 6, 1230),
		scaleXZ(-225, 11, 1250),
		scaleXZ(-130, 19, 1260),
		scaleXZ(5, 28, 1270),
	},

	AncientApproachRoute = {
		scaleXZ(0, 36, 1430),
		scaleXZ(0, 54, 1520),
		scaleXZ(0, 78, 1610),
		scaleXZ(0, 104, 1700),
		scaleXZ(0, 124, 1770),
	},
}

return table.freeze(WorldLayout)
