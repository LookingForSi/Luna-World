--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local LeaseRules = require(ServerScriptService.Server.persistence.LeaseRules)

return function(TestRunner)
	TestRunner.run("lease claim permits free same-owner and expired records", function()
		assert(LeaseRules.canClaim(nil, "session-a", 10))
		local active = LeaseRules.renew("session-a", 10, 300)
		assert(LeaseRules.canClaim(active, "session-a", 20))
		assert(not LeaseRules.canClaim(active, "session-b", 20))
		assert(LeaseRules.canClaim(active, "session-b", active.ExpiresAt))
	end)

	TestRunner.run("lease ownership is token exact and renewal is deterministic", function()
		local lease = LeaseRules.renew("session-a", 100, 300)
		assert(lease.ExpiresAt == 400)
		assert(LeaseRules.isOwner(lease, "session-a"))
		assert(not LeaseRules.isOwner(lease, "session-b"))
		assert(LeaseRules.isValid(lease))
		assert(not LeaseRules.isValid({ Token = "", ExpiresAt = 400 }))
	end)
end
