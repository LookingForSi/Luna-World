--!strict

local CooldownRules = require(game.ReplicatedStorage.Shared.combat.CooldownRules)

return function(TestRunner)
	TestRunner.run("cooldown readiness uses injected server time inclusively", function()
		local cooldowns = { basic_attack = 12 }
		assert(not CooldownRules.isReady(cooldowns, "basic_attack", 11.999))
		assert(CooldownRules.isReady(cooldowns, "basic_attack", 12))
	end)

	TestRunner.run("starting a cooldown returns one authoritative deadline", function()
		local previous = { basic_attack = 4 }
		local updated = CooldownRules.start(previous, "basic_attack", 10, 1.5)
		assert(updated.basic_attack == 11.5)
		assert(previous.basic_attack == 4, "pure rules must not mutate caller state")
	end)

	TestRunner.run("cooldown groups remain independent without a global cooldown", function()
		local cooldowns = CooldownRules.start({}, "power_strike", 20, 3)
		assert(not CooldownRules.isReady(cooldowns, "power_strike", 20))
		assert(CooldownRules.isReady(cooldowns, "shield_bash", 20))
		assert(cooldowns.global == nil)
	end)

	TestRunner.run("invalid cooldown durations are rejected", function()
		local ok = pcall(function()
			CooldownRules.start({}, "basic_attack", 10, -1)
		end)
		assert(not ok)
	end)
end
