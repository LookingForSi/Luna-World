--!strict

local PresentationRules = require(game.ReplicatedStorage.Shared.combat.CombatPresentationRules)

return function(TestRunner)
	TestRunner.run("presentation messages use a stable public shape", function()
		for _, kind in { "Action", "Result", "Interruption", "Effect", "Death", "Respawn" } do
			local message = PresentationRules.create(kind, "action-1", "player:1", 123, {
				targetEntityId = "mob:1",
				skillId = "power_strike",
				presentationKey = "power_strike",
				outcome = "Applied",
				amount = 12,
				isCritical = false,
				effectPhase = "Started",
			})
			assert(PresentationRules.isSupported(message))
			assert(message.kind == kind and message.actionId == "action-1")
			assert(message.serverTime == 123)
			assert(message.damageCoefficient == nil and message.randomRoll == nil)
		end
	end)

	TestRunner.run("only safe rejection reason codes are public", function()
		local reasonCodes: { PresentationRules.ReasonCode } = { "Cooldown", "InvalidTarget", "OutOfRange", "InsufficientResource", "ForbiddenState", "RateLimited" }
		for _, reasonCode in reasonCodes do
			assert(PresentationRules.isSupported(PresentationRules.create("Result", reasonCode, "player:1", 123, {
				outcome = "Rejected", reasonCode = reasonCode,
			})))
		end
		assert(not PresentationRules.isSupported({
			kind = "Result", actionId = "a", actorEntityId = "p", serverTime = 1,
			outcome = "Rejected", reasonCode = "ServerStackTrace",
		}))
	end)

	TestRunner.run("terminal presentation is correlated by the accepted action id", function()
		local action = PresentationRules.create("Action", "same-id", "player:1", 123, { outcome = "Accepted" })
		local result = PresentationRules.create("Result", "same-id", "player:1", 123, { outcome = "Applied" })
		local other = PresentationRules.create("Interruption", "other-id", "player:1", 123, { outcome = "Canceled" })
		assert(PresentationRules.isTerminalFor(action, result))
		assert(not PresentationRules.isTerminalFor(action, other))
	end)

	TestRunner.run("unsupported or malformed presentation messages are ignored", function()
		assert(not PresentationRules.isSupported({ kind = "Unknown", actionId = "a", actorEntityId = "p" }))
		assert(not PresentationRules.isSupported({ kind = "Action", actionId = "", actorEntityId = "p" }))
		assert(not PresentationRules.isSupported({ kind = "Action", actionId = "a", actorEntityId = "p", randomRoll = 0.5 }))
		assert(not PresentationRules.isSupported({ kind = "Result", actionId = "a", actorEntityId = "p", amount = "forged" }))
		assert(not PresentationRules.isSupported({ kind = "Result", actionId = "a", actorEntityId = "p", serverTime = 0 / 0 }))
		assert(not PresentationRules.isSupported({ kind = "Result", actionId = "a", actorEntityId = "p", serverTime = 1, outcome = "InternalFailure" }))
		assert(not PresentationRules.isSupported("Action"))
	end)
end
