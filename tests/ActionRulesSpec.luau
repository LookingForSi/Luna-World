--!strict

local ActionRules = require(game.ReplicatedStorage.Shared.combat.ActionRules)

return function(TestRunner)
	TestRunner.run("action timing accepts at the server readiness boundary", function()
		local result = ActionRules.evaluateTiming(10, 10, 0.2, false)
		assert(result.kind == "Accept")
	end)

	TestRunner.run("action timing rejects a request before the buffer window", function()
		local result = ActionRules.evaluateTiming(9.79, 10, 0.2, false)
		assert(result.kind == "Reject" and result.reason == "Cooldown")
	end)

	TestRunner.run("action timing stores one request inside the buffer window", function()
		local result = ActionRules.evaluateTiming(9.8, 10, 0.2, false)
		assert(result.kind == "Buffer")
	end)

	TestRunner.run("a full buffer rejects another request without changing its deadline", function()
		local result = ActionRules.evaluateTiming(9.9, 10, 0.2, true)
		assert(result.kind == "Reject" and result.reason == "Cooldown")

		local boundaryResult = ActionRules.evaluateTiming(10, 10, 0.2, true)
		assert(boundaryResult.kind == "Reject" and boundaryResult.reason == "Cooldown")
	end)

	TestRunner.run("buffer clears for target changes death and forbidden state", function()
		assert(not ActionRules.shouldClearBuffer("wolf-1", "wolf-1", true, false))
		assert(ActionRules.shouldClearBuffer("wolf-1", "wolf-2", true, false))
		assert(ActionRules.shouldClearBuffer("wolf-1", "wolf-1", false, false))
		assert(ActionRules.shouldClearBuffer("wolf-1", "wolf-1", true, true))
	end)

	TestRunner.run("range includes its configured boundary", function()
		assert(ActionRules.isWithinRange(Vector3.zero, Vector3.new(3, 4, 0), 5, 0))
		assert(not ActionRules.isWithinRange(Vector3.zero, Vector3.new(3, 4, 0), 4.99, 0))
	end)

	TestRunner.run("facing ignores ordinary height differences", function()
		local origin = Vector3.zero
		local forward = Vector3.new(0, 0, -1)
		assert(ActionRules.isFacing(origin, forward, Vector3.new(0, 50, -10), 90))
		assert(not ActionRules.isFacing(origin, forward, Vector3.new(0, 50, 10), 90))
	end)

	TestRunner.run("incompatible action state blocks without a global cooldown", function()
		assert(ActionRules.canStartAction("Ready"))
		assert(not ActionRules.canStartAction("Windup"))
		assert(not ActionRules.canStartAction("Recovery"))
	end)

	TestRunner.run("request rate limit uses authoritative time and permits its boundary", function()
		assert(not ActionRules.isRequestRateLimited(10, nil, 0.03))
		assert(ActionRules.isRequestRateLimited(10.02, 10, 0.03))
		assert(not ActionRules.isRequestRateLimited(10.03, 10, 0.03))
	end)
end
