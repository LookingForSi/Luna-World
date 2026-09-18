--!strict

local EffectRules = require(game.ReplicatedStorage.Shared.combat.EffectRules)

local function approximatelyEqual(left: number, right: number): boolean
	return math.abs(left - right) < 0.000001
end

return function(TestRunner)
	TestRunner.run("shield bash stuns only ordinary mobs", function()
		local ordinary = EffectRules.resolveShieldBash("Ordinary", true, true, true)
		assert(ordinary.shouldStun)
		assert(not ordinary.shouldInterrupt)

		local elite = EffectRules.resolveShieldBash("Elite", true, true, false)
		assert(not elite.shouldStun)
		assert(not elite.shouldInterrupt)
	end)

	TestRunner.run("shield bash interrupts only eligible elite and boss actions", function()
		local elite = EffectRules.resolveShieldBash("Elite", true, true, true)
		assert(not elite.shouldStun)
		assert(elite.shouldInterrupt)

		local boss = EffectRules.resolveShieldBash("Boss", true, true, true)
		assert(not boss.shouldStun)
		assert(boss.shouldInterrupt)

		local protectedBoss = EffectRules.resolveShieldBash("Boss", true, true, false)
		assert(not protectedBoss.shouldStun)
		assert(not protectedBoss.shouldInterrupt)
	end)

	TestRunner.run("mob action guard rejects stun and stale generations", function()
		assert(not EffectRules.canResolveMobAction(1, 1, 10, 9.9))
		assert(EffectRules.canResolveMobAction(1, 1, 10, 10))
		assert(not EffectRules.canResolveMobAction(1, 2, nil, 10))
	end)

	TestRunner.run("defensive stance derives values from an immutable baseline", function()
		local enabled = EffectRules.resolveDefenseStance(12, 16, 1, 0.3, 0.55, true)
		assert(enabled.active)
		assert(approximatelyEqual(enabled.physicalDefense, 15.6))
		assert(approximatelyEqual(enabled.movementSpeed, 8.8))
		assert(enabled.attackSpeedMultiplier == 1, "stance must not reduce attack speed")

		local disabled = EffectRules.resolveDefenseStance(12, 16, 1, 0.3, 0.55, false)
		assert(not disabled.active)
		assert(disabled.physicalDefense == 12)
		assert(disabled.movementSpeed == 16)
		assert(disabled.attackSpeedMultiplier == 1)
	end)

	TestRunner.run("defensive stance toggle does not compound its modifiers", function()
		local enabled = EffectRules.resolveDefenseStance(12, 16, 1, 0.3, 0.55, true)
		local enabledAgain = EffectRules.resolveDefenseStance(12, 16, 1, 0.3, 0.55, true)
		assert(enabledAgain.physicalDefense == enabled.physicalDefense)
		assert(enabledAgain.movementSpeed == enabled.movementSpeed)
		assert(enabledAgain.attackSpeedMultiplier == enabled.attackSpeedMultiplier)
	end)

	TestRunner.run("death and respawn clear defensive stance to its baseline", function()
		local cleared = EffectRules.resolveDefenseStance(12, 16, 1, 0.3, 0.55, false)
		assert(not cleared.active)
		assert(cleared.physicalDefense == 12)
		assert(cleared.movementSpeed == 16)
		assert(cleared.attackSpeedMultiplier == 1)
	end)

	TestRunner.run("stance recomputes from externally changed canonical stats", function()
		local recalculated = EffectRules.resolveDefenseStance(20, 18, 1.25, 0.3, 0.55, true)
		assert(approximatelyEqual(recalculated.physicalDefense, 26))
		assert(approximatelyEqual(recalculated.movementSpeed, 9.9))
		assert(recalculated.attackSpeedMultiplier == 1.25)
		local removed = EffectRules.resolveDefenseStance(20, 18, 1.25, 0.3, 0.55, false)
		assert(removed.physicalDefense == 20 and removed.movementSpeed == 18)
	end)

	TestRunner.run("stun movement recomputes without clobbering a changed base speed", function()
		assert(EffectRules.resolveMovementSpeed(14, true) == 0)
		assert(EffectRules.resolveMovementSpeed(20, true) == 0)
		assert(EffectRules.resolveMovementSpeed(20, false) == 20)
	end)

	TestRunner.run("rapid shot changes only basic attack speed and obeys the server cap", function()
		assert(approximatelyEqual(EffectRules.resolveAttackSpeed(1, 0.25, 2, true), 1.25))
		assert(EffectRules.resolveAttackSpeed(1.9, 0.25, 2, true) == 2)
		assert(EffectRules.resolveAttackSpeed(1.9, 0.25, 2, false) == 1.9)
	end)

	TestRunner.run("snare is a nonstacking movement modifier recomputed from current base speed", function()
		assert(EffectRules.resolveMovementSpeed(20, false, 0.4) == 12)
		assert(EffectRules.resolveMovementSpeed(30, false, 0.4) == 18)
		assert(EffectRules.resolveMovementSpeed(30, true, 0.4) == 0)
		assert(EffectRules.resolveMovementSpeed(30, false, nil) == 30)
	end)

	TestRunner.run("temporary effect expiry rejects stale ABA callbacks", function()
		local oldToken = {}
		local replacementToken = {}
		assert(EffectRules.isCurrentEffectToken(oldToken, oldToken, true))
		assert(not EffectRules.isCurrentEffectToken(replacementToken, oldToken, true))
		assert(not EffectRules.isCurrentEffectToken(oldToken, oldToken, false))
		assert(not EffectRules.isCurrentEffectToken(nil, oldToken, true))
	end)
end
