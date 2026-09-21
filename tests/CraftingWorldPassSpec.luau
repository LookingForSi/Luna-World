--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CraftingDefinitions = require(ReplicatedStorage.Shared.definitions.CraftingDefinitions)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local MerchantDefinitions = require(ReplicatedStorage.Shared.definitions.MerchantDefinitions)

return function(TestRunner)
	TestRunner.run("crafting pass exposes four complete disciplines", function()
		local counts = { Knight = 0, Ranger = 0, Mystic = 0, Material = 0 }
		local slots = { Knight = {}, Ranger = {}, Mystic = {} }
		local seen = {}
		for key, recipe in CraftingDefinitions do
			assert(key == recipe.id and not seen[recipe.id]); seen[recipe.id] = true
			assert(counts[recipe.discipline] ~= nil)
			counts[recipe.discipline] += 1
			assert(recipe.requiredLevel >= 1 and recipe.requiredLevel % 1 == 0)
			assert(recipe.outputQuantity >= 1 and recipe.outputQuantity % 1 == 0)
			assert(ItemDefinitions[recipe.outputItemId] ~= nil)
			local output = ItemDefinitions[recipe.outputItemId]
			assert(output.category == "Material" or output.grade == "NoGrade")
			if recipe.discipline ~= "Material" and output.equipmentSlot ~= nil then
				slots[recipe.discipline][output.equipmentSlot] = true
				if output.equipmentSlot ~= "Accessory" then
					local expected = if recipe.discipline == "Knight" then "knight" else if recipe.discipline == "Ranger" then "ranger" else "mystic"
					assert(output.allowedArchetypes ~= nil and #output.allowedArchetypes == 1 and output.allowedArchetypes[1] == expected, recipe.id .. " class ownership")
				end
			end
			for _, ingredient in recipe.ingredients do assert(ItemDefinitions[ingredient.itemId] ~= nil) end
		end
		assert(counts.Knight >= 5 and counts.Ranger >= 5 and counts.Mystic >= 5 and counts.Material == 4)
		for _, discipline in { "Knight", "Ranger", "Mystic" } do
			for _, slot in { "Weapon", "Head", "Chest", "Gloves", "Boots" } do assert(slots[discipline][slot], discipline .. " lacks " .. slot) end
		end
	end)

	TestRunner.run("early gear avoids late-zone materials", function()
		local late = { material_fallen_relic = true, material_ancient_shard = true, material_dire_hide = true }
		for _, recipe in CraftingDefinitions do
			if recipe.discipline ~= "Material" and recipe.requiredLevel <= 6 then
				for _, ingredient in recipe.ingredients do assert(not late[ingredient.itemId], recipe.id) end
			end
		end
	end)

	TestRunner.run("merchant stock excludes processed materials and class sets", function()
		local forbidden = {}
		for _, recipe in CraftingDefinitions do forbidden[recipe.outputItemId] = true end
		for _, itemId in MerchantDefinitions.Stock do assert(not forbidden[itemId], itemId .. " must be crafted") end
	end)
end
