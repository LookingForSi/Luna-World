--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)

return function(TestRunner)
	TestRunner.run("target inside selection range is valid", function()
		assert(CombatRules.canSelectTarget(Vector3.zero, Vector3.new(0, 0, 50), true, 100))
	end)

	TestRunner.run("dead target cannot be selected", function()
		assert(not CombatRules.canSelectTarget(Vector3.zero, Vector3.new(0, 0, 5), false, 100))
	end)

	TestRunner.run("basic attack requires range", function()
		assert(CombatRules.canBasicAttack(Vector3.zero, Vector3.new(0, 0, 10), true, 12))
		assert(not CombatRules.canBasicAttack(Vector3.zero, Vector3.new(0, 0, 13), true, 12))
	end)

end
