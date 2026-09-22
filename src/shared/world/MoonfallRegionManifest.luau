--!strict

local Contract = require(script.Parent.MoonfallAuthoringContract)
local WorldLayout = require(script.Parent.WorldLayout)
local TravelDefinitions = require(script.Parent.Parent.definitions.TravelDefinitions)

local manifest = {
	id = "moonfall",
	rootName = Contract.RootName,
	managedBy = Contract.AuthoredManagedBy,
	terrainRevision = Contract.TerrainRevision,
	zones = WorldLayout.Zones,
	pointsOfInterest = WorldLayout.PointsOfInterest,
	spawnMarkers = WorldLayout.SpawnMarkers,
	travelEntries = TravelDefinitions,
}

return table.freeze(manifest)
