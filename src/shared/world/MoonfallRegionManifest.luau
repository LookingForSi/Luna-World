--!strict
local WorldLayout=require(script.Parent.WorldLayout)
return table.freeze({id="moonfall",zones=WorldLayout.Zones,pointsOfInterest=WorldLayout.PointsOfInterest,spawnMarkers=WorldLayout.SpawnMarkers,travelEntries=WorldLayout.TravelEntries})
