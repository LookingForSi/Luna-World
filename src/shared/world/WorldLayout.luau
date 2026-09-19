--!strict

export type ZoneDefinition = {
	id: string,
	displayName: string,
	levelMin: number,
	levelMax: number,
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
}

local WORLD_DISTANCE_SCALE = 2.0

local function scaleXZ(x: number, y: number, z: number): Vector3
	return Vector3.new(x * WORLD_DISTANCE_SCALE, y, z * WORLD_DISTANCE_SCALE)
end

local function scaleDistance(value: number): number
	return value * WORLD_DISTANCE_SCALE
end

local WorldLayout: WorldLayoutDefinition = {
	Dimensions = {
		VillageFootprint = Vector2.new(500, 440),
		VillageElevationAboveMeadows = 50,
		MeadowsRouteLength = 1800,
		MoonfallRouteLength = 1880,
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
			center = scaleXZ(0, 18, 510),
			size = scaleXZ(760, 120, 900),
			priority = 1,
			minSafeY = -2,
		},
		{
			zoneId = "zone_moonfall_road",
			center = scaleXZ(0, 22, 1380),
			size = scaleXZ(560, 140, 960),
			priority = 2,
			minSafeY = -2,
		},
		{
			zoneId = "zone_goblin_camp",
			center = scaleXZ(-300, 42, 1415),
			size = scaleXZ(430, 140, 430),
			priority = 10,
			minSafeY = 12,
		},
		{
			zoneId = "zone_spider_hollow",
			center = scaleXZ(300, 8, 1440),
			size = scaleXZ(440, 120, 440),
			priority = 10,
			minSafeY = -6,
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
		{ id = "exit_moonfall_road", position = scaleXZ(0, 4, 900) },

		{ id = "poi_broken_wagon", position = scaleXZ(-70, 9, 1050) },
		{ id = "poi_moonfall_crossroads", position = scaleXZ(20, 16, 1220) },
		{ id = "poi_old_waystone", position = scaleXZ(8, 16, 1210) },
		{ id = "poi_goblin_camp", position = scaleXZ(-300, 42, 1400) },
		{ id = "poi_goblin_lookout", position = scaleXZ(-360, 50, 1510) },
		{ id = "poi_spider_hollow", position = scaleXZ(300, 2, 1420) },
		{ id = "poi_spider_cave_mouth", position = scaleXZ(360, 0, 1530) },
		{ id = "poi_dark_woodland_gate", position = scaleXZ(20, 24, 1740) },
		{ id = "entry_dark_woodland", position = scaleXZ(0, 26, 1840) },
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
			position = scaleXZ(-105, 20, 1285),
			radius = scaleDistance(42),
			zoneId = "zone_moonfall_road",
		},
		{
			id = "spawn_goblin_scout_outer",
			mobId = "mob_goblin_scout",
			position = scaleXZ(-220, 34, 1340),
			radius = scaleDistance(48),
			zoneId = "zone_goblin_camp",
		},
		{
			id = "spawn_goblin_warrior_camp",
			mobId = "mob_goblin_warrior",
			position = scaleXZ(-300, 42, 1430),
			radius = scaleDistance(55),
			zoneId = "zone_goblin_camp",
		},
		{
			id = "spawn_goblin_camp_elite_future",
			mobId = "mob_goblin_elite_future",
			position = scaleXZ(-350, 48, 1500),
			radius = scaleDistance(36),
			zoneId = "zone_goblin_camp",
			spawnEnabled = false,
		},
		{
			id = "spawn_spider_hollow_outer",
			mobId = "mob_meadow_spider",
			position = scaleXZ(210, 7, 1345),
			radius = scaleDistance(48),
			zoneId = "zone_spider_hollow",
		},
		{
			id = "spawn_spider_hollow_mid",
			mobId = "mob_meadow_spider",
			position = scaleXZ(295, 2, 1430),
			radius = scaleDistance(55),
			zoneId = "zone_spider_hollow",
		},
		{
			id = "spawn_spider_hollow_brood",
			mobId = "mob_brood_spider",
			position = scaleXZ(345, 0, 1510),
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
		scaleXZ(90, 7, 560),
		scaleXZ(45, 6, 720),
		scaleXZ(0, 5, 900),
	},

	MoonfallRoadRoute = {
		scaleXZ(0, 4, 900),
		scaleXZ(-25, 6, 1010),
		scaleXZ(-10, 10, 1110),
		scaleXZ(20, 16, 1220),
		scaleXZ(5, 18, 1340),
		scaleXZ(-10, 20, 1470),
		scaleXZ(15, 22, 1600),
		scaleXZ(20, 24, 1740),
		scaleXZ(0, 26, 1840),
	},

	GoblinCampRoute = {
		scaleXZ(20, 16, 1220),
		scaleXZ(-80, 19, 1265),
		scaleXZ(-170, 25, 1315),
		scaleXZ(-250, 32, 1370),
		scaleXZ(-300, 42, 1400),
		scaleXZ(-330, 46, 1460),
		scaleXZ(-360, 50, 1510),
	},

	SpiderHollowRoute = {
		scaleXZ(20, 16, 1220),
		scaleXZ(105, 12, 1275),
		scaleXZ(195, 7, 1340),
		scaleXZ(270, 3, 1395),
		scaleXZ(300, 2, 1420),
		scaleXZ(330, 1, 1480),
		scaleXZ(360, 0, 1530),
	},

	SpiderReturnRoute = {
		scaleXZ(360, 0, 1530),
		scaleXZ(320, 3, 1570),
		scaleXZ(245, 8, 1595),
		scaleXZ(155, 15, 1605),
		scaleXZ(15, 22, 1600),
	},
}

return table.freeze(WorldLayout)
