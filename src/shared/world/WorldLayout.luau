--!strict

export type ZoneDefinition = {
	id: string,
	levelMin: number,
	levelMax: number,
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
	PointsOfInterest: { PointOfInterestDefinition },
	SpawnMarkers: { SpawnMarkerDefinition },
	Route: { Vector3 },
	MoonfallRoadRoute: { Vector3 },
	GoblinCampRoute: { Vector3 },
	SpiderHollowRoute: { Vector3 },
	SpiderReturnRoute: { Vector3 },
}

local WorldLayout: WorldLayoutDefinition = {
	Dimensions = {
		VillageFootprint = Vector2.new(250, 220),
		VillageElevationAboveMeadows = 36,
		MeadowsRouteLength = 900,
		MoonfallRouteLength = 940,
	},

	Zones = {
		{
			id = "zone_luna_village",
			levelMin = 1,
			levelMax = 1,
		},
		{
			id = "zone_luna_meadows",
			levelMin = 1,
			levelMax = 3,
		},
		{
			id = "zone_moonfall_road",
			levelMin = 3,
			levelMax = 7,
		},
		{
			id = "zone_goblin_camp",
			levelMin = 4,
			levelMax = 7,
		},
		{
			id = "zone_spider_hollow",
			levelMin = 4,
			levelMax = 6,
		},
	},

	PointsOfInterest = {
		{ id = "poi_main_gate", position = Vector3.new(0, 32, 0) },
		{ id = "poi_training_ground", position = Vector3.new(-75, 38, -55) },
		{ id = "poi_blacksmith", position = Vector3.new(75, 40, -65) },
		{ id = "poi_village_square", position = Vector3.new(0, 46, -120) },
		{ id = "poi_merchant", position = Vector3.new(68, 47, -125) },
		{ id = "poi_residential", position = Vector3.new(-72, 47, -130) },
		{ id = "poi_elder_house", position = Vector3.new(55, 62, -185) },
		{ id = "poi_shrine", position = Vector3.new(-55, 66, -195) },
		{ id = "poi_moonfall_farm", position = Vector3.new(-180, 8, 365) },
		{ id = "poi_meadow_bridge", position = Vector3.new(-35, 7, 300) },
		{ id = "poi_stone_circle", position = Vector3.new(135, 6, 545) },
		{ id = "exit_moonfall_road", position = Vector3.new(0, 4, 900) },

		{ id = "poi_broken_wagon", position = Vector3.new(-70, 9, 1050) },
		{ id = "poi_moonfall_crossroads", position = Vector3.new(20, 16, 1220) },
		{ id = "poi_old_waystone", position = Vector3.new(8, 16, 1210) },
		{ id = "poi_goblin_camp", position = Vector3.new(-300, 30, 1400) },
		{ id = "poi_goblin_lookout", position = Vector3.new(-360, 42, 1510) },
		{ id = "poi_spider_hollow", position = Vector3.new(300, 2, 1420) },
		{ id = "poi_spider_cave_mouth", position = Vector3.new(360, 0, 1530) },
		{ id = "poi_dark_woodland_gate", position = Vector3.new(20, 24, 1740) },
		{ id = "entry_dark_woodland", position = Vector3.new(0, 26, 1840) },
	},

	SpawnMarkers = {
		{
			id = "spawn_young_wolf_farm",
			mobId = "mob_young_wolf",
			position = Vector3.new(-110, 8, 415),
			radius = 55,
			zoneId = "zone_luna_meadows",
		},
		{
			id = "spawn_wolf_stone_circle",
			mobId = "mob_grey_wolf",
			position = Vector3.new(100, 7, 585),
			radius = 70,
			zoneId = "zone_luna_meadows",
		},
		{
			id = "spawn_spider_meadow_pocket",
			mobId = "mob_meadow_spider",
			position = Vector3.new(220, 8, 690),
			radius = 60,
			zoneId = "zone_luna_meadows",
		},
		{
			id = "spawn_goblin_scout_road",
			mobId = "mob_goblin_scout",
			position = Vector3.new(-105, 20, 1285),
			radius = 42,
			zoneId = "zone_moonfall_road",
		},
		{
			id = "spawn_goblin_scout_outer",
			mobId = "mob_goblin_scout",
			position = Vector3.new(-220, 26, 1340),
			radius = 48,
			zoneId = "zone_goblin_camp",
		},
		{
			id = "spawn_goblin_warrior_camp",
			mobId = "mob_goblin_warrior",
			position = Vector3.new(-300, 30, 1430),
			radius = 55,
			zoneId = "zone_goblin_camp",
		},
		{
			id = "spawn_goblin_camp_elite_future",
			mobId = "mob_goblin_elite_future",
			position = Vector3.new(-350, 40, 1500),
			radius = 36,
			zoneId = "zone_goblin_camp",
			spawnEnabled = false,
		},
		{
			id = "spawn_spider_hollow_outer",
			mobId = "mob_meadow_spider",
			position = Vector3.new(210, 7, 1345),
			radius = 48,
			zoneId = "zone_spider_hollow",
		},
		{
			id = "spawn_spider_hollow_mid",
			mobId = "mob_meadow_spider",
			position = Vector3.new(295, 2, 1430),
			radius = 55,
			zoneId = "zone_spider_hollow",
		},
		{
			id = "spawn_spider_hollow_brood",
			mobId = "mob_brood_spider",
			position = Vector3.new(345, 0, 1510),
			radius = 44,
			zoneId = "zone_spider_hollow",
			spawnEnabled = false,
		},
	},

	Route = {
		Vector3.new(0, 32, 0),
		Vector3.new(0, 20, 90),
		Vector3.new(-20, 11, 210),
		Vector3.new(-35, 7, 300),
		Vector3.new(20, 6, 450),
		Vector3.new(90, 6, 560),
		Vector3.new(45, 5, 720),
		Vector3.new(0, 4, 900),
	},

	MoonfallRoadRoute = {
		Vector3.new(0, 4, 900),
		Vector3.new(-25, 6, 1010),
		Vector3.new(-10, 10, 1110),
		Vector3.new(20, 16, 1220),
		Vector3.new(5, 18, 1340),
		Vector3.new(-10, 20, 1470),
		Vector3.new(15, 22, 1600),
		Vector3.new(20, 24, 1740),
		Vector3.new(0, 26, 1840),
	},

	GoblinCampRoute = {
		Vector3.new(20, 16, 1220),
		Vector3.new(-80, 19, 1265),
		Vector3.new(-170, 24, 1315),
		Vector3.new(-250, 28, 1370),
		Vector3.new(-300, 30, 1400),
		Vector3.new(-330, 36, 1460),
		Vector3.new(-360, 42, 1510),
	},

	SpiderHollowRoute = {
		Vector3.new(20, 16, 1220),
		Vector3.new(105, 12, 1275),
		Vector3.new(195, 7, 1340),
		Vector3.new(270, 3, 1395),
		Vector3.new(300, 2, 1420),
		Vector3.new(330, 1, 1480),
		Vector3.new(360, 0, 1530),
	},

	SpiderReturnRoute = {
		Vector3.new(360, 0, 1530),
		Vector3.new(320, 3, 1570),
		Vector3.new(245, 8, 1595),
		Vector3.new(155, 15, 1605),
		Vector3.new(15, 22, 1600),
	},
}

return table.freeze(WorldLayout)
