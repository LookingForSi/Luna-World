--!strict

local RemoteRequestRules = require(game.ReplicatedStorage.Shared.combat.RemoteRequestRules)
local ActionRules = require(game.ReplicatedStorage.Shared.combat.ActionRules)
local AutoAttackRules = require(game.ReplicatedStorage.Shared.combat.AutoAttackRules)
local SkillRules = require(game.ReplicatedStorage.Shared.combat.SkillRules)
local ResourceRules = require(game.ReplicatedStorage.Shared.combat.ResourceRules)
local CombatConfig = require(game.ReplicatedStorage.Shared.config.CombatConfig)

return function(TestRunner)
	TestRunner.run("combat remotes reject malformed and forged payload shapes", function()
		local forged = { damage = 999999, healing = 999999, critical = true, resource = 999999, time = 0, areaTargets = { "wolf-1" } }
		assert(RemoteRequestRules.validateTargetRequest(0, nil) == nil)
		assert(RemoteRequestRules.validateTargetRequest(2, "wolf-1") == nil)
		assert(RemoteRequestRules.validateTargetRequest(1, forged) == nil)
		assert(RemoteRequestRules.validateTargetRequest(1, string.rep("x", 129)) == nil)

		assert(not RemoteRequestRules.validateAttackRequest(1), "legacy boolean attack must be rejected")
		assert(not RemoteRequestRules.validateAttackRequest(7), "forged combat results must be rejected")
		assert(RemoteRequestRules.validateAttackRequest(0))

		assert(RemoteRequestRules.validateAutoAttackRequest(0, nil) == nil)
		assert(RemoteRequestRules.validateAutoAttackRequest(1, "true") == nil)
		assert(RemoteRequestRules.validateAutoAttackRequest(2, true) == nil)
		assert(RemoteRequestRules.validateAutoAttackRequest(1, true) == true)

		assert(RemoteRequestRules.validateSkillRequest(0, nil) == nil)
		assert(RemoteRequestRules.validateSkillRequest(1, forged) == nil)
		assert(RemoteRequestRules.validateSkillRequest(2, "flame_burst") == nil)
		assert(RemoteRequestRules.validateSkillRequest(1, string.rep("x", 129)) == nil)
		assert(RemoteRequestRules.validateSkillRequest(1, "heal") == "heal")
	end)

	TestRunner.run("hostile payload validators are total and insufficient resources cannot be forged", function()
		local requests = {
			function() return RemoteRequestRules.validateAttackRequest(1) end,
			function() return RemoteRequestRules.validateAutoAttackRequest(2, true) end,
			function() return RemoteRequestRules.validateSkillRequest(6, "flame_burst") end,
			function() return RemoteRequestRules.validateTargetRequest(1, {}) end,
		}
		for _, request in requests do
			local ok, accepted = pcall(request)
			assert(ok and not accepted, "hostile request validation must be total and rejecting")
		end
		local resource = ResourceRules.create("Mana", 10)
		assert(ResourceRules.spend(resource, "Mana", 25) == nil, "server resource must gate skill acceptance")
		assert(resource.current == 10 and resource.maximum == 10, "failed spending must not mutate the snapshot")
		assert(not SkillRules.canAccept("Ready", true, false, true))
	end)

	TestRunner.run("authoritative eligibility rejects stale dead ranged facing and spam cases", function()
		assert(not SkillRules.isEnemyTargetValid("wolf-1", "wolf-2", true, true, true, true), "stale id")
		assert(not SkillRules.isEnemyTargetValid("wolf-1", "wolf-1", true, false, true, true), "dead or removed target")
		assert(not SkillRules.isEnemyTargetValid("wolf-1", "wolf-1", true, true, false, true), "range")
		assert(not SkillRules.isEnemyTargetValid("wolf-1", "wolf-1", true, true, true, false), "facing")
		assert(ActionRules.isRequestRateLimited(10.01, 10, 0.03), "spam")
		assert(ActionRules.isRequestRateLimited(10.01, 10, CombatConfig.TargetRequestMinIntervalSeconds), "target spam")
		assert(not AutoAttackRules.validateRequest(1, true, true, false).accepted, "AUTO requires a living mob target")
		assert(SkillRules.resolveFriendlyTarget(true, true, true, false, true) == "Self", "out-of-range Heal must not affect the selected player")
		assert(not SkillRules.isTargetContextAllowed("Friendly", "Mob", false), "hostile Heal target")
	end)
end
