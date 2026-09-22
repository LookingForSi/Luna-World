--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Shared.types.CombatTypes)
local CooldownRules = require(ReplicatedStorage.Shared.combat.CooldownRules)
local SkillActionLifecycle = require(ReplicatedStorage.Shared.combat.SkillActionLifecycle)

local PlayerCombatState = {}

export type State = {
	readyAt: number,
	actionState: "Ready" | "Windup" | "Recovery",
	bufferedTargetId: string?,
	generation: number,
	archetypeId: string,
	stats: CombatTypes.CombatStatSnapshot,
	regenerationElapsed: number,
	cooldowns: CooldownRules.CooldownDeadlines,
	skillSlot: SkillActionLifecycle.Slot,
	autoAttackEnabled: boolean,
	autoAttackNextAttemptAt: number,
	pendingBasicActionId: string?,
}

function PlayerCombatState.new(
	archetypeId: string,
	stats: CombatTypes.CombatStatSnapshot,
	cooldowns: CooldownRules.CooldownDeadlines
): State
	return {
		readyAt = 0,
		actionState = "Ready",
		bufferedTargetId = nil,
		generation = 0,
		archetypeId = archetypeId,
		stats = stats,
		regenerationElapsed = 0,
		cooldowns = cooldowns,
		skillSlot = SkillActionLifecycle.createSlot(),
		autoAttackEnabled = false,
		autoAttackNextAttemptAt = 0,
		pendingBasicActionId = nil,
	}
end

return table.freeze(PlayerCombatState)
