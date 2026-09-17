--!strict

local CombatRules = {}

local ActionRules = require(script.Parent.ActionRules)

function CombatRules.canSelectTarget(
	playerPosition: Vector3,
	targetPosition: Vector3,
	targetAlive: boolean,
	selectionRange: number
): boolean
	return targetAlive and ActionRules.isWithinRange(playerPosition, targetPosition, selectionRange, 0)
end

function CombatRules.canBasicAttack(
	playerPosition: Vector3,
	targetPosition: Vector3,
	targetAlive: boolean,
	attackRange: number
): boolean
	return targetAlive and ActionRules.isWithinRange(playerPosition, targetPosition, attackRange, 0)
end

function CombatRules.nextAttackIntent(authoritativeActive: boolean): boolean
	return not authoritativeActive
end

return CombatRules
