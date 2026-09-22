--!strict
return function(TestRunner)
 local Rules=require(game:GetService("ReplicatedStorage").Shared.core.transfer.TransferIntentRules)
 local intent={transferVersion=1,transferId="t",userId=1,characterId="c",sourceRole="Lobby",destinationRole="World",entryPointId="luna_village",expiresAt=20}
 TestRunner.it("validates bounded routing intent",function() local ok=Rules.validate(intent,10,"World"); TestRunner.expectEqual(ok,true); local payload=Rules.routingPayload(intent); TestRunner.expectEqual(payload.userId,nil) end)
 TestRunner.it("rejects hostile authoritative state",function() local hostile=table.clone(intent); hostile.Luna=999; local ok,why=Rules.validate(hostile,10,"World"); TestRunner.expectEqual(ok,false); TestRunner.expectEqual(why,"AuthoritativeStateForbidden") end)
	 TestRunner.it("rejects expired and wrong destinations",function() local ok=Rules.validate(intent,20,"World"); TestRunner.expectEqual(ok,false); local ok2=Rules.validate(intent,10,"Dungeon"); TestRunner.expectEqual(ok2,false) end)
	 TestRunner.it("rejects disallowed source transitions",function() local hostile=table.clone(intent); hostile.sourceRole="Dungeon"; local ok,why=Rules.validate(hostile,10,"World"); TestRunner.expectEqual(ok,false); TestRunner.expectEqual(why,"TransitionNotAllowed") end)
end
