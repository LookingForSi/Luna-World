--!strict
return function(TestRunner)
 local Rules=require(game:GetService("ReplicatedStorage").Shared.core.transfer.TransferIntentRules)
 local intent={transferVersion=1,transferId="t",userId=1,characterId="c",sourceRole="Lobby",destinationRole="World",entryPointId="luna_village",expiresAt=20}
 TestRunner.run("validates bounded routing intent",function() local ok=Rules.validate(intent,10,"World"); assert(ok == true); local payload=Rules.routingPayload(intent); assert(payload.userId == nil) end)
 TestRunner.run("rejects hostile authoritative state",function() local hostile=table.clone(intent); hostile.Luna=999; local ok,why=Rules.validate(hostile,10,"World"); assert(ok == false); assert(why == "AuthoritativeStateForbidden") end)
	 TestRunner.run("rejects expired and wrong destinations",function() local ok=Rules.validate(intent,20,"World"); assert(ok == false); local ok2=Rules.validate(intent,10,"Dungeon"); assert(ok2 == false) end)
	 TestRunner.run("rejects disallowed source transitions",function() local hostile=table.clone(intent); hostile.sourceRole="Dungeon"; local ok,why=Rules.validate(hostile,10,"World"); assert(ok == false); assert(why == "TransitionNotAllowed") end)
	 TestRunner.run("rejects malformed routing metadata",function() local malformed=table.clone(intent); malformed.entryPointId=nil; assert(Rules.validate(malformed,10,"World") == false); assert(Rules.validateRouting(malformed,"World") == false) end)
end
