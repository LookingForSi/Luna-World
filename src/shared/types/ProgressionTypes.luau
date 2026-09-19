--!strict

export type StatModifiers = {
	maxHealth: number?,
	maxResource: number?,
	physicalAttack: number?,
	magicAttack: number?,
	physicalDefense: number?,
	criticalChance: number?,
	attackSpeedMultiplier: number?,
}

export type DerivedStats = {
	maxHealth: number,
	maxResource: number,
	resourceRegenerationPerSecond: number,
	physicalAttack: number,
	magicAttack: number,
	physicalDefense: number,
	criticalChance: number,
	attackSpeedMultiplier: number,
	movementSpeed: number,
}

return table.freeze({})
