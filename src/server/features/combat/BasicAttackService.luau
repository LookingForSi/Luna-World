--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local DamageRules = require(ReplicatedStorage.Shared.combat.DamageRules)
local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)

local PlayerCombatState = require(script.Parent.PlayerCombatState)

local BasicAttackService = {}

function BasicAttackService.getDefinition(state: PlayerCombatState.State): CombatTypes.SkillDefinition
	local archetype = ArchetypeDefinitions[state.archetypeId]
	assert(archetype ~= nil, "combat state has an unknown archetype")

	local definition = SkillDefinitions[archetype.basicAttackId]
	assert(definition ~= nil, "archetype has an unknown basic attack")
	return definition
end

function BasicAttackService.getInterval(state: PlayerCombatState.State): number
	local definition = BasicAttackService.getDefinition(state)
	return DamageRules.getBasicAttackInterval(
		definition.cooldownSeconds,
		state.stats.attackSpeedMultiplier,
		CombatConfig.MinAttackSpeedMultiplier,
		CombatConfig.MaxAttackSpeedMultiplier
	)
end

return table.freeze(BasicAttackService)
