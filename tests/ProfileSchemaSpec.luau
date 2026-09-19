--!strict

local ProfileSchema = require(game.ReplicatedStorage.Shared.persistence.ProfileSchema)

return function(TestRunner)
	TestRunner.run("new profile starts at current DataVersion with isolated tables", function()
		local first = ProfileSchema.createDefault()
		local second = ProfileSchema.createDefault()
		assert(first.DataVersion == 1 and first.Level == 1 and first.XP == 0 and first.Luna == 0)
		assert(first.ArchetypeId == "knight")
		first.Inventory[1] = "mutated"
		assert(second.Inventory[1] == nil)
	end)

	TestRunner.run("profile validator accepts one canonical location per item", function()
		local profile = ProfileSchema.createDefault()
		profile.Items["item-a"] = { ItemId = "material_wolf_pelt", Quantity = 2 }
		profile.Inventory[1] = "item-a"
		assert(ProfileSchema.validateCurrent(profile))

		local equipped = ProfileSchema.createDefault()
		equipped.Items["weapon-a"] = { ItemId = "weapon_training_sword", Quantity = 1 }
		equipped.Equipment.Weapon = "weapon-a"
		assert(ProfileSchema.validateCurrent(equipped))
	end)

	TestRunner.run("profile validator rejects dangling duplicate and over-capacity ownership", function()
		local dangling = ProfileSchema.createDefault()
		dangling.Inventory[1] = "missing"
		assert(not ProfileSchema.validateCurrent(dangling))

		local duplicate = ProfileSchema.createDefault()
		duplicate.Items["item-a"] = { ItemId = "weapon_training_sword", Quantity = 1 }
		duplicate.Inventory[1] = "item-a"
		duplicate.Equipment.Weapon = "item-a"
		assert(not ProfileSchema.validateCurrent(duplicate))

		local overflow = ProfileSchema.createDefault()
		for index = 1, 41 do
			local id = "item-" .. tostring(index)
			overflow.Items[id] = { ItemId = "material_wolf_pelt", Quantity = 1 }
			overflow.Inventory[index] = id
		end
		assert(not ProfileSchema.validateCurrent(overflow))
	end)

	TestRunner.run("profile validator rejects corrupt progression currency and equipment", function()
		local invalidXP = ProfileSchema.createDefault()
		invalidXP.XP = 100
		assert(not ProfileSchema.validateCurrent(invalidXP))

		local invalidLuna = ProfileSchema.createDefault()
		invalidLuna.Luna = -1
		assert(not ProfileSchema.validateCurrent(invalidLuna))

		local stackedEquipment = ProfileSchema.createDefault()
		stackedEquipment.Items["item-a"] = { ItemId = "weapon_training_sword", Quantity = 2 }
		stackedEquipment.Equipment.Weapon = "item-a"
		assert(not ProfileSchema.validateCurrent(stackedEquipment))
	end)
end
