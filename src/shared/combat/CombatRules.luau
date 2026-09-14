--!strict

local CombatRules = {}

local function withinRange(a: Vector3, b: Vector3, range: number): boolean
	return (a - b).Magnitude <= range
end

function CombatRules.canSelectTarget(
	playerPosition: Vector3,
	targetPosition: Vector3,
	targetAlive: boolean,
	selectionRange: number
): boolean
	return targetAlive and withinRange(playerPosition, targetPosition, selectionRange)
end

function CombatRules.canBasicAttack(
	playerPosition: Vector3,
	targetPosition: Vector3,
	targetAlive: boolean,
	attackRange: number
): boolean
	return targetAlive and withinRange(playerPosition, targetPosition, attackRange)
end

return CombatRules
