--!strict

local ActionRules = require(game.ReplicatedStorage.Shared.combat.ActionRules)

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
end
