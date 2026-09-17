--!strict

local DamageRules = require(game.ReplicatedStorage.Shared.combat.DamageRules)

return function(TestRunner)
	TestRunner.run("configured attack power and effect magnitude determine base amount", function()
		assert(DamageRules.getBaseAmount(25, 1) == 25)
		assert(DamageRules.getBaseAmount(20, 1.5) == 30)
	end)

	TestRunner.run("attack speed changes only a bounded basic attack interval", function()
		assert(DamageRules.getBasicAttackInterval(1.2, 2, 0.5, 2) == 0.6)
		assert(DamageRules.getBasicAttackInterval(1.2, 99, 0.5, 2) == 0.6)
		assert(DamageRules.getBasicAttackInterval(1.2, 0.01, 0.5, 2) == 2.4)
	end)

	TestRunner.run("eligible direct damage rolls critical exactly once", function()
		local rollCount = 0
		local result = DamageRules.resolve(40, "DirectDamage", true, 0.25, 1.5, function()
			rollCount += 1
			return 0.2
		end)
		assert(rollCount == 1)
		assert(result.isCritical)
		assert(result.amount == 60)
	end)

	TestRunner.run("noncritical direct damage still samples once", function()
		local rollCount = 0
		local result = DamageRules.resolve(40, "DirectDamage", true, 0.25, 1.5, function()
			rollCount += 1
			return 0.25
		end)
		assert(rollCount == 1)
		assert(not result.isCritical and result.amount == 40)
	end)

	TestRunner.run("healing and control never roll critical", function()
		local rollCount = 0
		local function roll(): number
			rollCount += 1
			return 0
		end
		assert(not DamageRules.resolve(30, "DirectHealing", true, 1, 2, roll).isCritical)
		assert(not DamageRules.resolve(30, "MovementSlow", true, 1, 2, roll).isCritical)
		assert(not DamageRules.resolve(30, "DirectDamage", false, 1, 2, roll).isCritical)
		assert(rollCount == 0)
	end)

	TestRunner.run("damage calculations reject nonfinite inputs and rolls", function()
		assert(not pcall(function() DamageRules.getBaseAmount(math.huge, 1) end))
		assert(not pcall(function() DamageRules.getBasicAttackInterval(1, 0 / 0, 0.5, 2) end))
		assert(not pcall(function()
			DamageRules.resolve(10, "DirectDamage", true, 0.5, 1.5, function() return math.huge end)
		end))
	end)
end
