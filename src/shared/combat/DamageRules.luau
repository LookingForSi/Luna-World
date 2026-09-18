--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

local DamageRules = {}

local function isFinite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

export type DamageResult = {
	amount: number,
	isCritical: boolean,
}

function DamageRules.getBaseAmount(attackPower: number, magnitude: number): number
	assert(isFinite(attackPower) and attackPower >= 0, "attackPower must be finite and nonnegative")
	assert(isFinite(magnitude) and magnitude >= 0, "magnitude must be finite and nonnegative")
	local amount = attackPower * magnitude
	assert(isFinite(amount), "base damage result must be finite")
	return amount
end

function DamageRules.getBasicAttackInterval(
	baseInterval: number,
	attackSpeedMultiplier: number,
	minimumMultiplier: number,
	maximumMultiplier: number
): number
	assert(isFinite(baseInterval) and baseInterval >= 0, "baseInterval must be finite and nonnegative")
	assert(isFinite(attackSpeedMultiplier), "attackSpeedMultiplier must be finite")
	assert(isFinite(minimumMultiplier) and minimumMultiplier > 0, "minimumMultiplier must be finite and positive")
	assert(isFinite(maximumMultiplier) and maximumMultiplier >= minimumMultiplier, "maximumMultiplier must be finite and not below minimumMultiplier")
	local boundedMultiplier = math.clamp(attackSpeedMultiplier, minimumMultiplier, maximumMultiplier)
	return baseInterval / boundedMultiplier
end

function DamageRules.resolve(
	baseAmount: number,
	effectKind: CombatTypes.EffectKind,
	canCrit: boolean,
	criticalChance: number,
	criticalMultiplier: number,
	roll: () -> number
): DamageResult
	assert(isFinite(baseAmount) and baseAmount >= 0, "baseAmount must be finite and nonnegative")
	assert(isFinite(criticalChance) and criticalChance >= 0 and criticalChance <= 1, "criticalChance must be finite and between zero and one")
	assert(isFinite(criticalMultiplier) and criticalMultiplier >= 1, "criticalMultiplier must be finite and at least one")

	local eligible = effectKind == "DirectDamage" or effectKind == "AreaDamage"
	local isCritical = false
	if eligible and canCrit then
		local sample = roll()
		assert(isFinite(sample) and sample >= 0 and sample < 1, "critical roll must be finite and in the range [0, 1)")
		isCritical = sample < criticalChance
	end
	local amount = if isCritical then baseAmount * criticalMultiplier else baseAmount
	assert(isFinite(amount), "resolved damage must be finite")
	return {
		amount = amount,
		isCritical = isCritical,
	}
end

return table.freeze(DamageRules)
