--!strict

local Rules = require(game.ReplicatedStorage.Shared.inventory.InventoryRequestRules)

return function(TestRunner)
	TestRunner.run("inventory actions accept only the approved exact two argument shape", function()
		local action, identifier = Rules.validateAction(2, "Equip", "item-1")
		assert(action == "Equip" and identifier == "item-1")
		assert(Rules.validateAction(1, "Equip", "item-1") == nil)
		assert(Rules.validateAction(3, "Equip", "item-1") == nil)
		assert(Rules.validateAction(2, "GrantItem", "item-1") == nil)
		assert(Rules.validateAction(2, "Equip", "") == nil)
		assert(Rules.validateAction(2, "Equip", string.rep("x", 129)) == nil)
	end)

	TestRunner.run("inventory snapshot request has no client payload", function()
		assert(Rules.validateSnapshotRequest(0))
		assert(not Rules.validateSnapshotRequest(1))
	end)
end
