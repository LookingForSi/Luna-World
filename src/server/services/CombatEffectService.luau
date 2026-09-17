--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)
local MobService = require(script.Parent.MobService)

local CombatEffectService = {}

export type EffectTarget = {
	kind: "Mob" | "Player",
	entityId: string,
	model: Model,
}

export type EffectResult = {
	applied: boolean,
	amount: number?,
	isCritical: boolean?,
}

local criticalRandom = Random.new()

function CombatEffectService.isImplemented(definition: CombatTypes.SkillDefinition): boolean
	-- Task 6 deliberately installs the bounded dispatcher. Later skill tasks add
	-- their approved control, toggle, area, buff and healing handlers here.
	return definition.effect.kind == "DirectDamage"
end

function CombatEffectService.execute(
	actor: Player,
	stats: CombatTypes.CombatStatSnapshot,
	definition: CombatTypes.SkillDefinition,
	target: EffectTarget
): EffectResult
	if definition.effect.kind ~= "DirectDamage" or target.kind ~= "Mob" then
		return { applied = false }
	end

	local attackPower = if definition.powerSource == "MagicAttack" then stats.magicAttack else stats.physicalAttack
	local damage = DamageRules.resolve(
		DamageRules.getBaseAmount(attackPower, definition.effect.magnitude),
		definition.effect.kind,
		definition.canCrit,
		stats.criticalChance,
		CombatConfig.CriticalDamageMultiplier,
		function(): number return criticalRandom:NextNumber() end
	)
	if not MobService.applyDamage(target.entityId, damage.amount, actor) then
		return { applied = false }
	end
	return { applied = true, amount = damage.amount, isCritical = damage.isCritical }
end

return table.freeze(CombatEffectService)
