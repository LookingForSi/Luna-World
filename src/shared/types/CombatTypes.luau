--!strict

export type ResourceType = "Stamina" | "Focus" | "Mana"
export type ActionState = "Ready" | "Windup" | "Recovery"
export type TargetType = "Enemy" | "Self" | "Friendly" | "EnemyArea"
export type PowerSource = "PhysicalAttack" | "MagicAttack" | "None"
export type EffectKind =
	"DirectDamage"
	| "DirectHealing"
	| "AreaDamage"
	| "ShieldBash"
	| "DefenseStance"
	| "AttackSpeedBuff"
	| "MovementSlow"
export type RejectionReason =
	"Cooldown"
	| "InvalidTarget"
	| "OutOfRange"
	| "NotFacing"
	| "InsufficientResource"
	| "ForbiddenState"
	| "RateLimited"

export type CombatTarget = {
	entityId: string,
	entityType: "Player" | "Mob",
}

export type CombatResource = {
	resourceType: ResourceType,
	current: number,
	maximum: number,
}

export type CombatStatSnapshot = {
	resource: CombatResource,
	resourceRegenerationPerSecond: number,
	physicalAttack: number,
	magicAttack: number,
	basePhysicalDefense: number,
	physicalDefense: number,
	baseAttackSpeedMultiplier: number,
	attackSpeedMultiplier: number,
	criticalChance: number,
	baseMovementSpeed: number,
	movementSpeed: number,
}

export type DirectDamageEffect = { kind: "DirectDamage", magnitude: number }
export type DirectHealingEffect = {
	kind: "DirectHealing",
	magnitude: number,
	selfCastWithoutFriendlyTarget: boolean,
}
export type AreaDamageEffect = { kind: "AreaDamage", magnitude: number, radius: number, maximumTargets: number }
export type ShieldBashEffect = {
	kind: "ShieldBash",
	magnitude: number,
	durationSeconds: number,
	stunsOrdinaryMobs: boolean,
	interruptsEligibleImmuneMobs: boolean,
}
export type DefenseStanceEffect = {
	kind: "DefenseStance",
	magnitude: number,
	movementSpeedMultiplier: number,
	isToggle: boolean,
}
export type AttackSpeedBuffEffect = { kind: "AttackSpeedBuff", magnitude: number, durationSeconds: number }
export type MovementSlowEffect = {
	kind: "MovementSlow",
	magnitude: number,
	durationSeconds: number,
	refreshDurationOnReapply: boolean,
}
export type SkillEffect =
	DirectDamageEffect
	| DirectHealingEffect
	| AreaDamageEffect
	| ShieldBashEffect
	| DefenseStanceEffect
	| AttackSpeedBuffEffect
	| MovementSlowEffect

export type SkillDefinition = {
	id: string,
	archetypeId: string,
	displayName: string,
	unlockLevel: number,
	targetType: TargetType,
	range: number,
	requiresFacing: boolean,
	windupSeconds: number,
	cooldownSeconds: number,
	cooldownGroup: string,
	resourceType: ResourceType,
	resourceCost: number,
	powerSource: PowerSource,
	effect: SkillEffect,
	canCrit: boolean,
	canMoveDuringWindup: boolean,
	interruptible: boolean,
	presentationKey: string,
}

export type ArchetypeDefinition = {
	id: string,
	displayName: string,
	resourceType: ResourceType,
	basicAttackId: string,
	skillIds: { string },
}

export type AggressionMode = "Passive" | "Aggressive"
export type MobRank = "Ordinary" | "Elite" | "Boss"
export type MobAttackKind = "Melee" | "Ranged"
export type MobDamageType = "Physical" | "Magic"
export type MobAbilityKind = "DirectDamage" | "AreaDamage" | "DamageOverTime" | "Crippling" | "AllyDamageBuff" | "SelfDamageBuff"

export type MobAbilityDefinition = {
	id: string,
	displayName: string,
	kind: MobAbilityKind,
	damageType: MobDamageType,
	range: number,
	damage: number,
	windupSeconds: number,
	cooldownSeconds: number,
	presentationKey: string,
	durationSeconds: number?,
	tickDamage: number?,
	tickIntervalSeconds: number?,
	movementMultiplier: number?,
	attackSpeedMultiplier: number?,
	damageMultiplier: number?,
	radius: number?,
	callsAllies: boolean?,
	healthBelowFraction: number?,
}

export type MobDefinition = {
	id: string,
	displayName: string,
	level: number,
	maxHealth: number,
	physicalDefense: number,
	magicDefense: number,
	rewardXP: number,
	lootTableId: string,
	respawnSeconds: number,
	aggressionMode: AggressionMode,
	rank: MobRank,
	attackKind: MobAttackKind,
	faction: string,
	visualProfile: string,
	detectionRadius: number,
	aggroRadius: number,
	reacquireRadius: number,
	leashDistance: number,
	attackRange: number,
	basicAttackRange: number,
	basicAttackDamage: number,
	basicAttackDamageType: MobDamageType,
	attackWindupSeconds: number,
	attackIntervalSeconds: number,
	chaseSpeed: number,
	decisionIntervalSeconds: number,
	restoreHealthOnReturn: boolean,
	socialAssistRadius: number,
	abilityIds: { string },
}

export type ActionResult = {
	accepted: boolean,
	reason: RejectionReason?,
	actionId: string?,
	target: CombatTarget?,
}

return table.freeze({})
