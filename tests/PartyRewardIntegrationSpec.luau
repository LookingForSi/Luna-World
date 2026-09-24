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

	TestRunner.run("canonical ledger rejects a duplicate before any reward consumer", function()
		local ledger = RewardLedger.new(4096)
		local emitted = 0
		for _ = 1, 2 do if ledger:mark("same-entity") then emitted += 1 end end
		assert(emitted == 1)
	end)
end
