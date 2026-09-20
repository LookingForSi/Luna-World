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
	count: number?,
	socialGroupId: string?,
	patrolRadius: number?,
	patrolCycleSeconds: number?,
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
		},
		{
			id = "zone_old_cemetery",
			displayName = "Old Cemetery",
			levelMin = 7,
			levelMax = 9,
		},
		{
			id = "zone_fallen_shrine",
			displayName = "Fallen Shrine",
			levelMin = 7,
			levelMax = 9,
		},
		{
			id = "zone_ancient_approach",
			displayName = "Ancient Approach",
			levelMin = 8,
			levelMax = 10,
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
			center = scaleXZ(280, 60, 960),
			size = scaleXZ(440, 150, 405),
			priority = 10,
			minSafeY = 12,
		},
		{
			zoneId = "zone_spider_hollow",
			center = scaleXZ(-280, 6, 970),
			size = scaleXZ(450, 120, 418),
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
			center = scaleXZ(280, 102, 1415),
			size = scaleXZ(293, 150, 260),
			priority = 8,
			minSafeY = 40,
		},
		{
			zoneId = "zone_fallen_shrine",
			center = scaleXZ(-280, 108, 1430),
			size = scaleXZ(282, 150, 260),
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
		{ id = "poi_goblin_camp", position = scaleXZ(280, 60, 960) },
		{ id = "poi_goblin_lookout", position = scaleXZ(360, 68, 1035) },
		{ id = "poi_spider_hollow", position = scaleXZ(-280, 4, 970) },
		{ id = "poi_spider_cave_mouth", position = scaleXZ(-360, 4, 1030) },
		{ id = "poi_dark_woodland_gate", position = scaleXZ(0, 30, 1340) },
		{ id = "entry_dark_woodland", position = scaleXZ(0, 36, 1430) },

		{ id = "poi_old_cemetery", position = scaleXZ(280, 102, 1415) },
		{ id = "poi_fallen_shrine", position = scaleXZ(-280, 108, 1430) },
		{ id = "poi_ancient_approach", position = scaleXZ(0, 124, 1770) },
		{ id = "poi_selene_horizon", position = scaleXZ(0, 150, 2070) },
	},

	SpawnMarkers = {
		-- Farm / Meadows: intentionally non-social starter wolves.
		{ id = "spawn_young_wolf_farm", mobId = "mob_young_wolf", position = scaleXZ(-170, 8, 375), radius = scaleDistance(72), zoneId = "zone_luna_meadows", count = 6, patrolRadius = scaleDistance(28), patrolCycleSeconds = 8 },

		-- Stone Circle: three small linked wolf pairs plus a leader.
		{ id = "spawn_wolf_pack_south", mobId = "mob_grey_wolf", position = scaleXZ(105, 7, 555), radius = scaleDistance(32), zoneId = "zone_luna_meadows", count = 2, socialGroupId = "wolf_pack_south", patrolRadius = scaleDistance(24), patrolCycleSeconds = 7 },
		{ id = "spawn_wolf_pack_east", mobId = "mob_grey_wolf", position = scaleXZ(155, 7, 590), radius = scaleDistance(32), zoneId = "zone_luna_meadows", count = 2, socialGroupId = "wolf_pack_east", patrolRadius = scaleDistance(24), patrolCycleSeconds = 7 },
		{ id = "spawn_wolf_pack_north", mobId = "mob_grey_wolf", position = scaleXZ(115, 7, 625), radius = scaleDistance(28), zoneId = "zone_luna_meadows", count = 2, socialGroupId = "wolf_pack_north", patrolRadius = scaleDistance(22), patrolCycleSeconds = 7 },
		{ id = "spawn_wolf_pack_leader", mobId = "mob_wolf_pack_leader", position = scaleXZ(140, 8, 610), radius = scaleDistance(18), zoneId = "zone_luna_meadows", socialGroupId = "wolf_pack_north", patrolRadius = scaleDistance(16), patrolCycleSeconds = 9 },

		-- Moonfall Road warning patrol.
		{ id = "spawn_goblin_scout_road", mobId = "mob_goblin_scout", position = scaleXZ(70, 22, 900), radius = scaleDistance(34), zoneId = "zone_moonfall_road", count = 2, socialGroupId = "goblin_road_patrol", patrolRadius = scaleDistance(48), patrolCycleSeconds = 10 },

		-- Goblin Camp: four paired perimeter patrols plus interior groups.
		{ id = "spawn_goblin_patrol_south", mobId = "mob_goblin_scout", position = scaleXZ(215, 48, 900), radius = scaleDistance(24), zoneId = "zone_goblin_camp", count = 2, socialGroupId = "goblin_patrol_south", patrolRadius = scaleDistance(48), patrolCycleSeconds = 10 },
		{ id = "spawn_goblin_patrol_east", mobId = "mob_goblin_scout", position = scaleXZ(345, 58, 945), radius = scaleDistance(24), zoneId = "zone_goblin_camp", count = 2, socialGroupId = "goblin_patrol_east", patrolRadius = scaleDistance(42), patrolCycleSeconds = 10 },
		{ id = "spawn_goblin_patrol_north", mobId = "mob_goblin_scout", position = scaleXZ(305, 62, 1040), radius = scaleDistance(24), zoneId = "zone_goblin_camp", count = 2, socialGroupId = "goblin_patrol_north", patrolRadius = scaleDistance(44), patrolCycleSeconds = 10 },
		{ id = "spawn_goblin_patrol_west", mobId = "mob_goblin_scout", position = scaleXZ(205, 54, 1000), radius = scaleDistance(24), zoneId = "zone_goblin_camp", count = 2, socialGroupId = "goblin_patrol_west", patrolRadius = scaleDistance(40), patrolCycleSeconds = 10 },
		{ id = "spawn_goblin_scout_inner", mobId = "mob_goblin_scout", position = scaleXZ(265, 60, 955), radius = scaleDistance(24), zoneId = "zone_goblin_camp", count = 2, socialGroupId = "goblin_gate_group" },
		{ id = "spawn_goblin_warrior_camp", mobId = "mob_goblin_warrior", position = scaleXZ(300, 61, 980), radius = scaleDistance(26), zoneId = "zone_goblin_camp", count = 2, socialGroupId = "goblin_courtyard" },
		{ id = "spawn_goblin_shaman_camp", mobId = "mob_goblin_shaman", position = scaleXZ(285, 62, 1010), radius = scaleDistance(14), zoneId = "zone_goblin_camp", socialGroupId = "goblin_courtyard" },
		{ id = "spawn_goblin_chieftain_camp", mobId = "mob_goblin_chieftain", position = scaleXZ(330, 65, 1020), radius = scaleDistance(12), zoneId = "zone_goblin_camp", socialGroupId = "goblin_chief_group" },

		-- Spider Hollow: deliberately no socialGroupId.
		{ id = "spawn_spider_hollow_swarm", mobId = "mob_spider", position = scaleXZ(-280, 5, 970), radius = scaleDistance(82), zoneId = "zone_spider_hollow", count = 8, patrolRadius = scaleDistance(16), patrolCycleSeconds = 11 },
		{ id = "spawn_spider_hollow_brood", mobId = "mob_brood_spider", position = scaleXZ(-345, 5, 1025), radius = scaleDistance(34), zoneId = "zone_spider_hollow", count = 2, patrolRadius = scaleDistance(12), patrolCycleSeconds = 12 },

		-- Dark Woodland.
		{ id = "spawn_dire_wolf_west", mobId = "mob_dire_wolf", position = scaleXZ(-150, 42, 1360), radius = scaleDistance(45), zoneId = "zone_dark_woodland", count = 3, socialGroupId = "dire_pack_west", patrolRadius = scaleDistance(32), patrolCycleSeconds = 8 },
		{ id = "spawn_dire_wolf_east", mobId = "mob_dire_wolf", position = scaleXZ(145, 44, 1390), radius = scaleDistance(45), zoneId = "zone_dark_woodland", count = 3, socialGroupId = "dire_pack_east", patrolRadius = scaleDistance(32), patrolCycleSeconds = 8 },
		{ id = "spawn_forest_spider_dark", mobId = "mob_forest_spider", position = scaleXZ(-30, 38, 1490), radius = scaleDistance(74), zoneId = "zone_dark_woodland", count = 4, patrolRadius = scaleDistance(14), patrolCycleSeconds = 12 },
		{ id = "spawn_dire_wolf_alpha", mobId = "mob_dire_wolf_alpha", position = scaleXZ(100, 48, 1510), radius = scaleDistance(20), zoneId = "zone_dark_woodland", socialGroupId = "dire_pack_east" },

		-- Old Cemetery.
		{ id = "spawn_skeleton_cemetery_a", mobId = "mob_skeleton", position = scaleXZ(240, 100, 1385), radius = scaleDistance(38), zoneId = "zone_old_cemetery", count = 3, socialGroupId = "cemetery_group_a", patrolRadius = scaleDistance(18), patrolCycleSeconds = 12 },
		{ id = "spawn_skeleton_cemetery_b", mobId = "mob_skeleton", position = scaleXZ(315, 102, 1435), radius = scaleDistance(34), zoneId = "zone_old_cemetery", count = 3, socialGroupId = "cemetery_group_b", patrolRadius = scaleDistance(18), patrolCycleSeconds = 12 },
		{ id = "spawn_skeleton_archer_cemetery", mobId = "mob_skeleton_archer", position = scaleXZ(285, 105, 1470), radius = scaleDistance(44), zoneId = "zone_old_cemetery", count = 3, socialGroupId = "cemetery_group_b" },
		{ id = "spawn_grave_guardian", mobId = "mob_grave_guardian", position = scaleXZ(335, 107, 1485), radius = scaleDistance(14), zoneId = "zone_old_cemetery", socialGroupId = "cemetery_guardian" },

		-- Fallen Shrine.
		{ id = "spawn_fallen_acolytes", mobId = "mob_fallen_acolyte", position = scaleXZ(-285, 108, 1420), radius = scaleDistance(55), zoneId = "zone_fallen_shrine", count = 5, socialGroupId = "shrine_casters", patrolRadius = scaleDistance(14), patrolCycleSeconds = 12 },
		{ id = "spawn_shrine_guardians", mobId = "mob_shrine_guardian", position = scaleXZ(-245, 110, 1470), radius = scaleDistance(42), zoneId = "zone_fallen_shrine", count = 3, socialGroupId = "shrine_guardians" },

		-- Ancient Approach: sparse but heavy.
		{ id = "spawn_ancient_sentinels", mobId = "mob_ancient_sentinel", position = scaleXZ(-70, 122, 1725), radius = scaleDistance(78), zoneId = "zone_ancient_approach", count = 4, patrolRadius = scaleDistance(16), patrolCycleSeconds = 14 },
		{ id = "spawn_ancient_watchers", mobId = "mob_ancient_watcher", position = scaleXZ(90, 126, 1790), radius = scaleDistance(54), zoneId = "zone_ancient_approach", count = 2 },
		{ id = "spawn_moonbound_warden", mobId = "mob_moonbound_warden", position = scaleXZ(0, 130, 1870), radius = scaleDistance(18), zoneId = "zone_ancient_approach" },
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
		scaleXZ(80, 24, 962.5),
		scaleXZ(160, 34, 957.5),
		scaleXZ(227.5, 46, 957.5),
		scaleXZ(280, 60, 960),
		scaleXZ(320, 64, 995),
		scaleXZ(360, 68, 1035),
	},

	SpiderHollowRoute = {
		scaleXZ(0, 18, 970),
		scaleXZ(-85, 15, 962.5),
		scaleXZ(-165, 11, 960),
		scaleXZ(-235, 7, 965),
		scaleXZ(-280, 4, 970),
		scaleXZ(-320, 4, 1000),
		scaleXZ(-360, 4, 1030),
	},

	SpiderReturnRoute = {
		scaleXZ(-360, 4, 1030),
		scaleXZ(-315, 8, 1075),
		scaleXZ(-225, 14, 1115),
		scaleXZ(-130, 22, 1150),
		scaleXZ(0, 25, 1180),
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
