--!strict

local WorldLayout = require(script.Parent.WorldLayout)

export type RegionManifest = {
	id: string,
	rootName: string,
	managedBy: string,
	terrainRevision: string,
	zones: { WorldLayout.ZoneDefinition },
	pointsOfInterest: { WorldLayout.PointOfInterestDefinition },
	spawnMarkers: { WorldLayout.SpawnMarkerDefinition },
	travelEntries: { [string]: any },
}

return table.freeze({})
