--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)

local function generator(prefix: string): () -> string
	local sequence = 0
	return function()
		sequence += 1
		return prefix .. tostring(sequence)
	end
end

return function(TestRunner)
	TestRunner.run("stackable grants fill existing stacks before consuming slots", function()
		local profile = ProfileSchema.createDefault()
		local first = InventoryRules.add(profile, "material_wolf_pelt", 90, generator("a"))
		assert(first ~= nil and #first.Inventory == 1)
		local second = InventoryRules.add(first, "material_wolf_pelt", 20, generator("b"))
		assert(second ~= nil and #second.Inventory == 2)
		assert(second.Items["a1"].Quantity == 99)
		assert(second.Items["b1"].Quantity == 11)
	end)

	TestRunner.run("nonstackable duplicates always receive distinct instance ids", function()
		local profile = ProfileSchema.createDefault()
		local nextProfile = InventoryRules.add(profile, "weapon_training_sword", 2, generator("weapon-"))
		assert(nextProfile ~= nil)
		assert(#nextProfile.Inventory == 2)
		assert(nextProfile.Inventory[1] ~= nextProfile.Inventory[2])
	end)

	TestRunner.run("inventory full rejects the entire grant transaction", function()
		local profile = ProfileSchema.createDefault()
		for index = 1, 40 do
			local id = "full-" .. tostring(index)
			profile.Items[id] = { ItemId = "weapon_training_sword", Quantity = 1 }
			profile.Inventory[index] = id
		end
		local result, reason = InventoryRules.add(profile, "material_wolf_pelt", 1, generator("new-"))
		assert(result == nil and reason == "InventoryFull")
		assert(#profile.Inventory == 40 and profile.Items["new-1"] == nil)
	end)

	TestRunner.run("foreign and equipped instances cannot be discarded from inventory", function()
		local profile = ProfileSchema.createDefault()
		local missing, missingReason = InventoryRules.discard(profile, "foreign")
		assert(missing == nil and missingReason == "NotOwned")

		profile.Items["equipped"] = { ItemId = "weapon_training_sword", Quantity = 1 }
		profile.Equipment.Weapon = "equipped"
		local equipped, equippedReason = InventoryRules.discard(profile, "equipped")
		assert(equipped == nil and equippedReason == "EquippedItem")
	end)

	TestRunner.run("discard decrements stack or removes its canonical instance", function()
		local profile = ProfileSchema.createDefault()
		local withStack = InventoryRules.add(profile, "material_wolf_pelt", 5, generator("stack-"))
		assert(withStack ~= nil)
		local reduced = InventoryRules.discard(withStack, "stack-1", 2)
		assert(reduced ~= nil and reduced.Items["stack-1"].Quantity == 3)
		local removed = InventoryRules.discard(reduced, "stack-1")
		assert(removed ~= nil and removed.Items["stack-1"] == nil and #removed.Inventory == 0)
	end)
end
