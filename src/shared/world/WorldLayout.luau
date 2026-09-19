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
}

export type WorldLayoutDefinition = {
	Dimensions: {
		VillageFootprint: Vector2,
		VillageElevationAboveMeadows: number,
		MeadowsRouteLength: number,
	},
	Zones: { ZoneDefinition },
	PointsOfInterest: { PointOfInterestDefinition },
	SpawnMarkers: { SpawnMarkerDefinition },
	Route: { Vector3 },
}

local WorldLayout: WorldLayoutDefinition = {
	Dimensions = {
		VillageFootprint = Vector2.new(250, 220),
		VillageElevationAboveMeadows = 36,
		MeadowsRouteLength = 900,
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
}

return table.freeze(WorldLayout)
