--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local SkillDefinitions = require(ReplicatedStorage.Shared.definitions.SkillDefinitions)

local CombatFeature = ServerScriptService.Server.features.combat
local AutoAttackService = require(CombatFeature.AutoAttackService)
local BasicAttackService = require(CombatFeature.BasicAttackService)
local PlayerCombatState = require(CombatFeature.PlayerCombatState)
local SkillExecutionService = require(CombatFeature.SkillExecutionService)
local TargetingService = require(CombatFeature.TargetingService)

local function snapshot(resourceCurrent: number, attackSpeedMultiplier: number)
	return {
		physicalAttack = 10,
		magicAttack = 10,
		physicalDefense = 1,
		magicDefense = 1,
		criticalChance = 0,
		criticalMultiplier = 1,
		attackSpeedMultiplier = attackSpeedMultiplier,
		movementSpeedMultiplier = 1,
		resource = { resourceType = "Stamina", current = resourceCurrent, maximum = 100 },
		resourceRegenerationPerSecond = 0,
	}
end

return function(TestRunner)
	TestRunner.run("PlayerCombatState creates isolated authoritative defaults", function()
		local cooldowns = { shared = 7 }
		local state = PlayerCombatState.new("knight", snapshot(50, 1), cooldowns)
		assert(state.readyAt == 0 and state.actionState == "Ready")
		assert(state.bufferedTargetId == nil and state.generation == 0)
		assert(state.cooldowns == cooldowns, "the coordinator-owned cooldown table must retain identity")
		assert(not state.autoAttackEnabled and state.autoAttackNextAttemptAt == 0)
		assert(state.pendingBasicActionId == nil and state.skillSlot.pending == nil)
	end)

	TestRunner.run("BasicAttackService resolves archetype definition and scaled interval", function()
		local state = PlayerCombatState.new("knight", snapshot(100, 2), {})
		local definition = BasicAttackService.getDefinition(state)
		assert(definition == SkillDefinitions[ArchetypeDefinitions.knight.basicAttackId])
		local expected = definition.cooldownSeconds / math.clamp(
			state.stats.attackSpeedMultiplier,
			CombatConfig.MinAttackSpeedMultiplier,
			CombatConfig.MaxAttackSpeedMultiplier
		)
		assert(BasicAttackService.getInterval(state) == expected)
	end)

	TestRunner.run("SkillExecutionService gates state cooldown resource and target without mutation", function()
		local definition = SkillDefinitions.power_strike
		assert(definition ~= nil)
		local state = PlayerCombatState.new("knight", snapshot(100, 1), {})
		local accepted = SkillExecutionService.evaluate(state, definition, 10, true)
		assert(accepted.accepted and accepted.cooldownReady and accepted.resourceAfterCost ~= nil)
		assert(state.stats.resource.current == 100, "evaluation must not spend before coordinator acceptance")
		state.actionState = "Windup"
		assert(not SkillExecutionService.evaluate(state, definition, 10, true).accepted)
		state.actionState = "Ready"
		state.cooldowns[definition.cooldownGroup] = 11
		assert(not SkillExecutionService.evaluate(state, definition, 10, true).accepted)
		state.cooldowns = {}
		state.stats.resource.current = 0
		assert(not SkillExecutionService.evaluate(state, definition, 10, true).accepted)
		state.stats.resource.current = 100
		assert(not SkillExecutionService.evaluate(state, definition, 10, false).accepted)
	end)

	TestRunner.run("AutoAttackService preserves request rate-limit bookkeeping", function()
		local accepted = AutoAttackService.evaluateEnable(1, true, 10, nil, true, true)
		assert(accepted.accepted and accepted.enabled == true and accepted.stampRequestAt)
		local limited = AutoAttackService.evaluateEnable(1, true, 10, 10, true, true)
		assert(limited.rateLimited and not limited.accepted and not limited.stampRequestAt)
		local invalid = AutoAttackService.evaluateEnable(1, true, 20, nil, true, false)
		assert(not invalid.rateLimited and not invalid.accepted and invalid.stampRequestAt)
	end)

	TestRunner.run("AutoAttackService preserves stop attempt wait and retry timing", function()
		local stopped = AutoAttackService.evaluateTick(10, 10, 12, "Ready", false, true, true, true)
		assert(stopped.kind == "Stop" and stopped.nextAttemptAt == 0)
		local attempted = AutoAttackService.evaluateTick(10, 10, 12, "Ready", true, true, true, true)
		assert(attempted.kind == "Attempt" and attempted.nextAttemptAt == 12)
		local waited = AutoAttackService.evaluateTick(10, 10, 8, "Windup", true, true, true, true)
		assert(waited.kind == "Wait")
		assert(waited.nextAttemptAt == 10 + CombatConfig.AutoAttackRetryIntervalSeconds)
	end)

	TestRunner.run("TargetingService returns the exact canonical player candidate", function()
		local players = game:GetService("Players"):GetPlayers()
		for _, player in players do
			assert(TargetingService.findPlayerByCanonicalTargetId("player:" .. player.UserId, players) == player)
		end
		assert(TargetingService.findPlayerByCanonicalTargetId("player:-1", players) == nil)
		assert(TargetingService.findPlayerByCanonicalTargetId("mob:1", players) == nil)
	end)
end
