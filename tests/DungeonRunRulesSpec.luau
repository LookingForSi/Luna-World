--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonRunRules)
return function(TestRunner:any)
	TestRunner.run("dungeon lifecycle rejects skips",function() assert(Rules.canTransition("CREATED","ENTERING")); assert(not Rules.canTransition("CREATED","BOSS")); assert(Rules.canTransition("BOSS","COMPLETED")) end)
	TestRunner.run("participants are unique and capped",function() assert(Rules.validateParticipants({1,2,3,4},1)); local ok=Rules.validateParticipants({1,1},1); assert(not ok); ok=Rules.validateParticipants({1,2,3,4,5},1); assert(not ok) end)
	TestRunner.run("encounters and rewards are exactly once",function() local n,ok=Rules.advanceEncounter(0,1,false); assert(ok and n==1); n,ok=Rules.advanceEncounter(n,1,true); assert(not ok and n==1); local claimed={}; local first; first,claimed=Rules.claim(claimed,7); assert(first); local again=Rules.claim(claimed,7); assert(not again) end)
	TestRunner.run("wipe requires every connected participant dead",function() assert(Rules.allDead({1},{[1]=false},{[1]=true}));assert(Rules.allDead({1,2},{[1]=false,[2]=false},{[1]=true,[2]=true})); assert(not Rules.allDead({1,2},{[1]=true,[2]=false},{[1]=true,[2]=true})) end)
	TestRunner.run("checkpoint progression preserves completed encounters",function()assert(Rules.checkpointForEncounter(0)==0);assert(Rules.checkpointForEncounter(1)==1);assert(Rules.checkpointForEncounter(2)==2);assert(Rules.checkpointForEncounter(3)==3);assert(Rules.checkpointForEncounter(4)==3);assert(Rules.canReset("BOSS",false));assert(not Rules.canReset("COMPLETED",true))end)
end
