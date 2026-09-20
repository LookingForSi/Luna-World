--!strict
local QuestDefinitions=require(game.ReplicatedStorage.Shared.definitions.QuestDefinitions)
local MobDefinitions=require(game.ReplicatedStorage.Shared.definitions.MobDefinitions)
local NpcDefinitions=require(game.ReplicatedStorage.Shared.definitions.NpcDefinitions)
local WorldLayout=require(game.ReplicatedStorage.Shared.world.WorldLayout)
return function(TestRunner)
	TestRunner.run("Q1 through Q7 reference authoritative content",function()
		local pois={};for _,p in WorldLayout.PointsOfInterest do pois[p.id]=true end
		local count=0;for id,q in QuestDefinitions do count+=1;assert(q.id==id and NpcDefinitions[q.giverNpcId] and NpcDefinitions[q.turnInNpcId]);assert(type(q.description)=="string" and #q.description>=100,"quest descriptions must contain readable narrative context");for _,o in q.objectives do assert(type(o.displayText)=="string" and #o.displayText>0);if o.mobId then assert(MobDefinitions[o.mobId]) end;if o.npcId then assert(NpcDefinitions[o.npcId]) end;if o.poiId then assert(pois[o.poiId]) end;if o.waypointPoiId then assert(pois[o.waypointPoiId]) end end end
		assert(count==7)
		assert(QuestDefinitions.quest_young_wolf_problem.objectives[1].waypointPoiId=="poi_young_wolf_staging","young wolf quest must guide players to the wolf staging area, not back to the farmer")
	end)
end
