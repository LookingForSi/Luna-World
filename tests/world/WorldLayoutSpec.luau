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

	runner:test("missing required POI fails", function()
		local layout = deepClone(WorldLayout)
		table.remove(layout.PointsOfInterest, 2)
		assertInvalid(layout, "missing required point of interest ID 'poi_training_ground'")
	end)

	runner:test("exit too close fails", function()
		local layout = deepClone(WorldLayout)
		for _, pointOfInterest in ipairs(layout.PointsOfInterest) do
			if pointOfInterest.id == "exit_moonfall_road" then
				pointOfInterest.position = Vector3.new(0, 4, 699)
				break
			end
		end
		assertInvalid(layout, "gate-to-exit XZ distance must be at least 700 studs")
	end)
end

return table.freeze(WorldLayoutSpec)
