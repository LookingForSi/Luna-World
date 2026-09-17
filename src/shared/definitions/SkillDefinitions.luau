--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)
local CombatConfig = require(script.Parent.Parent.config.CombatConfig)

-- All numbers in this file are working tuning values, not final balance.
local definitions: { [string]: CombatTypes.SkillDefinition } = {
	knight_basic_attack = {
		id = "knight_basic_attack", archetypeId = "knight", displayName = "Базовая атака", targetType = "Enemy",
		range = CombatConfig.BasicAttackRange, requiresFacing = true, windupSeconds = 0.2, cooldownSeconds = CombatConfig.BasicAttackInterval, cooldownGroup = "basic_attack",
		resourceType = "Stamina", resourceCost = 0, powerSource = "PhysicalAttack", effect = { kind = "DirectDamage", magnitude = 1 },
		canCrit = true, canMoveDuringWindup = true, interruptible = false, presentationKey = "knight_basic_attack",
	},
	power_strike = {
		id = "power_strike", archetypeId = "knight", displayName = "Мощный удар", targetType = "Enemy",
		range = 12, requiresFacing = true, windupSeconds = 0.3, cooldownSeconds = 4, cooldownGroup = "power_strike",
		resourceType = "Stamina", resourceCost = 20, powerSource = "PhysicalAttack", effect = { kind = "DirectDamage", magnitude = 1.5 },
		canCrit = true, canMoveDuringWindup = true, interruptible = true, presentationKey = "power_strike",
	},
	shield_bash = {
		id = "shield_bash", archetypeId = "knight", displayName = "Удар щитом", targetType = "Enemy",
		range = 10, requiresFacing = true, windupSeconds = 0.2, cooldownSeconds = 8, cooldownGroup = "shield_bash",
		resourceType = "Stamina", resourceCost = 25, powerSource = "PhysicalAttack", effect = {
			-- Shield Bash is one deliberately small composite: physical hit plus control.
			kind = "ShieldBash", magnitude = 0.5, durationSeconds = 1.5,
			stunsOrdinaryMobs = true, interruptsEligibleImmuneMobs = true,
		},
		canCrit = false, canMoveDuringWindup = true, interruptible = true, presentationKey = "shield_bash",
	},
	defensive_stance = {
		id = "defensive_stance", archetypeId = "knight", displayName = "Защитная стойка", targetType = "Self",
		range = 0, requiresFacing = false, windupSeconds = 0, cooldownSeconds = 1, cooldownGroup = "defensive_stance",
		resourceType = "Stamina", resourceCost = 0, powerSource = "None", effect = {
			kind = "DefenseStance", magnitude = 0.3, movementSpeedMultiplier = 0.55, isToggle = true,
		},
		canCrit = false, canMoveDuringWindup = true, interruptible = false, presentationKey = "defensive_stance",
	},
	ranger_basic_attack = {
		id = "ranger_basic_attack", archetypeId = "ranger", displayName = "Дальняя базовая атака", targetType = "Enemy",
		range = CombatConfig.RangerBasicAttackRange, requiresFacing = true, windupSeconds = 0.25, cooldownSeconds = CombatConfig.RangerBasicAttackInterval, cooldownGroup = "basic_attack",
		resourceType = "Focus", resourceCost = 0, powerSource = "PhysicalAttack", effect = { kind = "DirectDamage", magnitude = 1 },
		canCrit = true, canMoveDuringWindup = true, interruptible = false, presentationKey = "ranger_basic_attack",
	},
	power_shot = {
		id = "power_shot", archetypeId = "ranger", displayName = "Мощный выстрел", targetType = "Enemy",
		range = 60, requiresFacing = true, windupSeconds = 0.6, cooldownSeconds = 5, cooldownGroup = "power_shot",
		resourceType = "Focus", resourceCost = 20, powerSource = "PhysicalAttack", effect = { kind = "DirectDamage", magnitude = 1.6 },
		canCrit = true, canMoveDuringWindup = false, interruptible = true, presentationKey = "power_shot",
	},
	rapid_shot = {
		id = "rapid_shot", archetypeId = "ranger", displayName = "Быстрый выстрел", targetType = "Self",
		range = 0, requiresFacing = false, windupSeconds = 0, cooldownSeconds = 12, cooldownGroup = "rapid_shot",
		resourceType = "Focus", resourceCost = 25, powerSource = "None", effect = { kind = "AttackSpeedBuff", magnitude = 0.25, durationSeconds = 6 },
		canCrit = false, canMoveDuringWindup = true, interruptible = false, presentationKey = "rapid_shot",
	},
	snare = {
		id = "snare", archetypeId = "ranger", displayName = "Западня", targetType = "Enemy",
		range = 45, requiresFacing = true, windupSeconds = 0.3, cooldownSeconds = 8, cooldownGroup = "snare",
		resourceType = "Focus", resourceCost = 20, powerSource = "None", effect = {
			kind = "MovementSlow", magnitude = 0.4, durationSeconds = 5, refreshDurationOnReapply = true,
		},
		canCrit = false, canMoveDuringWindup = true, interruptible = true, presentationKey = "snare",
	},
	mystic_basic_attack = {
		id = "mystic_basic_attack", archetypeId = "mystic", displayName = "Магическая базовая атака", targetType = "Enemy",
		range = CombatConfig.MysticBasicAttackRange, requiresFacing = true, windupSeconds = 0.45, cooldownSeconds = CombatConfig.MysticBasicAttackInterval, cooldownGroup = "basic_attack",
		resourceType = "Mana", resourceCost = 0, powerSource = "MagicAttack", effect = { kind = "DirectDamage", magnitude = 1 },
		canCrit = true, canMoveDuringWindup = false, interruptible = true, presentationKey = "mystic_basic_attack",
	},
	arcane_bolt = {
		id = "arcane_bolt", archetypeId = "mystic", displayName = "Чародейская стрела", targetType = "Enemy",
		range = 55, requiresFacing = true, windupSeconds = 0.25, cooldownSeconds = 3, cooldownGroup = "arcane_bolt",
		resourceType = "Mana", resourceCost = 15, powerSource = "MagicAttack", effect = { kind = "DirectDamage", magnitude = 1.25 },
		canCrit = true, canMoveDuringWindup = true, interruptible = true, presentationKey = "arcane_bolt",
	},
	flame_burst = {
		id = "flame_burst", archetypeId = "mystic", displayName = "Огненная вспышка", targetType = "EnemyArea",
		range = 45, requiresFacing = true, windupSeconds = 0.7, cooldownSeconds = 7, cooldownGroup = "flame_burst",
		resourceType = "Mana", resourceCost = 30, powerSource = "MagicAttack", effect = { kind = "AreaDamage", magnitude = 1.1, radius = 10 },
		canCrit = true, canMoveDuringWindup = false, interruptible = true, presentationKey = "flame_burst",
	},
	heal = {
		id = "heal", archetypeId = "mystic", displayName = "Лечение", targetType = "Friendly",
		range = 45, requiresFacing = false, windupSeconds = 0.6, cooldownSeconds = 5, cooldownGroup = "heal",
		resourceType = "Mana", resourceCost = 25, powerSource = "MagicAttack", effect = {
			kind = "DirectHealing", magnitude = 1, selfCastWithoutFriendlyTarget = true,
		},
		canCrit = false, canMoveDuringWindup = false, interruptible = true, presentationKey = "heal",
	},
}

return table.freeze(definitions)
