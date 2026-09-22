--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local CooldownRules = require(ReplicatedStorage.Shared.combat.CooldownRules)
local ResourceRules = require(ReplicatedStorage.Shared.combat.ResourceRules)
local SkillRules = require(ReplicatedStorage.Shared.combat.SkillRules)

local PlayerCombatState = require(script.Parent.PlayerCombatState)

local SkillExecutionService = {}

export type Evaluation = {
	accepted: boolean,
	cooldownReady: boolean,
	resourceAfterCost: CombatTypes.CombatResource?,
}

function SkillExecutionService.evaluate(
	state: PlayerCombatState.State,
	definition: CombatTypes.SkillDefinition,
	now: number,
	hasValidTarget: boolean
): Evaluation
	local resourceAfterCost = ResourceRules.spend(
		state.stats.resource,
		definition.resourceType,
		definition.resourceCost
	)
	local cooldownReady = CooldownRules.isReady(state.cooldowns, definition.cooldownGroup, now)
	return {
		accepted = SkillRules.canAccept(
			state.actionState,
			cooldownReady,
			resourceAfterCost ~= nil,
			hasValidTarget
		),
		cooldownReady = cooldownReady,
		resourceAfterCost = resourceAfterCost,
	}
end

return table.freeze(SkillExecutionService)
