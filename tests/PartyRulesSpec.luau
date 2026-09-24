--!strict

local PartyRules = require(game.ReplicatedStorage.Shared.party.PartyRules)

local function party(members: { number }, leader: number?)
	return { leaderUserId = leader or members[1], memberUserIds = members, nextLootCursor = 1 }
end

return function(TestRunner)
	TestRunner.run("party grows from one to the four member cap in join order", function()
		local state = party({ 10 })
		assert(PartyRules.canInvite(state, 10, 20) == true)
		state = PartyRules.addMember(state, 20)
		state = PartyRules.addMember(state, 30)
		state = PartyRules.addMember(state, 40)
		assert(table.concat(state.memberUserIds, ",") == "10,20,30,40")
		assert(PartyRules.canInvite(state, 10, 50) == false)
		assert(PartyRules.addMember(state, 50) == state)
	end)

	TestRunner.run("member and leader removal preserve deterministic lifecycle", function()
		local state = party({ 10, 20, 30 })
		local afterMember = PartyRules.removeMember(state, 20)
		assert(afterMember ~= nil and afterMember.leaderUserId == 10)
		assert(table.concat(afterMember.memberUserIds, ",") == "10,30")
		local afterLeader = PartyRules.removeMember(afterMember, 10)
		assert(afterLeader == nil, "a party with one remaining member must disband")
		local successor = PartyRules.removeMember(state, 10)
		assert(successor ~= nil and successor.leaderUserId == 20)
	end)

	TestRunner.run("acceptance rejects invalid membership transitions", function()
		assert(PartyRules.canAccept(nil, false, false, true) == true)
		assert(PartyRules.canAccept(party({ 1, 2, 3, 4 }), false, false, true) == false)
		assert(PartyRules.canAccept(nil, true, false, true) == false)
		assert(PartyRules.canAccept(nil, false, true, true) == false)
		assert(PartyRules.canAccept(nil, false, false, false) == false)
	end)

	TestRunner.run("invite expiration uses an exclusive valid deadline", function()
		assert(not PartyRules.isInviteExpired(100, 111.999, 12))
		assert(PartyRules.isInviteExpired(100, 112, 12))
	end)

	TestRunner.run("only the leader can kick another current member", function()
		local state = party({ 10, 20, 30 })
		assert(PartyRules.canKick(state, 10, 20))
		local memberOk, memberReason = PartyRules.canKick(state, 20, 30)
		assert(not memberOk and memberReason == "NotLeader")
		local selfOk, selfReason = PartyRules.canKick(state, 10, 10)
		assert(not selfOk and selfReason == "CannotKickSelf")
		local outsiderOk, outsiderReason = PartyRules.canKick(state, 10, 40)
		assert(not outsiderOk and outsiderReason == "TargetNotMember")
	end)
end
