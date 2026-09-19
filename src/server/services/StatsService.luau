--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ResourceRules = require(ReplicatedStorage.Shared.combat.ResourceRules)
local StatRules = require(ReplicatedStorage.Shared.progression.StatRules)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local ProgressionTypes = require(ReplicatedStorage.Shared.types.ProgressionTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StatsService = {}

export type Snapshot = {
	maxHealth: number,
	combat: CombatTypes.CombatStatSnapshot,
}

local function resolveLevel(player: Player): number
	local profile = PlayerDataService.getProfileCopy(player)
	if profile ~= nil then return profile.Level end
	local attribute = player:GetAttribute(ProgressionConfig.LevelAttribute)
	if typeof(attribute) == "number" then
		return math.clamp(math.floor(attribute), 1, ProgressionConfig.LevelCap)
	end
	return 1
end

function StatsService.derive(
	player: Player,
	archetypeId: string,
	equipmentModifiers: ProgressionTypes.StatModifiers?
): ProgressionTypes.DerivedStats
	return StatRules.derive(archetypeId, resolveLevel(player), equipmentModifiers)
end

function StatsService.createCombatSnapshot(
	player: Player,
	archetypeId: string,
	equipmentModifiers: ProgressionTypes.StatModifiers?
): Snapshot
	local archetype = ArchetypeDefinitions[archetypeId]
	assert(archetype ~= nil, "combat snapshot requires a known archetype")
	local derived = StatsService.derive(player, archetypeId, equipmentModifiers)
	return {
		maxHealth = derived.maxHealth,
		combat = {
			resource = ResourceRules.create(archetype.resourceType, derived.maxResource),
			resourceRegenerationPerSecond = derived.resourceRegenerationPerSecond,
			physicalAttack = derived.physicalAttack,
			magicAttack = derived.magicAttack,
			basePhysicalDefense = derived.physicalDefense,
			physicalDefense = derived.physicalDefense,
			baseAttackSpeedMultiplier = derived.attackSpeedMultiplier,
			attackSpeedMultiplier = derived.attackSpeedMultiplier,
			criticalChance = derived.criticalChance,
			baseMovementSpeed = derived.movementSpeed,
			movementSpeed = derived.movementSpeed,
		},
	}
end

return StatsService
