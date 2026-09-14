--!strict

local MINIMUM_GATE_TO_EXIT_DISTANCE = 700

local REQUIRED_ZONE_IDS = {
	"zone_luna_village",
	"zone_luna_meadows",
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
}

local REQUIRED_SPAWN_IDS = {
	"spawn_young_wolf_farm",
	"spawn_wolf_stone_circle",
	"spawn_spider_meadow_pocket",
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

function WorldLayoutValidator.validate(layout: any): (boolean, { string })
	local errors = {}
	if type(layout) ~= "table" then
		table.insert(errors, "layout must be a table")
		return false, errors
	end

	local zones = getList(layout, "Zones", errors)
	local pointsOfInterest = getList(layout, "PointsOfInterest", errors)
	local spawnMarkers = getList(layout, "SpawnMarkers", errors)
	local route = getList(layout, "Route", errors)

	local seenIds = {}
	local zonesById = collectIds(zones, "zone", seenIds, errors)
	local pointsOfInterestById = collectIds(pointsOfInterest, "point of interest", seenIds, errors)
	local spawnMarkersById = collectIds(spawnMarkers, "spawn marker", seenIds, errors)

	requireIds(REQUIRED_ZONE_IDS, zonesById, "zone", errors)
	requireIds(REQUIRED_POI_IDS, pointsOfInterestById, "point of interest", errors)
	requireIds(REQUIRED_SPAWN_IDS, spawnMarkersById, "spawn marker", errors)

	validateLevelRanges(zones, "zone", errors)

	for index, spawnMarker in ipairs(spawnMarkers) do
		if type(spawnMarker) == "table" then
			local radius = spawnMarker.radius
			if type(radius) ~= "number" or not (radius > 0) then
				table.insert(errors, string.format("spawn marker '%s' must have radius greater than zero", tostring(spawnMarker.id or index)))
			end
		end
	end

	if #route < 2 then
		table.insert(errors, "Route must contain at least two points")
	end

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

	return #errors == 0, errors
end

return table.freeze(WorldLayoutValidator)
