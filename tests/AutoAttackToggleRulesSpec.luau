--!strict

local AutoAttackToggleRules = require(game.ReplicatedStorage.Shared.combat.AutoAttackToggleRules)

return function(TestRunner)
	TestRunner.run("AUTO client toggle serializes until authoritative reconciliation", function()
		local state = AutoAttackToggleRules.create(false)
		local desired, generation = AutoAttackToggleRules.requestToggle(state)
		assert(desired == true and generation == 1 and state.pending)
		assert(AutoAttackToggleRules.requestToggle(state) == nil, "pending toggle must suppress repeated input")
		AutoAttackToggleRules.reconcile(state, true)
		assert(state.authoritative and not state.pending)
		local desiredOff = AutoAttackToggleRules.requestToggle(state)
		assert(desiredOff == false)
	end)

	TestRunner.run("AUTO rejected-request timeout restores authoritative desire", function()
		local state = AutoAttackToggleRules.create(false)
		local _, generation = AutoAttackToggleRules.requestToggle(state)
		assert(generation ~= nil)
		AutoAttackToggleRules.expire(state, generation :: number)
		assert(not state.pending and not state.desired and not state.authoritative)
	end)
end
