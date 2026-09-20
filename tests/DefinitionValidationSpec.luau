--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local MobAbilityDefinitions = require(ReplicatedStorage.Shared.definitions.MobAbilityDefinitions)
local LootTableDefinitions = require(ReplicatedStorage.Shared.definitions.LootTableDefinitions)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)

local SUPPORTED_RESOURCES = { Stamina = true, Focus = true, Mana = true }
local SUPPORTED_TARGETS = { Enemy = true, Self = true, Friendly = true, EnemyArea = true }
local SUPPORTED_POWER_SOURCES = { PhysicalAttack = true, MagicAttack = true, None = true }
local SUPPORTED_EFFECTS = {
	DirectDamage = true,
	DirectHealing = true,
	AreaDamage = true,
	ShieldBash = true,
	DefenseStance = true,
	AttackSpeedBuff = true,
	MovementSlow = true,
}
local SUPPORTED_AGGRESSION_MODES = { Passive = true, Aggressive = true }
local SUPPORTED_MOB_RANKS = { Ordinary = true, Elite = true, Boss = true }
local SUPPORTED_MOB_ATTACK_KINDS = { Melee = true, Ranged = true }
local SUPPORTED_MOB_DAMAGE_TYPES = { Physical = true, Magic = true }
local SUPPORTED_MOB_ABILITY_KINDS = {
	DirectDamage = true,
	AreaDamage = true,
	DamageOverTime = true,
	Crippling = true,
	AllyDamageBuff = true,
	SelfDamageBuff = true,
}

local function assertFiniteNumber(value: any, field: string, allowZero: boolean?)
	assert(type(value) == "number", field .. " must be a number")
	assert(value == value and value > -math.huge and value < math.huge, field .. " must be finite")
	if allowZero then
		assert(value >= 0, field .. " must not be negative")
	else
		assert(value > 0, field .. " must be positive")
	end
end

local function assertUniqueStableIds(definitions: { [string]: { id: string } }, kind: string)
	local seen = {}
	for key, definition in definitions do
		assert(type(definition.id) == "string" and definition.id ~= "", kind .. " id is required")
		assert(not seen[definition.id], string.format("duplicate %s id %s", kind, definition.id))
		seen[definition.id] = true
		assert(type(key) == "string" and key ~= "", kind .. " lookup key is required")
	end
end

