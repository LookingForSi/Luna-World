--!strict

local PartyRules = require(game.ReplicatedStorage.Shared.party.PartyRules)

return function(TestRunner)
	TestRunner.run("xp splitting preserves the exact mob budget", function()
		local one = PartyRules.splitXP(40, { 1 })
		assert(one[1] == 40)
		local two = PartyRules.splitXP(40, { 1, 2 })
		assert(two[1] == 20 and two[2] == 20)
		local three = PartyRules.splitXP(41, { 1, 2, 3 })
		assert(three[1] == 14 and three[2] == 14 and three[3] == 13)
		assert(three[1] + three[2] + three[3] == 41)
	end)

	TestRunner.run("round robin skips ineligible members without losing stable cursor", function()
		local ordered = { 10, 20, 30 }
		local recipient, cursor = PartyRules.selectRoundRobin(ordered, { [10] = true, [30] = true }, 2)
		assert(recipient == 30 and cursor == 1)
		local nextRecipient, nextCursor = PartyRules.selectRoundRobin(ordered, { [10] = true }, cursor)
		assert(nextRecipient == 10 and nextCursor == 2)
		local none, sameCursor = PartyRules.selectRoundRobin(ordered, {}, nextCursor)
		assert(none == nil and sameCursor == nextCursor)
	end)
end
