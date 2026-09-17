--!strict

local AutoAttackRules = require(game.ReplicatedStorage.Shared.combat.AutoAttackRules)

return function(TestRunner)
	TestRunner.run("AUTO accepts exactly one boolean in living PvE context", function()
		local enabled = AutoAttackRules.validateRequest(1, true, true, true)
		assert(enabled.accepted and enabled.enabled == true)
		local disabled = AutoAttackRules.validateRequest(1, false, false, false)
		assert(disabled.accepted and disabled.enabled == false, "explicit off must always be available")
		assert(not AutoAttackRules.validateRequest(0, nil, true, true).accepted)
		assert(not AutoAttackRules.validateRequest(2, true, true, true).accepted)
		assert(not AutoAttackRules.validateRequest(1, "true", true, true).accepted)
		assert(not AutoAttackRules.validateRequest(1, true, true, false).accepted, "PvP or no target cannot enable AUTO")
		assert(not AutoAttackRules.validateRequest(1, true, false, true).accepted)
	end)

	TestRunner.run("AUTO lifecycle stops on target and player invalidation", function()
		assert(not AutoAttackRules.shouldStop(true, true, true, true))
		assert(AutoAttackRules.shouldStop(false, true, true, true))
		assert(AutoAttackRules.shouldStop(true, false, true, true))
		assert(AutoAttackRules.shouldStop(true, true, false, true))
		assert(AutoAttackRules.shouldStop(true, true, true, false))
	end)

	TestRunner.run("AUTO schedules against authoritative readiness", function()
		assert(AutoAttackRules.nextAttemptAt(10, 12, 0.1) == 12)
		assert(AutoAttackRules.nextAttemptAt(12, 12, 0.1) == 12.1)
		assert(AutoAttackRules.shouldAttempt(12, 12, "Ready"))
		assert(not AutoAttackRules.shouldAttempt(12, 12, "Windup"), "manual action must occupy the shared slot")
		assert(not AutoAttackRules.shouldAttempt(12, 12, "Recovery"), "AUTO must not add a second hit during recovery")
	end)
end
