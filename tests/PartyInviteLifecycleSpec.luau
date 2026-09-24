--!strict

local InviteRules = require(game.ReplicatedStorage.Shared.party.PartyInviteRules)
local PartyRules = require(game.ReplicatedStorage.Shared.party.PartyRules)

return function(TestRunner)
	TestRunner.run("invite can be accepted into the same authoritative party transition", function()
		local invite = { targetUserId=-2, createdAt=100 }
		local ok = InviteRules.canConsume(invite, -2, 111, 12)
		assert(ok)
		local party = PartyRules.addMember({ leaderUserId=-1, memberUserIds={-1}, nextLootCursor=1 }, -2)
		assert(#party.memberUserIds == 2 and party.memberUserIds[2] == -2)
	end)

	TestRunner.run("decline consumes only the addressed active invite", function()
		local ok = InviteRules.canConsume({ targetUserId=2, createdAt=100 }, 2, 105, 12)
		local spoofed, reason = InviteRules.canConsume({ targetUserId=2, createdAt=100 }, 3, 105, 12)
		assert(ok and not spoofed and reason == "InvalidInvite")
	end)

	TestRunner.run("timeout and pair cooldown use server timestamps", function()
		local ok, reason = InviteRules.canConsume({ targetUserId=2, createdAt=100 }, 2, 112, 12)
		assert(not ok and reason == "ExpiredInvite")
		assert(InviteRules.isPairCoolingDown(100, 102.9, 3))
		assert(not InviteRules.isPairCoolingDown(100, 103, 3))
	end)

	TestRunner.run("new invite finds and replaces the pending target token", function()
		local pending = { old={ targetUserId=2, createdAt=100 }, other={ targetUserId=3, createdAt=100 } }
		assert(InviteRules.findForTarget(pending, 2) == "old")
		pending.old = nil; pending.new = { targetUserId=2, createdAt=101 }
		assert(InviteRules.findForTarget(pending, 2) == "new")
	end)
end
