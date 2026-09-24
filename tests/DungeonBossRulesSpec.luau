--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonBossRules)
return function(TestRunner:any)
	TestRunner.run("guardian enrages once below threshold",function() assert(Rules.phase(100,100,false)=="BASE"); assert(Rules.phase(35,100,false)=="ENRAGED"); assert(Rules.phase(90,100,true)=="ENRAGED"); assert(Rules.phase(0,100,true)=="DEAD") end)
	TestRunner.run("aoe is server-distance based and ignores dead targets",function() assert(Rules.aoeHits(Vector3.zero,Vector3.new(3,0,4),true,5)); assert(not Rules.aoeHits(Vector3.zero,Vector3.new(6,0,0),true,5)); assert(not Rules.aoeHits(Vector3.zero,Vector3.zero,false,5)) end)
	TestRunner.run("target selection skips dead and absent members",function() assert(Rules.selectTarget({1,2,3},{[1]=false,[2]=true,[3]=true},{[2]=false,[3]=true})==3) end)
end