return function(TestRunner)
	TestRunner.run("combat definitions use unique stable identifiers", function()
		assertUniqueStableIds(ArchetypeDefinitions, "archetype")
		assertUniqueStableIds(SkillDefinitions, "skill")
		assertUniqueStableIds(MobDefinitions, "mob")
		assertUniqueStableIds(MobAbilityDefinitions, "mob ability")
	end)

	TestRunner.run("archetypes declare their approved resource and basic attack", function()
		assert(ArchetypeDefinitions.knight.resourceType == "Stamina")
		assert(ArchetypeDefinitions.ranger.resourceType == "Focus")
		assert(ArchetypeDefinitions.mystic.resourceType == "Mana")

		for _, definition in ArchetypeDefinitions do
			assert(type(definition.displayName) == "string" and definition.displayName ~= "", definition.id .. ".displayName is required")
			assert(SUPPORTED_RESOURCES[definition.resourceType], definition.id .. ".resourceType is unsupported")
			assert(type(definition.basicAttackId) == "string" and definition.basicAttackId ~= "", definition.id .. ".basicAttackId is required")
			assert(SkillDefinitions[definition.basicAttackId] ~= nil, definition.id .. ".basicAttackId must reference a skill")
			assert(#definition.skillIds == 3, definition.id .. ".skillIds must define the three ordered action-bar skills")
			local seenSkills = {}
			for _, skillId in definition.skillIds do
				assert(not seenSkills[skillId], definition.id .. ".skillIds must be unique")
				seenSkills[skillId] = true
				local skill = SkillDefinitions[skillId]
				assert(skill ~= nil and skill.archetypeId == definition.id, definition.id .. ".skillIds must reference owned skills")
				assert(skillId ~= definition.basicAttackId, definition.id .. ".skillIds must not duplicate basic attack")
			end
		end
	end)

	TestRunner.run("skills reference supported milestone one contracts", function()
		for _, definition in SkillDefinitions do
			local archetype = ArchetypeDefinitions[definition.archetypeId]
			local prefix = definition.id .. "."
			assert(type(definition.displayName) == "string" and definition.displayName ~= "", prefix .. "displayName is required")
			assertFiniteNumber(definition.unlockLevel, prefix .. "unlockLevel")
			assert(definition.unlockLevel % 1 == 0 and definition.unlockLevel <= ProgressionConfig.LevelCap, prefix .. "unlockLevel must be a supported integer level")
			assert(archetype ~= nil, prefix .. "archetypeId must reference an archetype")
			assert(definition.resourceType == archetype.resourceType, prefix .. "resourceType must match archetype")
			assert(SUPPORTED_TARGETS[definition.targetType], prefix .. "targetType is unsupported")
			assert(SUPPORTED_POWER_SOURCES[definition.powerSource], prefix .. "powerSource is unsupported")
			assert(type(definition.effect) == "table", prefix .. "effect is required")
			assert(SUPPORTED_EFFECTS[definition.effect.kind], prefix .. "effect.kind is unsupported")
			assert(type(definition.cooldownGroup) == "string" and definition.cooldownGroup ~= "", prefix .. "cooldownGroup is required")
			assert(CombatConfig.CooldownGroups[definition.cooldownGroup], prefix .. "cooldownGroup must exist")
			assert(type(definition.presentationKey) == "string" and definition.presentationKey ~= "", prefix .. "presentationKey is required")
			assertFiniteNumber(definition.range, prefix .. "range", true)
			assertFiniteNumber(definition.windupSeconds, prefix .. "windupSeconds", true)
			assertFiniteNumber(definition.cooldownSeconds, prefix .. "cooldownSeconds", true)
			assertFiniteNumber(definition.resourceCost, prefix .. "resourceCost", true)
			assert(type(definition.requiresFacing) == "boolean", prefix .. "requiresFacing must be boolean")
			assert(type(definition.canCrit) == "boolean", prefix .. "canCrit must be boolean")
			assert(type(definition.canMoveDuringWindup) == "boolean", prefix .. "canMoveDuringWindup must be boolean")
			assert(type(definition.interruptible) == "boolean", prefix .. "interruptible must be boolean")

			local effectPrefix = prefix .. "effect."
			if definition.effect.kind == "DirectDamage" or definition.effect.kind == "DirectHealing" then
				assertFiniteNumber(definition.effect.magnitude, effectPrefix .. "magnitude")
			elseif definition.effect.kind == "AreaDamage" then
				assertFiniteNumber(definition.effect.magnitude, effectPrefix .. "magnitude")
				assertFiniteNumber(definition.effect.radius, effectPrefix .. "radius")
			elseif definition.effect.kind == "ShieldBash" then
				assertFiniteNumber(definition.effect.magnitude, effectPrefix .. "magnitude")
				assertFiniteNumber(definition.effect.durationSeconds, effectPrefix .. "durationSeconds")
				assert(definition.effect.stunsOrdinaryMobs == true, effectPrefix .. "stunsOrdinaryMobs must be true")
				assert(definition.effect.interruptsEligibleImmuneMobs == true, effectPrefix .. "interruptsEligibleImmuneMobs must be true")
			elseif definition.effect.kind == "DefenseStance" then
				assertFiniteNumber(definition.effect.magnitude, effectPrefix .. "magnitude")
				assertFiniteNumber(definition.effect.movementSpeedMultiplier, effectPrefix .. "movementSpeedMultiplier")
				assert(definition.effect.isToggle == true, effectPrefix .. "isToggle must be true")
			elseif definition.effect.kind == "AttackSpeedBuff" then
				assertFiniteNumber(definition.effect.magnitude, effectPrefix .. "magnitude")
				assertFiniteNumber(definition.effect.durationSeconds, effectPrefix .. "durationSeconds")
			elseif definition.effect.kind == "MovementSlow" then
				assertFiniteNumber(definition.effect.magnitude, effectPrefix .. "magnitude")
				assertFiniteNumber(definition.effect.durationSeconds, effectPrefix .. "durationSeconds")
				assert(definition.effect.refreshDurationOnReapply == true, effectPrefix .. "must refresh on reapply")
			end
			if definition.effect.kind == "AreaDamage" then
				assertFiniteNumber(definition.effect.radius, prefix .. "effect.radius")
				assert(definition.effect.radius > 0, prefix .. "effect.radius must be positive")
				assertFiniteNumber(definition.effect.maximumTargets, prefix .. "effect.maximumTargets")
				assert(definition.effect.maximumTargets >= 1 and definition.effect.maximumTargets % 1 == 0, prefix .. "effect.maximumTargets must be a positive integer")
			end
		end
	end)

	TestRunner.run("approved skill behavior is represented by data", function()
		local shieldBash = SkillDefinitions.shield_bash
		local shieldBashEffect = shieldBash.effect
		assert(shieldBashEffect.kind == "ShieldBash")
		assert(shieldBash.powerSource == "PhysicalAttack")
		assertFiniteNumber(shieldBashEffect.magnitude, "shield_bash.effect.magnitude")
		assert(shieldBashEffect.stunsOrdinaryMobs == true)
		assert(shieldBashEffect.interruptsEligibleImmuneMobs == true)

		local defensiveStance = SkillDefinitions.defensive_stance
		local defensiveStanceEffect = defensiveStance.effect
		assert(defensiveStanceEffect.kind == "DefenseStance")
		assert(defensiveStanceEffect.isToggle == true)
		assert(defensiveStanceEffect.movementSpeedMultiplier < 1)

		local snare = SkillDefinitions.snare
		local snareEffect = snare.effect
		assert(snareEffect.kind == "MovementSlow")
		assert(snareEffect.refreshDurationOnReapply == true)

		local heal = SkillDefinitions.heal
		local healEffect = heal.effect
		assert(healEffect.kind == "DirectHealing")
		assert(healEffect.selfCastWithoutFriendlyTarget == true)
		assert(heal.canCrit == false)
	end)

	TestRunner.run("basic attacks use canonical combat tuning", function()
		assert(SkillDefinitions.knight_basic_attack.range == CombatConfig.BasicAttackRange)
		assert(SkillDefinitions.knight_basic_attack.windupSeconds == CombatConfig.BasicAttackWindupSeconds)
		assert(SkillDefinitions.knight_basic_attack.cooldownSeconds == CombatConfig.BasicAttackInterval)
		assert(CombatConfig.BasicAttackWindupSeconds >= 0)
		assert(CombatConfig.BasicAttackWindupSeconds < CombatConfig.BasicAttackInterval)
		assert(SkillDefinitions.ranger_basic_attack.range == CombatConfig.RangerBasicAttackRange)
		assert(SkillDefinitions.ranger_basic_attack.cooldownSeconds == CombatConfig.RangerBasicAttackInterval)
		assert(SkillDefinitions.mystic_basic_attack.range == CombatConfig.MysticBasicAttackRange)
		assert(SkillDefinitions.mystic_basic_attack.cooldownSeconds == CombatConfig.MysticBasicAttackInterval)
	end)

	TestRunner.run("mob definitions cover the v0.1 world population and combat contract", function()
		assert(MobDefinitions.young_wolf.level == 1 and MobDefinitions.young_wolf.rewardXP == 15)
		assert(MobDefinitions.grey_wolf.level == 2 and MobDefinitions.grey_wolf.rewardXP == 25)
		assert(MobDefinitions.wolf_pack_leader.level == 3)
		assert(MobDefinitions.spider.level == 4 and MobDefinitions.spider.rewardXP == 50)
		assert(MobDefinitions.goblin_chieftain.rank == "Elite")
		assert(MobDefinitions.spider.socialAssistRadius == 0)
		assert(MobDefinitions.brood_spider.socialAssistRadius == 0)
		assert(MobDefinitions.moonbound_warden.level == 14 and MobDefinitions.moonbound_warden.rank == "Elite")
		assert(MobDefinitions.young_wolf.aggressionMode == "Passive")
		assert(MobDefinitions.grey_wolf.aggressionMode == "Aggressive")
		assert(MobDefinitions.grey_wolf.attackKind == "Melee")
		assert(MobDefinitions.spider.attackKind == "Ranged")

		for _, definition in MobDefinitions do
			local prefix = definition.id .. "."
			assert(type(definition.displayName) == "string" and definition.displayName ~= "", prefix .. "displayName is required")
			assertFiniteNumber(definition.level, prefix .. "level")
			assert(definition.level % 1 == 0 and definition.level >= 1 and definition.level <= ProgressionConfig.LevelCap, prefix .. "level must be a supported integer")
			assert(SUPPORTED_AGGRESSION_MODES[definition.aggressionMode], prefix .. "aggressionMode is unsupported")
			assert(SUPPORTED_MOB_RANKS[definition.rank], prefix .. "rank is unsupported")
			assert(SUPPORTED_MOB_ATTACK_KINDS[definition.attackKind], prefix .. "attackKind is unsupported")
			assert(SUPPORTED_MOB_DAMAGE_TYPES[definition.basicAttackDamageType], prefix .. "basicAttackDamageType is unsupported")
			assert(type(definition.faction) == "string" and definition.faction ~= "", prefix .. "faction is required")
			assert(type(definition.visualProfile) == "string" and definition.visualProfile ~= "", prefix .. "visualProfile is required")
			assertFiniteNumber(definition.maxHealth, prefix .. "maxHealth")
			assertFiniteNumber(definition.physicalDefense, prefix .. "physicalDefense", true)
			assertFiniteNumber(definition.magicDefense, prefix .. "magicDefense", true)
			assertFiniteNumber(definition.rewardXP, prefix .. "rewardXP", true)
			assert(type(definition.lootTableId) == "string" and LootTableDefinitions[definition.lootTableId] ~= nil, prefix .. "lootTableId must reference a loot table")
			assertFiniteNumber(definition.respawnSeconds, prefix .. "respawnSeconds")
			assertFiniteNumber(definition.detectionRadius, prefix .. "detectionRadius", true)
			assertFiniteNumber(definition.aggroRadius, prefix .. "aggroRadius", true)
			assertFiniteNumber(definition.reacquireRadius, prefix .. "reacquireRadius", true)
			assertFiniteNumber(definition.leashDistance, prefix .. "leashDistance")
			assertFiniteNumber(definition.attackRange, prefix .. "attackRange")
			assertFiniteNumber(definition.basicAttackRange, prefix .. "basicAttackRange")
			assert(definition.basicAttackRange <= definition.attackRange, prefix .. "basic attack range cannot exceed engagement range")
			assertFiniteNumber(definition.basicAttackDamage, prefix .. "basicAttackDamage")
			if definition.criticalChance ~= nil then
				assertFiniteNumber(definition.criticalChance, prefix .. "criticalChance", true)
				assert(definition.criticalChance <= 1, prefix .. "criticalChance must be at most one")
			end
			if definition.criticalDamageMultiplier ~= nil then
				assertFiniteNumber(definition.criticalDamageMultiplier, prefix .. "criticalDamageMultiplier")
				assert(definition.criticalDamageMultiplier >= 1, prefix .. "criticalDamageMultiplier must be at least one")
			end
			assertFiniteNumber(definition.attackWindupSeconds, prefix .. "attackWindupSeconds", true)
			assertFiniteNumber(definition.attackIntervalSeconds, prefix .. "attackIntervalSeconds")
			assert(definition.attackWindupSeconds < definition.attackIntervalSeconds, prefix .. "attack windup must finish before the next attack")
			assertFiniteNumber(definition.chaseSpeed, prefix .. "chaseSpeed")
			assertFiniteNumber(definition.decisionIntervalSeconds, prefix .. "decisionIntervalSeconds")
			assertFiniteNumber(definition.socialAssistRadius, prefix .. "socialAssistRadius", true)
			assert(type(definition.restoreHealthOnReturn) == "boolean", prefix .. "restoreHealthOnReturn must be boolean")
			assert(type(definition.abilityIds) == "table", prefix .. "abilityIds must be a table")
			local seenAbilities = {}
			for _, abilityId in definition.abilityIds do
				assert(not seenAbilities[abilityId], prefix .. "abilityIds must be unique")
				seenAbilities[abilityId] = true
				assert(MobAbilityDefinitions[abilityId] ~= nil, prefix .. "references unknown ability " .. abilityId)
			end
		end
	end)

	TestRunner.run("mob abilities use bounded server-authoritative tuning", function()
		for key, ability in MobAbilityDefinitions do
			local prefix = ability.id .. "."
			assert(key == ability.id)
			assert(type(ability.displayName) == "string" and ability.displayName ~= "", prefix .. "displayName is required")
			assert(SUPPORTED_MOB_ABILITY_KINDS[ability.kind], prefix .. "kind is unsupported")
			assert(SUPPORTED_MOB_DAMAGE_TYPES[ability.damageType], prefix .. "damageType is unsupported")
			assertFiniteNumber(ability.range, prefix .. "range", true)
			assertFiniteNumber(ability.damage, prefix .. "damage", true)
			assertFiniteNumber(ability.windupSeconds, prefix .. "windupSeconds", true)
			assertFiniteNumber(ability.cooldownSeconds, prefix .. "cooldownSeconds")
			assert(type(ability.presentationKey) == "string" and ability.presentationKey ~= "", prefix .. "presentationKey is required")
			if ability.durationSeconds ~= nil then assertFiniteNumber(ability.durationSeconds, prefix .. "durationSeconds", true) end
			if ability.tickDamage ~= nil then assertFiniteNumber(ability.tickDamage, prefix .. "tickDamage", true) end
			if ability.tickIntervalSeconds ~= nil then assertFiniteNumber(ability.tickIntervalSeconds, prefix .. "tickIntervalSeconds") end
			if ability.movementMultiplier ~= nil then
				assertFiniteNumber(ability.movementMultiplier, prefix .. "movementMultiplier")
				assert(ability.movementMultiplier <= 1, prefix .. "movementMultiplier must not speed the player up")
			end
			if ability.attackSpeedMultiplier ~= nil then
				assertFiniteNumber(ability.attackSpeedMultiplier, prefix .. "attackSpeedMultiplier")
				assert(ability.attackSpeedMultiplier <= 1, prefix .. "attackSpeedMultiplier must not speed the player up")
			end
			if ability.damageMultiplier ~= nil then assertFiniteNumber(ability.damageMultiplier, prefix .. "damageMultiplier") end
			if ability.radius ~= nil then assertFiniteNumber(ability.radius, prefix .. "radius") end
			if ability.healthBelowFraction ~= nil then
				assert(ability.healthBelowFraction > 0 and ability.healthBelowFraction <= 1, prefix .. "healthBelowFraction must be in (0, 1]")
			end
		end

		assert(MobAbilityDefinitions.spider_venom_spit.kind == "DamageOverTime")
		assert(MobAbilityDefinitions.spider_crippling_venom.kind == "Crippling")
		assert(MobAbilityDefinitions.goblin_war_chant.kind == "AllyDamageBuff")
		assert(MobAbilityDefinitions.goblin_shaman_hex.kind == "Crippling")
		assert(MobAbilityDefinitions.goblin_cleave.kind == "AreaDamage")
		assert(MobAbilityDefinitions.goblin_cleave.radius ~= nil and MobAbilityDefinitions.goblin_cleave.radius > 0)
		assert(MobAbilityDefinitions.warden_enrage.healthBelowFraction == 0.55)
		assert(MobDefinitions.goblin_chieftain.criticalChance == 0.20)
		assert(MobDefinitions.goblin_chieftain.criticalDamageMultiplier == 1.80)
		assert(MobDefinitions.goblin_shaman.criticalChance == 0.12)
	end)

	TestRunner.run("loot tables reference known stable item ids", function()
		for key, definition in LootTableDefinitions do
			assert(key == definition.id)
			assert(definition.lunaMin >= 0 and definition.lunaMin <= definition.lunaMax)
			for _, entry in definition.entries do
				assert(ItemDefinitions[entry.itemId] ~= nil, definition.id .. " references unknown item " .. entry.itemId)
				assert(entry.chance >= 0 and entry.chance <= 1)
				assert(entry.minQuantity >= 1 and entry.minQuantity <= entry.maxQuantity)
			end
		end
	end)

	TestRunner.run("combat tuning exposes milestone one server limits", function()
		assert(CombatConfig.InputBufferSeconds > 0)
		assert(CombatConfig.InputBufferSeconds <= 0.25)
		assert(CombatConfig.AttackRequestMinIntervalSeconds > 0)
		assert(CombatConfig.AttackRequestMinIntervalSeconds < CombatConfig.InputBufferSeconds)
		assert(CombatConfig.TargetRequestMinIntervalSeconds > 0)
		assert(CombatConfig.MinAttackSpeedMultiplier > 0)
		assert(CombatConfig.MaxAttackSpeedMultiplier >= CombatConfig.MinAttackSpeedMultiplier)
		assert(CombatConfig.CriticalDamageMultiplier >= 1)
	end)

	TestRunner.run("skill cooldown replication names are stable and unique", function()
		local names = {}
		for skillId in SkillDefinitions do
			local attributeName = CombatConfig.SkillCooldownAttributePrefix .. skillId
			assert(not names[attributeName], "skill cooldown attribute names must be unique")
			names[attributeName] = true
		end
	end)
end
