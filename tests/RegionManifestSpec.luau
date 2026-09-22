--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contract = require(ReplicatedStorage.Shared.world.MoonfallAuthoringContract)
local Manifest = require(ReplicatedStorage.Shared.world.MoonfallRegionManifest)
local TravelDefinitions = require(ReplicatedStorage.Shared.definitions.TravelDefinitions)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local WorldLayoutValidator = require(ReplicatedStorage.Shared.world.WorldLayoutValidator)

return function(TestRunner)
	TestRunner.run("Moonfall region manifest wraps canonical world data", function()
		assert(Manifest.id == "moonfall")
		assert(Manifest.rootName == Contract.RootName)
		assert(Manifest.managedBy == Contract.AuthoredManagedBy)
		assert(Manifest.terrainRevision == Contract.TerrainRevision)
		assert(Manifest.zones == WorldLayout.Zones)
		assert(Manifest.pointsOfInterest == WorldLayout.PointsOfInterest)
		assert(Manifest.spawnMarkers == WorldLayout.SpawnMarkers)
		assert(Manifest.travelEntries == TravelDefinitions)

		local valid, errors = WorldLayoutValidator.validate(WorldLayout)
		assert(valid, table.concat(errors, "; "))
	end)

	TestRunner.run("Moonfall manifest stable IDs are globally unique across region entities", function()
		local seen: { [string]: boolean } = {}
		for _, entries in {
			Manifest.zones,
			Manifest.pointsOfInterest,
			Manifest.spawnMarkers,
		} do
			for _, entry in entries do
				assert(typeof(entry.id) == "string" and entry.id ~= "")
				assert(not seen[entry.id], "duplicate region stable ID: " .. entry.id)
				seen[entry.id] = true
			end
		end
	end)

	TestRunner.run("Moonfall travel entries use stable keyed IDs", function()
		local count = 0
		for key, definition in Manifest.travelEntries do
			assert(typeof(key) == "string" and key ~= "")
			assert(definition.id == key)
			assert(typeof(definition.villageNpcId) == "string")
			assert(typeof(definition.fieldNpcId) == "string")
			count += 1
		end
		assert(count > 0)
	end)
end
