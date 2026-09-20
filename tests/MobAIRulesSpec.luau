--!strict

local MobAIRules = require(game.ReplicatedStorage.Shared.combat.MobAIRules)

return function(TestRunner)
	TestRunner.run("passive and aggressive idle detection follows aggression mode", function()
		assert(MobAIRules.nextState("Idle", { alive = true, hasTarget = false, detectedTarget = true, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = true }, "Passive") == "Idle")
		assert(MobAIRules.nextState("Idle", { alive = true, hasTarget = false, detectedTarget = false, hostileAttacker = true, beyondLeash = false, inAttackRange = false, atHome = true }, "Passive") == "Aggro")
		assert(MobAIRules.nextState("Idle", { alive = true, hasTarget = false, detectedTarget = true, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = true }, "Aggressive") == "Aggro")
	end)

	TestRunner.run("aggro chase and attack transitions are deterministic", function()
		local base = { alive = true, hasTarget = true, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = false }
		assert(MobAIRules.nextState("Aggro", base, "Aggressive") == "Chase")
		assert(MobAIRules.nextState("Chase", table.freeze({ alive = true, hasTarget = true, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = true, atHome = false }), "Aggressive") == "Attack")
		assert(MobAIRules.nextState("Attack", base, "Aggressive") == "Chase")
	end)

	TestRunner.run("lost targets reacquire nearest eligible candidate or return", function()
		local candidates = {
			{ id = "far", distance = 12, eligible = true },
			{ id = "invalid", distance = 2, eligible = false },
			{ id = "near", distance = 5, eligible = true },
		}
		assert(MobAIRules.nearestEligible(candidates, 10) == "near")
		assert(MobAIRules.nearestEligible(candidates, 4) == nil)
		local lost = { alive = true, hasTarget = false, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = false }
		assert(MobAIRules.nextState("Chase", lost, "Aggressive") == "Return")
	end)

	TestRunner.run("leash return home and death dominate normal transitions", function()
		assert(MobAIRules.nextState("Attack", { alive = true, hasTarget = true, detectedTarget = false, hostileAttacker = false, beyondLeash = true, inAttackRange = true, atHome = false }, "Aggressive") == "Return")
		assert(MobAIRules.nextState("Return", { alive = true, hasTarget = false, detectedTarget = true, hostileAttacker = true, beyondLeash = false, inAttackRange = false, atHome = false }, "Aggressive") == "Return")
		assert(MobAIRules.nextState("Return", { alive = true, hasTarget = false, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = true }, "Aggressive") == "Idle")
		assert(MobAIRules.nextState("Chase", { alive = false, hasTarget = true, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = true, atHome = false }, "Aggressive") == "Dead")
	end)

	TestRunner.run("yielding decisions are single-flight and generation guarded", function()
		assert(MobAIRules.canBeginDecision(10, 10, false))
		assert(not MobAIRules.canBeginDecision(10, 10, true))
		assert(not MobAIRules.canBeginDecision(9.9, 10, false))
		assert(MobAIRules.isCurrentGeneration(4, 4))
		assert(not MobAIRules.isCurrentGeneration(4, 5), "a result from a stale path computation must be discarded")
	end)

	TestRunner.run("return invalidates attacks and heals only after arriving home", function()
		assert(MobAIRules.shouldInvalidateAction("Attack", "Return"))
		assert(MobAIRules.shouldInvalidateAction("Attack", "Dead"))
		assert(not MobAIRules.shouldInvalidateAction("Return", "Return"))
		assert(MobAIRules.shouldRestoreHealth("Return", "Idle", true))
		assert(not MobAIRules.shouldRestoreHealth("Idle", "Idle", true), "idle mobs must not heal every decision")
		assert(not MobAIRules.shouldRestoreHealth("Return", "Idle", false))
	end)

	TestRunner.run("returning and dead mobs cannot start social assist", function()
		assert(MobAIRules.canRequestSocialAssist("Idle", "local_pack"))
		assert(MobAIRules.canRequestSocialAssist("Attack", "local_pack"))
		assert(not MobAIRules.canRequestSocialAssist("Return", "local_pack"))
		assert(not MobAIRules.canRequestSocialAssist("Dead", "local_pack"))
		assert(not MobAIRules.canRequestSocialAssist("Attack", nil))
		assert(not MobAIRules.canRequestSocialAssist("Attack", ""))
	end)
end
