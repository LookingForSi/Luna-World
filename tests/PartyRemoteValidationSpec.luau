--!strict

local Rules = require(game.ReplicatedStorage.Shared.party.PartyRequestRules)

return function(TestRunner)
	TestRunner.run("party request validation accepts only the narrow action contract", function()
		assert(Rules.validate(1, { action="Invite", targetUserId=12 }) == "Invite")
		assert(Rules.validate(1, { action="Accept", inviteId="12345678" }) == "Accept")
		assert(Rules.validate(1, { action="Decline", inviteId="12345678" }) == "Decline")
		assert(Rules.validate(1, { action="Leave" }) == "Leave")
	end)

	TestRunner.run("party request validation rejects hostile payloads", function()
		for _, payload in { nil, "Invite", 3, { action="Unknown" }, { action="Invite" },
			{ action="Invite", targetUserId=0 }, { action="Invite", targetUserId=-1 },
			{ action="Invite", targetUserId=1.5 }, { action="Invite", targetUserId=0/0 },
			{ action="Accept", inviteId="short" } } do
			assert(Rules.validate(1, payload) == nil)
		end
		assert(Rules.validate(0, nil) == nil)
		assert(Rules.validate(2, { action="Leave" }) == nil)
	end)
end
