--!strict

local PartyRules = require(game.ReplicatedStorage.Shared.party.PartyRules)
local RequestRules = require(game.ReplicatedStorage.Shared.party.PartyRequestRules)

return function(TestRunner)
	TestRunner.run("simultaneous final-slot transitions cannot exceed the cap", function()
		local state = { leaderUserId=1, memberUserIds={1,2,3}, nextLootCursor=1 }
		assert(PartyRules.canAccept(state, false, false, true))
		state = PartyRules.addMember(state, 4)
		assert(#state.memberUserIds == 4)
		assert(not PartyRules.canAccept(state, false, false, true))
		assert(PartyRules.addMember(state, 5) == state)
	end)

	TestRunner.run("spoofed identifiers cannot select another party action", function()
		assert(RequestRules.validate(1, { action="Leave", targetUserId=999 }) == "Leave")
		assert(RequestRules.validate(1, { action="Accept", inviteId=999 }) == nil)
		assert(RequestRules.validate(1, { action="Invite", targetUserId=math.huge }) == nil)
	end)

	TestRunner.run("death and respawn do not mutate membership state", function()
		local state = { leaderUserId=1, memberUserIds={1,2}, nextLootCursor=1 }
		local before = table.concat(state.memberUserIds, ",")
		local shares = PartyRules.splitXP(40, { 1 })
		assert(shares[1] == 40 and table.concat(state.memberUserIds, ",") == before)
	end)
end
