--!strict

local CombatConfig = require(script.Parent.Parent.config.CombatConfig)
local ProgressionConfig = require(script.Parent.Parent.config.ProgressionConfig)
local ProgressionTypes = require(script.Parent.Parent.types.ProgressionTypes)

local StatRules = {}

local function modifier(value: number?): number
	return if value ~= nil then value else 0
end

function StatRules.derive(
	archetypeId: string,
	level: number,
	equipment: ProgressionTypes.StatModifiers?
): ProgressionTypes.DerivedStats
	assert(level >= 1 and level <= ProgressionConfig.LevelCap and level % 1 == 0, "level is outside the supported range")
	local base = CombatConfig.ArchetypeStats[archetypeId]
	local growth = ProgressionConfig.ArchetypeGrowthPerLevel[archetypeId]
	local baseMaxHealth = ProgressionConfig.ArchetypeBaseMaxHealth[archetypeId]
	assert(base ~= nil and growth ~= nil and baseMaxHealth ~= nil, "unknown archetype")

	local levelsAfterOne = level - 1
	local modifiers: ProgressionTypes.StatModifiers = equipment or {}

	return {
		maxHealth = baseMaxHealth + growth.maxHealth * levelsAfterOne + modifier(modifiers.maxHealth),
		maxResource = base.maximumResource + growth.maxResource * levelsAfterOne + modifier(modifiers.maxResource),
		resourceRegenerationPerSecond = base.resourceRegenerationPerSecond,
		physicalAttack = base.physicalAttack + growth.physicalAttack * levelsAfterOne + modifier(modifiers.physicalAttack),
		magicAttack = base.magicAttack + growth.magicAttack * levelsAfterOne + modifier(modifiers.magicAttack),
		physicalDefense = base.physicalDefense + growth.physicalDefense * levelsAfterOne + modifier(modifiers.physicalDefense),
		criticalChance = math.max(0, base.criticalChance + growth.criticalChance * levelsAfterOne + modifier(modifiers.criticalChance)),
		attackSpeedMultiplier = math.max(
			CombatConfig.MinAttackSpeedMultiplier,
			math.min(
				CombatConfig.MaxAttackSpeedMultiplier,
				base.attackSpeedMultiplier + modifier(modifiers.attackSpeedMultiplier)
			)
		),
		movementSpeed = base.movementSpeed,
	}
end

return table.freeze(StatRules)
