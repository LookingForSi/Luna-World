--!strict

local RespawnRules = require(game.ReplicatedStorage.Shared.combat.RespawnRules)

return function(TestRunner)
	TestRunner.run("death is accepted exactly once per pending lifecycle", function()
		local accepted, generation = RespawnRules.beginDeath(false, 3)
		assert(accepted and generation == 4)
		local duplicateAccepted, duplicateGeneration = RespawnRules.beginDeath(true, generation)
		assert(not duplicateAccepted and duplicateGeneration == generation)
	end)

	TestRunner.run("nearest registered settlement anchor is deterministic", function()
		local anchors = {
			{ id = "far", settlementId = "luna_village", position = Vector3.new(50, 0, 0) },
			{ id = "near", settlementId = "luna_village", position = Vector3.new(4, 0, 0) },
		}
		assert(RespawnRules.nearestAnchorId(Vector3.zero, anchors) == "near")
		assert(RespawnRules.nearestAnchorId(Vector3.zero, {}) == nil)
	end)

	TestRunner.run("authoritative override wins over a nearer settlement anchor", function()
		local anchors = {
			{ id = "luna", settlementId = "luna_village", position = Vector3.zero },
			{ id = "checkpoint", settlementId = "dungeon_selene", position = Vector3.new(0, 500, -12000) },
		}
		assert(RespawnRules.selectAnchorId("checkpoint", Vector3.zero, anchors) == "checkpoint")
		assert(RespawnRules.selectAnchorId(nil, Vector3.zero, anchors) == "luna")
	end)

	TestRunner.run("stale respawn generations cannot affect a newer character", function()
		assert(RespawnRules.isCurrentGeneration(5, 5))
		assert(not RespawnRules.isCurrentGeneration(4, 5))
	end)

	TestRunner.run("anchor pivot keeps the character above the registered point", function()
		local anchor = CFrame.new(10, 5, -3)
		assert(RespawnRules.spawnCFrame(anchor, 2, 2).Position == Vector3.new(10, 8, -3))
	end)
	TestRunner.run("manual respawn accepts exactly one pending request with an anchor", function()
		assert(RespawnRules.canRequestRespawn(true, false, true))
		assert(not RespawnRules.canRequestRespawn(false, false, true))
		assert(not RespawnRules.canRequestRespawn(true, true, true))
		assert(not RespawnRules.canRequestRespawn(true, false, false))
	end)

end
