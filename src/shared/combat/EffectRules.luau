--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

local EffectRules = {}

export type ShieldBashDecision = {
	shouldStun: boolean,
	shouldInterrupt: boolean,
}

export type DefenseStanceValues = {
	active: boolean,
	physicalDefense: number,
	movementSpeed: number,
	attackSpeedMultiplier: number,
}

function EffectRules.invalidateMobActionGeneration(currentGeneration: number?): number
	if currentGeneration == nil then return 1 end
	assert(currentGeneration == currentGeneration and currentGeneration >= 0 and currentGeneration < math.huge, "currentGeneration must be finite and nonnegative")
	return currentGeneration + 1
end

function EffectRules.canResolveMobAction(
	acceptedGeneration: number,
	currentGeneration: number,
	stunnedUntil: number?,
	now: number
): boolean
	if acceptedGeneration ~= currentGeneration then return false end
	return stunnedUntil == nil or now >= stunnedUntil
end

local function assertFiniteNonnegative(value: number, name: string): ()
	assert(value == value and value >= 0 and value < math.huge, name .. " must be finite and nonnegative")
end

function EffectRules.resolveShieldBash(
	rank: CombatTypes.MobRank,
	stunsOrdinaryMobs: boolean,
	interruptsEligibleImmuneMobs: boolean,
	targetActionInterruptible: boolean
): ShieldBashDecision
	local isOrdinary = rank == "Ordinary"
	return {
		shouldStun = isOrdinary and stunsOrdinaryMobs,
		shouldInterrupt = not isOrdinary and interruptsEligibleImmuneMobs and targetActionInterruptible,
	}
end

function EffectRules.resolveDefenseStance(
	basePhysicalDefense: number,
	baseMovementSpeed: number,
	attackSpeedMultiplier: number,
	defenseIncrease: number,
	movementSpeedMultiplier: number,
	active: boolean
): DefenseStanceValues
	assertFiniteNonnegative(basePhysicalDefense, "basePhysicalDefense")
	assertFiniteNonnegative(baseMovementSpeed, "baseMovementSpeed")
	assertFiniteNonnegative(attackSpeedMultiplier, "attackSpeedMultiplier")
	assertFiniteNonnegative(defenseIncrease, "defenseIncrease")
	assertFiniteNonnegative(movementSpeedMultiplier, "movementSpeedMultiplier")
	return {
		active = active,
		physicalDefense = if active then basePhysicalDefense * (1 + defenseIncrease) else basePhysicalDefense,
		movementSpeed = if active then baseMovementSpeed * movementSpeedMultiplier else baseMovementSpeed,
		attackSpeedMultiplier = attackSpeedMultiplier,
	}
end

function EffectRules.resolveAttackSpeed(
	baseAttackSpeedMultiplier: number,
	increase: number,
	maximum: number,
	active: boolean
): number
	assertFiniteNonnegative(baseAttackSpeedMultiplier, "baseAttackSpeedMultiplier")
	assertFiniteNonnegative(increase, "increase")
	assertFiniteNonnegative(maximum, "maximum")
	if not active then return baseAttackSpeedMultiplier end
	return math.min(baseAttackSpeedMultiplier * (1 + increase), maximum)
end

function EffectRules.isCurrentEffectToken(currentToken: unknown, expectedToken: unknown, identityMatches: boolean): boolean
	return currentToken ~= nil and currentToken == expectedToken and identityMatches
end

function EffectRules.resolveMovementSpeed(
	baseMovementSpeed: number,
	immobilized: boolean,
	slowMagnitude: number?
): number
	assertFiniteNonnegative(baseMovementSpeed, "baseMovementSpeed")
	if slowMagnitude ~= nil then
		assertFiniteNonnegative(slowMagnitude, "slowMagnitude")
		assert(slowMagnitude <= 1, "slowMagnitude must not exceed one")
	end
	if immobilized then return 0 end
	return baseMovementSpeed * (1 - (slowMagnitude or 0))
end

return table.freeze(EffectRules)
