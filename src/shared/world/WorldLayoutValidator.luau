--!strict

local MINIMUM_GATE_TO_EXIT_DISTANCE = 700

local REQUIRED_ZONE_IDS = {
	"zone_luna_village",
	"zone_luna_meadows",
	"zone_moonfall_road",
	"zone_goblin_camp",
	"zone_spider_hollow",
}

local REQUIRED_POI_IDS = {
	"poi_main_gate",
	"poi_training_ground",
	"poi_blacksmith",
	"poi_village_square",
	"poi_merchant",
	"poi_residential",
	"poi_elder_house",
	"poi_shrine",
	"poi_moonfall_farm",
	"poi_meadow_bridge",
	"poi_stone_circle",
	"exit_moonfall_road",
	"poi_broken_wagon",
	"poi_moonfall_crossroads",
	"poi_old_waystone",
	"poi_goblin_camp",
	"poi_goblin_lookout",
	"poi_spider_hollow",
	"poi_spider_cave_mouth",
	"poi_dark_woodland_gate",
	"entry_dark_woodland",
}

local REQUIRED_SPAWN_IDS = {
	"spawn_young_wolf_farm",
	"spawn_wolf_stone_circle",
	"spawn_spider_meadow_pocket",
	"spawn_goblin_scout_outer",
	"spawn_goblin_scout_road",
	"spawn_goblin_warrior_camp",
	"spawn_goblin_camp_elite_future",
	"spawn_spider_hollow_outer",
	"spawn_spider_hollow_mid",
	"spawn_spider_hollow_brood",
}

local WorldLayoutValidator = {}

local function getList(layout: { [any]: any }, fieldName: string, errors: { string }): { any }
	local value = layout[fieldName]
	if type(value) ~= "table" then
		table.insert(errors, string.format("%s must be a table", fieldName))
		return {}
	end

	return value
end

local function collectIds(
	entries: { any },
	categoryName: string,
	seenIds: { [string]: string },
	errors: { string }
): { [string]: any }
	local entriesById = {}

	for index, entry in ipairs(entries) do
		if type(entry) ~= "table" then
			table.insert(errors, string.format("%s[%d] must be a table", categoryName, index))
			continue
		end

		local id = entry.id
		if type(id) ~= "string" or id == "" then
			table.insert(errors, string.format("%s[%d] must have a non-empty string id", categoryName, index))
			continue
		end

		local previousCategory = seenIds[id]
		if previousCategory ~= nil then
			table.insert(
				errors,
				string.format("duplicate stable ID '%s' in %s and %s", id, previousCategory, categoryName)
			)
		else
			seenIds[id] = categoryName
			entriesById[id] = entry
		end
	end

	return entriesById
end

local function requireIds(requiredIds: { string }, entriesById: { [string]: any }, categoryName: string, errors: { string })
	for _, requiredId in ipairs(requiredIds) do
		if entriesById[requiredId] == nil then
			table.insert(errors, string.format("missing required %s ID '%s'", categoryName, requiredId))
		end
	end
end

local function validateLevelRanges(entries: { any }, categoryName: string, errors: { string })
	for index, entry in ipairs(entries) do
		if type(entry) ~= "table" then
			continue
		end

		local levelMin = entry.levelMin
		local levelMax = entry.levelMax
		if type(levelMin) ~= "number" or type(levelMax) ~= "number" then
			table.insert(errors, string.format("%s[%d] must define numeric levelMin and levelMax", categoryName, index))
		elseif not (levelMin <= levelMax) then
			table.insert(errors, string.format("%s '%s' must satisfy levelMin <= levelMax", categoryName, tostring(entry.id)))
		end
	end
end

local function validateRoute(route: { any }, routeName: string, errors: { string })
	if #route < 2 then
		table.insert(errors, string.format("%s must contain at least two points", routeName))
	end

	for index, position in ipairs(route) do
		if typeof(position) ~= "Vector3" then
			table.insert(errors, string.format("%s[%d] must be a Vector3", routeName, index))
		end
	end
end

local function samePosition(first: any, second: any): boolean
	return typeof(first) == "Vector3" and typeof(second) == "Vector3" and first == second
end

