--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local WorldLayoutValidator = require(ReplicatedStorage.Shared.world.WorldLayoutValidator)

type Runner = {
	test: (self: Runner, name: string, callback: () -> ()) -> (),
}

local WorldLayoutSpec = {}

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local result = {}
	for key, childValue in pairs(value) do
		result[deepClone(key)] = deepClone(childValue)
	end

	return result
end

local function assertInvalid(layout: any, expectedErrorFragment: string)
	local valid, errors = WorldLayoutValidator.validate(layout)
	assert(not valid, "expected layout validation to fail")

	for _, validationError in ipairs(errors) do
		if string.find(validationError, expectedErrorFragment, 1, true) ~= nil then
			return
		end
	end

	error(string.format("expected an error containing '%s', got: %s", expectedErrorFragment, table.concat(errors, "; ")))
end

local function findSpawn(layout: any, id: string): any
	for _, marker in ipairs(layout.SpawnMarkers) do
		if marker.id == id then
			return marker
		end
	end
	error(string.format("missing spawn '%s' in test fixture", id))
end

local function findPoi(layout: any, id: string): any
	for _, poi in ipairs(layout.PointsOfInterest) do
		if poi.id == id then
			return poi
		end
	end
	error(string.format("missing POI '%s' in test fixture", id))
end

function WorldLayoutSpec.register(runner: Runner)
	runner:test("canonical layout passes", function()
		local valid, errors = WorldLayoutValidator.validate(WorldLayout)
		assert(valid, table.concat(errors, "; "))
		assert(#errors == 0, "a valid layout must return no errors")
	end)

	runner:test("duplicate ID fails", function()
		local layout = deepClone(WorldLayout)
		layout.SpawnMarkers[1].id = layout.PointsOfInterest[1].id
		assertInvalid(layout, "duplicate stable ID")
	end)

	runner:test("invalid level range fails", function()
		local layout = deepClone(WorldLayout)
		layout.Zones[2].levelMin = 4
		layout.Zones[2].levelMax = 3
		assertInvalid(layout, "levelMin <= levelMax")
	end)

	runner:test("non-positive radius fails", function()
		local layout = deepClone(WorldLayout)
		layout.SpawnMarkers[1].radius = 0
		assertInvalid(layout, "radius greater than zero")
	end)

	runner:test("spawn marker with unknown zone fails", function()
		local layout = deepClone(WorldLayout)
		layout.SpawnMarkers[#layout.SpawnMarkers].zoneId = "zone_missing"
		assertInvalid(layout, "must reference an existing zone")
	end)

	runner:test("future reservation spawns remain disabled", function()
		assert(findSpawn(WorldLayout, "spawn_goblin_camp_elite_future").spawnEnabled == false)
		assert(findSpawn(WorldLayout, "spawn_spider_hollow_brood").spawnEnabled == false)
	end)

	runner:test("invalid spawnEnabled shape fails", function()
		local layout = deepClone(WorldLayout)
		findSpawn(layout, "spawn_goblin_camp_elite_future").spawnEnabled = "yes"
		assertInvalid(layout, "spawnEnabled must be boolean when provided")
	end)

	runner:test("missing required POI fails", function()
		local layout = deepClone(WorldLayout)
		table.remove(layout.PointsOfInterest, 2)
		assertInvalid(layout, "missing required point of interest ID 'poi_training_ground'")
	end)

	runner:test("exit too close fails", function()
		local layout = deepClone(WorldLayout)
		findPoi(layout, "exit_moonfall_road").position = Vector3.new(0, 4, 699)
		assertInvalid(layout, "gate-to-exit XZ distance must be at least 700 studs")
	end)

	runner:test("Moonfall road starts at Meadows exit", function()
		local layout = deepClone(WorldLayout)
		layout.MoonfallRoadRoute[1] = Vector3.new(20, 4, 900)
		assertInvalid(layout, "MoonfallRoadRoute must begin at exit_moonfall_road")
	end)

	runner:test("Moonfall road ends at Dark Woodland entry", function()
		local layout = deepClone(WorldLayout)
		layout.MoonfallRoadRoute[#layout.MoonfallRoadRoute] = Vector3.new(0, 26, 1800)
		assertInvalid(layout, "MoonfallRoadRoute must end at entry_dark_woodland")
	end)

	runner:test("Goblin Camp remains above crossroads", function()
		local layout = deepClone(WorldLayout)
		findPoi(layout, "poi_goblin_camp").position = Vector3.new(-300, 16, 1400)
		assertInvalid(layout, "Goblin Camp must be above Moonfall crossroads")
	end)

	runner:test("Spider Hollow remains below crossroads", function()
		local layout = deepClone(WorldLayout)
		findPoi(layout, "poi_spider_hollow").position = Vector3.new(300, 16, 1420)
		assertInvalid(layout, "Spider Hollow must be below Moonfall crossroads")
	end)

	runner:test("Dark Woodland handoff remains deeper along +Z", function()
		local layout = deepClone(WorldLayout)
		findPoi(layout, "entry_dark_woodland").position = Vector3.new(0, 26, 1700)
		assertInvalid(layout, "Dark Woodland handoff must continue deeper along +Z")
	end)
end

return table.freeze(WorldLayoutSpec)
