--!strict

local ResourceRules = require(game.ReplicatedStorage.Shared.combat.ResourceRules)
local CooldownRules = require(game.ReplicatedStorage.Shared.combat.CooldownRules)

return function(TestRunner)
	TestRunner.run("class resources are not interchangeable", function()
		local stamina = { resourceType = "Stamina" :: "Stamina", current = 30, maximum = 100 }
		assert(ResourceRules.canSpend(stamina, "Stamina", 20))
		assert(not ResourceRules.canSpend(stamina, "Focus", 20))
		assert(not ResourceRules.canSpend(stamina, "Mana", 20))
	end)

	TestRunner.run("basic attacks are free and insufficient skill resources reject before acceptance", function()
		local focus = { resourceType = "Focus" :: "Focus", current = 10, maximum = 100 }
		local freeResult = ResourceRules.spend(focus, "Focus", 0)
		assert(freeResult ~= nil and freeResult.current == 10)
		assert(ResourceRules.spend(focus, "Focus", 11) == nil)
		assert(focus.current == 10, "a rejected action must not mutate authoritative resource")
	end)

	TestRunner.run("accepted costs are charged once and are not implicitly refunded", function()
		local mana = { resourceType = "Mana" :: "Mana", current = 50, maximum = 100 }
		local accepted = ResourceRules.spend(mana, "Mana", 25)
		assert(accepted ~= nil and accepted.current == 25)
		local cooldowns = CooldownRules.start({}, "heal", 10, 5)
		-- Resolve failure or interruption keeps the snapshot committed at acceptance.
		assert(accepted.current == 25)
		assert(not CooldownRules.isReady(cooldowns, "heal", 14.99))
		assert(mana.current == 50, "pure resource rules must not mutate their input")
	end)

	TestRunner.run("resource restoration and regeneration stop at maximum", function()
		local stamina = { resourceType = "Stamina" :: "Stamina", current = 90, maximum = 100 }
		assert(ResourceRules.restore(stamina, 15).current == 100)
		assert(ResourceRules.regenerate(stamina, 8, 2).current == 100)
	end)

	TestRunner.run("regeneration preserves fractional heartbeat time deterministically", function()
		local mana = { resourceType = "Mana" :: "Mana", current = 50, maximum = 100 }
		local afterFirst, firstRemainder = ResourceRules.stepRegeneration(mana, 4, 0, 0.1, 0.25, true)
		assert(afterFirst.current == 50 and firstRemainder == 0.1)
		local afterSecond, secondRemainder = ResourceRules.stepRegeneration(afterFirst, 4, firstRemainder, 0.2, 0.25, true)
		assert(afterSecond.current == 51)
		assert(math.abs(secondRemainder - 0.05) < 0.000001)
	end)

	TestRunner.run("new full snapshots begin with no inherited regeneration time", function()
		local full = ResourceRules.create("Stamina", 100)
		local unchanged, remainder = ResourceRules.stepRegeneration(full, 5, 0, 0.1, 0.25, true)
		assert(unchanged.current == 100 and remainder == 0.1)
		-- Removing a player discards both values; a replacement snapshot starts from zero explicitly.
		local recreatedSnapshot = ResourceRules.create("Stamina", 100)
		local inactive, inactiveRemainder = ResourceRules.stepRegeneration(
			{ resourceType = "Stamina", current = 50, maximum = 100 },
			5,
			0.2,
			1,
			0.25,
			false
		)
		assert(inactive.current == 50 and inactiveRemainder == 0, "dead or removed actors must not regenerate")
		local recreated, recreatedRemainder = ResourceRules.stepRegeneration(recreatedSnapshot, 5, 0, 0, 0.25, true)
		assert(recreated.current == 100 and recreatedRemainder == 0)
	end)

	TestRunner.run("invalid resource snapshots and nonfinite inputs are rejected", function()
		for _, resource in {
			{ resourceType = "Mana" :: "Mana", current = -1, maximum = 100 },
			{ resourceType = "Mana" :: "Mana", current = 101, maximum = 100 },
			{ resourceType = "Mana" :: "Mana", current = 0, maximum = math.huge },
		} do
			assert(not pcall(function() ResourceRules.restore(resource, 1) end))
		end
		local valid = { resourceType = "Focus" :: "Focus", current = 10, maximum = 100 }
		assert(not pcall(function() ResourceRules.spend(valid, "Focus", math.huge) end))
		assert(not pcall(function() ResourceRules.regenerate(valid, 1, 0 / 0) end))
	end)
end
