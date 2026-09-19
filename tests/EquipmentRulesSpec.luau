--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EquipmentRules = require(ReplicatedStorage.Shared.inventory.EquipmentRules)
local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)

local function ids(): () -> string
	local sequence = 0
	return function()
		sequence += 1
		return "item-" .. tostring(sequence)
	end
end

return function(TestRunner)
	TestRunner.run("equip requires ownership archetype and required level", function()
		local profile = ProfileSchema.createDefault()
		local owned = InventoryRules.add(profile, "weapon_iron_blade", 1, ids())
		assert(owned ~= nil)

		local tooLow, lowReason = EquipmentRules.equip(owned, "item-1", "knight", 3)
		assert(tooLow == nil and lowReason == "LevelTooLow")

		local wrongClass, classReason = EquipmentRules.equip(owned, "item-1", "ranger", 4)
		assert(wrongClass == nil and classReason == "WrongArchetype")

		local equipped, reason = EquipmentRules.equip(owned, "item-1", "knight", 4)
		assert(reason == nil and equipped ~= nil)
		assert(equipped.Equipment.Weapon == "item-1")
		assert(#equipped.Inventory == 0)
	end)

	TestRunner.run("equipping into an occupied slot swaps the old item back to inventory", function()
		local profile = ProfileSchema.createDefault()
		local first = InventoryRules.add(profile, "weapon_training_sword", 1, ids())
		assert(first ~= nil)
		local second = InventoryRules.add(first, "weapon_iron_blade", 1, function() return "item-2" end)
		assert(second ~= nil)
		local equippedFirst = EquipmentRules.equip(second, "item-1", "knight", 4)
		assert(equippedFirst ~= nil)
		local equippedSecond = EquipmentRules.equip(equippedFirst, "item-2", "knight", 4)
		assert(equippedSecond ~= nil)
		assert(equippedSecond.Equipment.Weapon == "item-2")
		assert(#equippedSecond.Inventory == 1 and equippedSecond.Inventory[1] == "item-1")
	end)

	TestRunner.run("unequip returns the item to inventory and respects capacity", function()
		local profile = ProfileSchema.createDefault()
		local owned = InventoryRules.add(profile, "weapon_training_sword", 1, ids())
		assert(owned ~= nil)
		local equipped = EquipmentRules.equip(owned, "item-1", "knight", 1)
		assert(equipped ~= nil)
		local unequipped = EquipmentRules.unequip(equipped, "Weapon")
		assert(unequipped ~= nil and unequipped.Equipment.Weapon == nil)
		assert(unequipped.Inventory[1] == "item-1")
	end)

	TestRunner.run("equip replay cannot duplicate an item", function()
		local profile = ProfileSchema.createDefault()
		local owned = InventoryRules.add(profile, "weapon_training_sword", 1, ids())
		assert(owned ~= nil)
		local equipped = EquipmentRules.equip(owned, "item-1", "knight", 1)
		assert(equipped ~= nil)
		local replay, reason = EquipmentRules.equip(equipped, "item-1", "knight", 1)
		assert(replay == nil and reason == "NotOwned")
	end)
end
