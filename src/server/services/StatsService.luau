--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local ResourceRules = require(ReplicatedStorage.Shared.combat.ResourceRules)
local StatRules = require(ReplicatedStorage.Shared.progression.StatRules)
local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local ProgressionTypes = require(ReplicatedStorage.Shared.types.ProgressionTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local StatsService = {}

local MODIFIER_FIELDS = {
	"maxHealth",
	"maxResource",
	"physicalAttack",
	"magicAttack",
	"physicalDefense",
	"criticalChance",
	"attackSpeedMultiplier",
}

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

function StatsService.aggregateEquipmentModifiers(profile: any): ProgressionTypes.StatModifiers
	local totals: any = {}
	for _, instanceId in profile.Equipment do
		if instanceId ~= nil then
			local record = profile.Items[instanceId]
			local definition = if record ~= nil then ItemDefinitions[record.ItemId] else nil
			if definition ~= nil then
				for _, field in MODIFIER_FIELDS do
					local value = definition.statModifiers[field]
					if typeof(value) == "number" then
						totals[field] = (totals[field] or 0) + value
					end
				end
			end
		end
	end
	return totals :: ProgressionTypes.StatModifiers
end

function StatsService.derive(
	player: Player,
	archetypeId: string,
	equipmentModifiers: ProgressionTypes.StatModifiers?
): ProgressionTypes.DerivedStats
	local modifiers = equipmentModifiers
	if modifiers == nil then
		local profile = PlayerDataService.getProfileCopy(player)
		if profile ~= nil then modifiers = StatsService.aggregateEquipmentModifiers(profile) end
	end
	return StatRules.derive(archetypeId, resolveLevel(player), modifiers)
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
