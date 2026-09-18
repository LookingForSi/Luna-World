--!strict

local CombatConfig = require(game.ReplicatedStorage.Shared.config.CombatConfig)
local DamageRules = require(game.ReplicatedStorage.Shared.combat.DamageRules)
local SkillDefinitions = require(game.ReplicatedStorage.Shared.definitions.SkillDefinitions)

return function(TestRunner)
	TestRunner.run("power shot declares one delayed ranged physical result", function()
		local definition = SkillDefinitions.power_shot
		assert(definition.archetypeId == "ranger")
		assert(definition.targetType == "Enemy")
		assert(definition.powerSource == "PhysicalAttack")
		assert(definition.effect.kind == "DirectDamage")
		assert(definition.windupSeconds > 0)
		local amount = DamageRules.getBaseAmount(20, definition.effect.magnitude)
		assert(amount > 20)
	end)

	TestRunner.run("rapid shot is a capped temporary basic attack speed modifier", function()
		local definition = SkillDefinitions.rapid_shot
		assert(definition.targetType == "Self")
		assert(definition.effect.kind == "AttackSpeedBuff")
		assert(definition.effect.durationSeconds > 0)
		assert(CombatConfig.MaxAttackSpeedMultiplier > 1)
	end)

	TestRunner.run("snare refreshes one movement slow and never deals direct damage", function()
		local definition = SkillDefinitions.snare
		assert(definition.targetType == "Enemy")
		assert(definition.powerSource == "None")
		assert(definition.canCrit == false)
		assert(definition.effect.kind == "MovementSlow")
		assert(definition.effect.refreshDurationOnReapply)
		assert(definition.effect.magnitude > 0 and definition.effect.magnitude < 1)
	end)
end
