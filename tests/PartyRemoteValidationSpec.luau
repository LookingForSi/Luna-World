--!strict

local Rules = require(game.ReplicatedStorage.Shared.party.PartyRequestRules)

return function(TestRunner)
	TestRunner.run("party request validation accepts only the narrow action contract", function()
		assert(Rules.validate(1, { action="Invite", targetUserId=12 }, false) == "Invite")
		assert(Rules.validate(1, { action="Accept", inviteId="12345678" }) == "Accept")
		assert(Rules.validate(1, { action="Decline", inviteId="12345678" }) == "Decline")
		assert(Rules.validate(1, { action="Leave" }) == "Leave")
	end)

	TestRunner.run("studio accepts only finite nonzero integer synthetic user ids", function()
		assert(Rules.validate(1, { action="Invite", targetUserId=-1 }, true) == "Invite")
		assert(Rules.validate(1, { action="Invite", targetUserId=-2 }, true) == "Invite")
		assert(Rules.validate(1, { action="Invite", targetUserId=-1 }, false) == nil)
		for _, userId in { 0, -1.5, 0/0, math.huge, -math.huge } do
			assert(Rules.validate(1, { action="Invite", targetUserId=userId }, true) == nil)
		end
	end)

	TestRunner.run("party request validation rejects hostile payloads", function()
		for _, payload in { nil, "Invite", 3, { action="Unknown" }, { action="Invite" },
			{ action="Invite", targetUserId=0 }, { action="Invite", targetUserId=-1 },
			{ action="Invite", targetUserId=1.5 }, { action="Invite", targetUserId=0/0 },
			{ action="Accept", inviteId="short" } } do
			assert(Rules.validate(1, payload, false) == nil)
		end
		assert(Rules.validate(0, nil) == nil)
		assert(Rules.validate(2, { action="Leave" }) == nil)
	end)
end
