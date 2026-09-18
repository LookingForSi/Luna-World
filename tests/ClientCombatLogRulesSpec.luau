--!strict

local Rules = require(game.ReplicatedStorage.Shared.combat.ClientCombatLogRules)

return function(TestRunner)
	TestRunner.run("combat log keeps only local outgoing and incoming messages", function()
		local localId = "player:42"
		assert(Rules.isRelevant({ actorEntityId = localId, targetEntityId = "mob:a" }, localId))
		assert(Rules.isRelevant({ actorEntityId = "mob:a", targetEntityId = localId }, localId))
		assert(not Rules.isRelevant({ actorEntityId = "player:7", targetEntityId = "mob:a" }, localId))
	end)

	TestRunner.run("combat log formats whole and fractional amounts compactly", function()
		assert(Rules.formatAmount(10) == "10")
		assert(Rules.formatAmount(6.4) == "6.4")
		assert(Rules.formatAmount(6.44) == "6.4")
	end)

	TestRunner.run("combat log exposes readable rejection reasons", function()
		assert(Rules.rejectionText("Cooldown") == "перезарядка")
		assert(Rules.rejectionText("OutOfRange") == "слишком далеко")
		assert(Rules.rejectionText(nil) == "неизвестная причина")
	end)
end
