--!strict

local ActionRules = require(game.ReplicatedStorage.Shared.combat.ActionRules)
local CooldownRules = require(game.ReplicatedStorage.Shared.combat.CooldownRules)
local ResourceRules = require(game.ReplicatedStorage.Shared.combat.ResourceRules)
local SkillRules = require(game.ReplicatedStorage.Shared.combat.SkillRules)
local EffectRules = require(game.ReplicatedStorage.Shared.combat.EffectRules)
local MobAIRules = require(game.ReplicatedStorage.Shared.combat.MobAIRules)

return function(TestRunner)
	TestRunner.run("manual input lifecycle accepts one request and buffers at most one", function()
		local readyAt = 10
		assert(ActionRules.evaluateTiming(10, readyAt, 0.2, false).kind == "Accept")
		assert(ActionRules.evaluateTiming(10.5, 11.2, 0.2, false).kind == "Reject")
		assert(ActionRules.evaluateTiming(11.05, 11.2, 0.2, false).kind == "Buffer")
		assert(ActionRules.evaluateTiming(11.1, 11.2, 0.2, true).kind == "Reject")
	end)

	TestRunner.run("buffered intent is invalidated when its target changes", function()
		assert(ActionRules.shouldClearBuffer("wolf-1", "wolf-2", true, false))
		assert(ActionRules.shouldClearBuffer("wolf-1", nil, true, false))
	end)

	TestRunner.run("accepted manual attack revalidates every resolve condition", function()
		local function canResolve(currentTargetId: string?, actorAlive: boolean, targetAlive: boolean, inRange: boolean, isFacing: boolean): boolean
			return ActionRules.canResolveAttack("wolf-1", currentTargetId, actorAlive, targetAlive, inRange, isFacing)
		end

		assert(canResolve("wolf-1", true, true, true, true))
		assert(not canResolve("wolf-2", true, true, true, true), "target switch must cancel damage")
		assert(not canResolve("wolf-1", true, false, true, true), "target death must cancel damage")
		assert(not canResolve("wolf-1", true, true, false, true), "range must be checked at resolve")
		assert(not canResolve("wolf-1", true, true, true, false), "facing must be checked at resolve")
	end)

	TestRunner.run("actor lifecycle invalidates pending combat state", function()
		assert(not ActionRules.shouldInvalidatePlayerState(true, true, true))
		assert(ActionRules.shouldInvalidatePlayerState(true, false, true), "actor death must invalidate state")
		assert(ActionRules.shouldInvalidatePlayerState(true, true, false), "character replacement must invalidate state")
		assert(ActionRules.shouldInvalidatePlayerState(false, true, true), "PlayerRemoving must invalidate state")
	end)

	TestRunner.run("authoritative readiness accepts even if a recovery scheduler runs late", function()
		local now = 20
		local readyAt = 20
		local staleActionState = "Recovery"
		if staleActionState == "Recovery" and now >= readyAt then
			staleActionState = "Ready"
		end
		assert(staleActionState == "Ready")
		assert(ActionRules.evaluateTiming(now, readyAt, 0.2, false).kind == "Accept")
	end)

	TestRunner.run("accepted skill cost and cooldown survive a later resolve failure", function()
		local resource = ResourceRules.create("Stamina", 100)
		local cooldowns: CooldownRules.CooldownDeadlines = {}
		assert(SkillRules.canAccept("Ready", CooldownRules.isReady(cooldowns, "power_strike", 10), ResourceRules.canSpend(resource, "Stamina", 20), true))
		local spent = ResourceRules.spend(resource, "Stamina", 20)
		assert(spent ~= nil)
		resource = spent
		cooldowns = CooldownRules.start(cooldowns, "power_strike", 10, 4)

		-- Resolve-time target failure does not roll back acceptance state.
		assert(not SkillRules.isEnemyTargetValid("wolf-1", "wolf-1", true, false, true, true))
		assert(resource.current == 80)
		assert(not CooldownRules.isReady(cooldowns, "power_strike", 13.9))
	end)

	TestRunner.run("two skill attempts cannot consume resource through one action slot", function()
		local resource = ResourceRules.create("Focus", 100)
		local actionState: "Ready" | "Windup" | "Recovery" = "Ready"
		local accepted = 0
		for _ = 1, 2 do
			if SkillRules.canAccept(actionState, true, ResourceRules.canSpend(resource, "Focus", 20), true) then
				local spent = ResourceRules.spend(resource, "Focus", 20)
				assert(spent ~= nil)
				resource = spent
				actionState = "Windup"
				accepted += 1
			end
		end
		assert(accepted == 1)
		assert(resource.current == 80)
	end)

	TestRunner.run("ordinary shield stun invalidates a pending mob action", function()
		local acceptedGeneration = 4
		local stunDecision = EffectRules.resolveShieldBash("Ordinary", true, true, false)
		assert(stunDecision.shouldStun)
		local currentGeneration = EffectRules.invalidateMobActionGeneration(acceptedGeneration)
		local stunnedUntil = 21.5
		assert(not EffectRules.canResolveMobAction(acceptedGeneration, currentGeneration, stunnedUntil, 20.5))
		assert(not EffectRules.canResolveMobAction(acceptedGeneration, currentGeneration, stunnedUntil, 22), "canceled action must remain stale after stun expires")
		assert(EffectRules.canResolveMobAction(currentGeneration, currentGeneration, stunnedUntil, 22), "a new post-stun action may resolve")
	end)

	TestRunner.run("mob AI lifecycle acquires attacks reacquires and returns without parallel state", function()
		local state: MobAIRules.State = "Idle"
		state = MobAIRules.nextState(state, { alive = true, hasTarget = true, detectedTarget = true, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = true }, "Aggressive")
		assert(state == "Aggro")
		state = MobAIRules.nextState(state, { alive = true, hasTarget = true, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = false }, "Aggressive")
		assert(state == "Chase")
		state = MobAIRules.nextState(state, { alive = true, hasTarget = true, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = true, atHome = false }, "Aggressive")
		assert(state == "Attack")
		assert(MobAIRules.nearestEligible({ { id = "player-a", distance = 7, eligible = true } }, 10) == "player-a")
		state = MobAIRules.nextState(state, { alive = true, hasTarget = false, detectedTarget = false, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = false }, "Aggressive")
		assert(state == "Return")
		state = MobAIRules.nextState(state, { alive = true, hasTarget = false, detectedTarget = true, hostileAttacker = false, beyondLeash = false, inAttackRange = false, atHome = true }, "Aggressive")
		assert(state == "Idle", "return must ignore detection until home")
	end)
end
