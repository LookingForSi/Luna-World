--!strict

local LootRules = require(game.ReplicatedStorage.Shared.loot.LootRules)

local function constant(value: number): () -> number
	return function() return value end
end

return function(TestRunner)
	TestRunner.run("loot rules grant independent entries deterministically", function()
		local result = LootRules.roll({
			id = "test",
			lunaMin = 3,
			lunaMax = 3,
			entries = {
				{ itemId = "a", chance = 0.5, minQuantity = 1, maxQuantity = 1 },
				{ itemId = "b", chance = 1, minQuantity = 2, maxQuantity = 2 },
			},
		}, constant(0))
		assert(result.luna == 3)
		assert(#result.items == 2)
		assert(result.items[1].itemId == "a" and result.items[1].quantity == 1)
		assert(result.items[2].itemId == "b" and result.items[2].quantity == 2)
	end)

	TestRunner.run("loot rules can produce no optional item drops", function()
		local result = LootRules.roll({
			id = "test",
			lunaMin = 0,
			lunaMax = 0,
			entries = {
				{ itemId = "a", chance = 0.5, minQuantity = 1, maxQuantity = 1 },
			},
		}, constant(0.9))
		assert(result.luna == 0)
		assert(#result.items == 0)
	end)

	TestRunner.run("loot rules reject invalid random sources", function()
		local ok = pcall(function()
			LootRules.roll({
				id = "test",
				lunaMin = 1,
				lunaMax = 2,
				entries = {},
			}, constant(1))
		end)
		assert(not ok)
	end)
end
