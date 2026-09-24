--!strict

local RewardLedger = require(game.ServerScriptService.Server.features.party.RewardLedger)

return function(TestRunner)
	TestRunner.run("one entity can enter reward distribution only once", function()
		local ledger = RewardLedger.new(2)
		assert(ledger:mark("mob-1"))
		assert(not ledger:mark("mob-1"))
		assert(ledger:mark("mob-2"))
		assert(ledger:mark("mob-3"))
		assert(ledger:mark("mob-1"), "bounded ledger releases its oldest entity")
	end)

	TestRunner.run("ledger cleanup permits clean service restart", function()
		local ledger = RewardLedger.new(2)
		assert(ledger:mark("mob")); ledger:clear(); assert(ledger:mark("mob"))
	end)
end
