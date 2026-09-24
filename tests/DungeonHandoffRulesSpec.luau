--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Rules=require(ReplicatedStorage.Shared.dungeon.DungeonHandoffRules)
return function(TestRunner:any)
	local base={schemaVersion=1,runId="run-12345678",nonce="0123456789abcdef",destinationRole="Dungeon",expiresAt=20,leaderUserId=1,memberUserIds={1,2}}
	TestRunner.run("handoff admits only listed member",function() assert(Rules.validate(base,10,"Dungeon",2)); local ok,why=Rules.validate(base,10,"Dungeon",3); assert(not ok and why=="NotParticipant") end)
	TestRunner.run("handoff rejects expiry destination and malformed ids",function() local ok=Rules.validate(base,21,"Dungeon",1); assert(not ok); ok=Rules.validate(base,10,"World",1); assert(not ok); local hostile=table.clone(base); hostile.memberUserIds={0/0}; ok=Rules.validate(hostile,10,"Dungeon",1); assert(not ok) end)
end
