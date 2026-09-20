--!strict
local QuestDefinitions=require(game.ReplicatedStorage.Shared.definitions.QuestDefinitions)
local MobDefinitions=require(game.ReplicatedStorage.Shared.definitions.MobDefinitions)
local NpcDefinitions=require(game.ReplicatedStorage.Shared.definitions.NpcDefinitions)
local WorldLayout=require(game.ReplicatedStorage.Shared.world.WorldLayout)
return function(TestRunner)
	TestRunner.run("Q1 through Q7 reference authoritative content",function()
		local pois={};for _,p in WorldLayout.PointsOfInterest do pois[p.id]=true end
		local count=0;for id,q in QuestDefinitions do count+=1;assert(q.id==id and NpcDefinitions[q.giverNpcId] and NpcDefinitions[q.turnInNpcId]);for _,o in q.objectives do if o.mobId then assert(MobDefinitions[o.mobId]) end;if o.npcId then assert(NpcDefinitions[o.npcId]) end;if o.poiId then assert(pois[o.poiId]) end;if o.waypointPoiId then assert(pois[o.waypointPoiId]) end end end
		assert(count==7)
	end)
end
