--!strict

local DamageRules = require(game.ReplicatedStorage.Shared.combat.DamageRules)
local SkillDefinitions = require(game.ReplicatedStorage.Shared.definitions.SkillDefinitions)
local SkillRules = require(game.ReplicatedStorage.Shared.combat.SkillRules)

return function(TestRunner)
	TestRunner.run("arcane bolt is one critical-capable magical result", function()
		local definition = SkillDefinitions.arcane_bolt
		assert(definition.effect.kind == "DirectDamage")
		assert(definition.powerSource == "MagicAttack")
		local result = DamageRules.resolve(27 * definition.effect.magnitude, definition.effect.kind, definition.canCrit, 0, 1.5, function()
			return 0.5
		end)
		assert(result.amount == 33.75 and not result.isCritical)
	end)

	TestRunner.run("flame burst selects a bounded server-owned area", function()
		local definition = SkillDefinitions.flame_burst
		assert(definition.effect.kind == "AreaDamage")
		assert(definition.powerSource == "MagicAttack")
		local selected = SkillRules.selectAreaTargets({
			{ entityId = "far", distance = definition.effect.radius + 0.01 },
			{ entityId = "d", distance = 4 },
			{ entityId = "b", distance = 2 },
			{ entityId = "a", distance = 2 },
			{ entityId = "c", distance = 3 },
			{ entityId = "e", distance = 5 },
		}, definition.effect.radius, definition.effect.maximumTargets)
		assert(#selected == definition.effect.maximumTargets)
		assert(selected[1] == "a" and selected[2] == "b" and selected[3] == "c" and selected[4] == "d")
	end)

	TestRunner.run("heal resolves a selected living in-range player without party state", function()
		assert(SkillRules.resolveFriendlyTarget(true, true, true, true, true) == "Selected")
		-- There is deliberately no party-membership input: every in-session player is friendly in v0.1.
	end)

	TestRunner.run("heal falls back to self instead of mutating an invalid selected target", function()
		assert(SkillRules.resolveFriendlyTarget(true, true, true, false, true) == "Self", "distant player must remain unchanged")
		assert(SkillRules.resolveFriendlyTarget(true, true, false, true, true) == "Self", "dead player must remain unchanged")
		assert(SkillRules.resolveFriendlyTarget(true, false, false, false, true) == "Self", "mob or malformed selection must remain unchanged")
		assert(SkillRules.resolveFriendlyTarget(false, true, true, true, true) == nil, "dead caster cannot heal")
		assert(SkillRules.resolveFriendlyTarget(true, false, false, false, false) == nil)
	end)

	TestRunner.run("skill resolve requires the exact accepted target model", function()
		local acceptedModel = {}
		local replacementModel = {}
		assert(SkillRules.isAcceptedTargetIdentityCurrent("Player", "player:2", acceptedModel, "Player", "player:2", acceptedModel))
		assert(not SkillRules.isAcceptedTargetIdentityCurrent("Player", "player:2", acceptedModel, "Player", "player:2", replacementModel), "character replacement during heal windup must not heal the replacement")
		assert(not SkillRules.isAcceptedTargetIdentityCurrent("Mob", "wolf", acceptedModel, "Mob", "wolf", replacementModel), "mob replacement during damage windup must not receive damage")
	end)

	TestRunner.run("heal caps at maximum health and cannot revive or crit", function()
		local definition = SkillDefinitions.heal
		assert(definition.effect.kind == "DirectHealing" and not definition.canCrit)
		assert(SkillRules.resolveHealing(80, 100, 30, true) == 100)
		assert(SkillRules.resolveHealing(0, 100, 30, false) == nil)
		local result = DamageRules.resolve(27, definition.effect.kind, definition.canCrit, 1, 2, function()
			error("healing must not roll for a critical result")
		end)
		assert(not result.isCritical)
	end)
end