function WorldLayoutValidator.validate(layout: any): (boolean, { string })
	local errors = {}
	if type(layout) ~= "table" then
		table.insert(errors, "layout must be a table")
		return false, errors
	end

	local zones = getList(layout, "Zones", errors)
	local zoneVolumes = getList(layout, "ZoneVolumes", errors)
	local pointsOfInterest = getList(layout, "PointsOfInterest", errors)
	local spawnMarkers = getList(layout, "SpawnMarkers", errors)
	local route = getList(layout, "Route", errors)
	local moonfallRoadRoute = getList(layout, "MoonfallRoadRoute", errors)
	local goblinCampRoute = getList(layout, "GoblinCampRoute", errors)
	local spiderHollowRoute = getList(layout, "SpiderHollowRoute", errors)
	local spiderReturnRoute = getList(layout, "SpiderReturnRoute", errors)

	local seenIds = {}
	local zonesById = collectIds(zones, "zone", seenIds, errors)
	local pointsOfInterestById = collectIds(pointsOfInterest, "point of interest", seenIds, errors)
	local spawnMarkersById = collectIds(spawnMarkers, "spawn marker", seenIds, errors)

	requireIds(REQUIRED_ZONE_IDS, zonesById, "zone", errors)
	requireIds(REQUIRED_POI_IDS, pointsOfInterestById, "point of interest", errors)
	requireIds(REQUIRED_SPAWN_IDS, spawnMarkersById, "spawn marker", errors)

	validateLevelRanges(zones, "zone", errors)

	for index, zone in ipairs(zones) do
		if type(zone) == "table" then
			if type(zone.displayName) ~= "string" or zone.displayName == "" then
				table.insert(errors, string.format("zone '%s' must define a non-empty displayName", tostring(zone.id or index)))
			end
		end
	end

	local zoneVolumeCountById = {}
	for index, zoneVolume in ipairs(zoneVolumes) do
		if type(zoneVolume) ~= "table" then
			table.insert(errors, string.format("ZoneVolumes[%d] must be a table", index))
			continue
		end

		local zoneId = zoneVolume.zoneId
		if type(zoneId) ~= "string" or zonesById[zoneId] == nil then
			table.insert(errors, string.format("ZoneVolumes[%d] must reference an existing zone", index))
		else
			zoneVolumeCountById[zoneId] = (zoneVolumeCountById[zoneId] or 0) + 1
		end

		if typeof(zoneVolume.center) ~= "Vector3" then
			table.insert(errors, string.format("ZoneVolumes[%d] center must be a Vector3", index))
		end
		if typeof(zoneVolume.size) ~= "Vector3"
			or zoneVolume.size.X <= 0
			or zoneVolume.size.Y <= 0
			or zoneVolume.size.Z <= 0 then
			table.insert(errors, string.format("ZoneVolumes[%d] size must be a positive Vector3", index))
		end
		if type(zoneVolume.priority) ~= "number" then
			table.insert(errors, string.format("ZoneVolumes[%d] priority must be numeric", index))
		end
		if type(zoneVolume.minSafeY) ~= "number" then
			table.insert(errors, string.format("ZoneVolumes[%d] minSafeY must be numeric", index))
		end
	end

	for _, requiredZoneId in ipairs(REQUIRED_ZONE_IDS) do
		if zoneVolumeCountById[requiredZoneId] ~= 1 then
			table.insert(errors, string.format("zone '%s' must define exactly one presentation volume", requiredZoneId))
		end
	end

	for index, spawnMarker in ipairs(spawnMarkers) do
		if type(spawnMarker) == "table" then
			local radius = spawnMarker.radius
			if type(radius) ~= "number" or not (radius > 0) then
				table.insert(errors, string.format(
					"spawn marker '%s' must have radius greater than zero",
					tostring(spawnMarker.id or index)
				))
			end

			local spawnEnabled = spawnMarker.spawnEnabled
			if spawnEnabled ~= nil and type(spawnEnabled) ~= "boolean" then
				table.insert(errors, string.format(
					"spawn marker '%s' spawnEnabled must be boolean when provided",
					tostring(spawnMarker.id or index)
				))
			end

			local zoneId = spawnMarker.zoneId
			if type(zoneId) ~= "string" or zonesById[zoneId] == nil then
				table.insert(errors, string.format(
					"spawn marker '%s' must reference an existing zone",
					tostring(spawnMarker.id or index)
				))
			end
		end
	end

	validateRoute(route, "Route", errors)
	validateRoute(moonfallRoadRoute, "MoonfallRoadRoute", errors)
	validateRoute(goblinCampRoute, "GoblinCampRoute", errors)
	validateRoute(spiderHollowRoute, "SpiderHollowRoute", errors)
	validateRoute(spiderReturnRoute, "SpiderReturnRoute", errors)

	local gate = pointsOfInterestById.poi_main_gate
	local roadExit = pointsOfInterestById.exit_moonfall_road
	if gate ~= nil and roadExit ~= nil then
		local gatePosition = gate.position
		local exitPosition = roadExit.position
		if typeof(gatePosition) ~= "Vector3" or typeof(exitPosition) ~= "Vector3" then
			table.insert(errors, "poi_main_gate and exit_moonfall_road must have Vector3 positions")
		else
			local offsetX = exitPosition.X - gatePosition.X
			local offsetZ = exitPosition.Z - gatePosition.Z
			local xzDistance = math.sqrt(offsetX * offsetX + offsetZ * offsetZ)
			if xzDistance < MINIMUM_GATE_TO_EXIT_DISTANCE then
				table.insert(
					errors,
					string.format("gate-to-exit XZ distance must be at least %d studs", MINIMUM_GATE_TO_EXIT_DISTANCE)
				)
			end
		end
	end

	local crossroads = pointsOfInterestById.poi_moonfall_crossroads
	local goblinCamp = pointsOfInterestById.poi_goblin_camp
	local spiderHollow = pointsOfInterestById.poi_spider_hollow
	local darkGate = pointsOfInterestById.poi_dark_woodland_gate
	local darkEntry = pointsOfInterestById.entry_dark_woodland

	if roadExit ~= nil and #moonfallRoadRoute > 0
		and not samePosition(moonfallRoadRoute[1], roadExit.position) then
		table.insert(errors, "MoonfallRoadRoute must begin at exit_moonfall_road")
	end
	if darkEntry ~= nil and #moonfallRoadRoute > 0
		and not samePosition(moonfallRoadRoute[#moonfallRoadRoute], darkEntry.position) then
		table.insert(errors, "MoonfallRoadRoute must end at entry_dark_woodland")
	end
	if crossroads ~= nil then
		if #goblinCampRoute > 0 and not samePosition(goblinCampRoute[1], crossroads.position) then
			table.insert(errors, "GoblinCampRoute must begin at poi_moonfall_crossroads")
		end
		if #spiderHollowRoute > 0 and not samePosition(spiderHollowRoute[1], crossroads.position) then
			table.insert(errors, "SpiderHollowRoute must begin at poi_moonfall_crossroads")
		end
	end
	if spiderHollow ~= nil and #spiderReturnRoute > 0
		and spiderHollowRoute[#spiderHollowRoute] ~= spiderReturnRoute[1] then
		table.insert(errors, "SpiderReturnRoute must begin at the end of SpiderHollowRoute")
	end

	if crossroads ~= nil and goblinCamp ~= nil
		and typeof(crossroads.position) == "Vector3" and typeof(goblinCamp.position) == "Vector3"
		and goblinCamp.position.Y <= crossroads.position.Y then
		table.insert(errors, "Goblin Camp must be above Moonfall crossroads")
	end

	if crossroads ~= nil and spiderHollow ~= nil
		and typeof(crossroads.position) == "Vector3" and typeof(spiderHollow.position) == "Vector3"
		and spiderHollow.position.Y >= crossroads.position.Y then
		table.insert(errors, "Spider Hollow must be below Moonfall crossroads")
	end

	if crossroads ~= nil and darkGate ~= nil and darkEntry ~= nil
		and typeof(crossroads.position) == "Vector3"
		and typeof(darkGate.position) == "Vector3"
		and typeof(darkEntry.position) == "Vector3" then
		if darkGate.position.Z <= crossroads.position.Z or darkEntry.position.Z <= darkGate.position.Z then
			table.insert(errors, "Dark Woodland handoff must continue deeper along +Z")
		end
	end

	return #errors == 0, errors
end

return table.freeze(WorldLayoutValidator)
