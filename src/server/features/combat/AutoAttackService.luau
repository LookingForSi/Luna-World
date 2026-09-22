--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionRules = require(ReplicatedStorage.Shared.combat.ActionRules)
local AutoAttackRules = require(ReplicatedStorage.Shared.combat.AutoAttackRules)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)

local AutoAttackService = {}

export type EnableDecision = {
	rateLimited: boolean,
	accepted: boolean,
	enabled: boolean?,
	stampRequestAt: boolean,
}

function AutoAttackService.evaluateEnable(
	argumentCount: number,
	requestedEnabled: boolean,
	now: number,
	lastRequestAt: number?,
	actorAlive: boolean,
	hasLivingMobTarget: boolean
): EnableDecision
	if ActionRules.isRequestRateLimited(
		now,
		lastRequestAt,
		CombatConfig.AutoAttackRequestMinIntervalSeconds
	) then
		return {
			rateLimited = true,
			accepted = false,
			enabled = nil,
			stampRequestAt = false,
		}
	end

	local decision = AutoAttackRules.validateRequest(
		argumentCount,
		requestedEnabled,
		actorAlive,
		hasLivingMobTarget
	)
	return {
		rateLimited = false,
		accepted = decision.accepted,
		enabled = decision.enabled,
		stampRequestAt = true,
	}
end

export type TickDecision = {
	kind: "Stop" | "Attempt" | "Wait",
	nextAttemptAt: number?,
}

function AutoAttackService.evaluateTick(
	now: number,
	currentNextAttemptAt: number,
	readyAt: number,
	actionState: string,
	playerPresent: boolean,
	actorAlive: boolean,
	hasCharacter: boolean,
	hasLivingMobTarget: boolean
): TickDecision
	if AutoAttackRules.shouldStop(playerPresent, actorAlive, hasCharacter, hasLivingMobTarget) then
		return { kind = "Stop", nextAttemptAt = 0 }
	end

	if AutoAttackRules.shouldAttempt(now, currentNextAttemptAt, actionState) then
		return { kind = "Attempt", nextAttemptAt = nil }
	end

	return {
		kind = "Wait",
		nextAttemptAt = AutoAttackRules.nextAttemptAt(
			now,
			readyAt,
			CombatConfig.AutoAttackRetryIntervalSeconds
		),
	}
end

return table.freeze(AutoAttackService)
