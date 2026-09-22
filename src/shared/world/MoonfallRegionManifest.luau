--!strict

local Contract = require(script.Parent.MoonfallAuthoringContract)
local WorldLayout = require(script.Parent.WorldLayout)

return table.freeze({
	id = "moonfall",
	rootName = Contract.RootName,
	managedBy = Contract.AuthoredManagedBy,
	terrainRevision = Contract.TerrainRevision,
	zones = WorldLayout.Zones,
	pointsOfInterest = WorldLayout.PointsOfInterest,
	spawnMarkers = WorldLayout.SpawnMarkers,
	travelEntries = WorldLayout.TravelEntries,
})
