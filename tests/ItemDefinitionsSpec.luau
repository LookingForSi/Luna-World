--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)

return function(TestRunner)
	TestRunner.run("v0.1 content exposes the stable item catalog", function()
		local count = 0
		local seen = {}
		for key, definition in ItemDefinitions do
			count += 1
			assert(key == definition.id)
			assert(not seen[definition.id])
			seen[definition.id] = true
			assert(definition.displayName ~= "")
			assert(definition.maxStack >= 1)
			if definition.stackable then
				assert(definition.equipmentSlot == nil)
			else
				assert(definition.maxStack == 1)
			end
		end
		assert(count == 35)
	end)

	TestRunner.run("weapons keep archetype ownership and approved level tiers", function()
		assert(ItemDefinitions.weapon_training_sword.requiredLevel == 1)
		assert(ItemDefinitions.weapon_iron_blade.requiredLevel == 4)
		assert(ItemDefinitions.weapon_moonsteel_sword.requiredLevel == 7)
		assert(ItemDefinitions.weapon_training_sword.allowedArchetypes[1] == "knight")
		assert(ItemDefinitions.weapon_ash_bow.allowedArchetypes[1] == "ranger")
		assert(ItemDefinitions.weapon_ash_staff.allowedArchetypes[1] == "mystic")
	end)

	TestRunner.run("mob content materials, consumables and reserved epic are represented by data", function()
		for _, itemId in {
			"material_venom_sac",
			"material_goblin_token",
			"material_dire_hide",
			"material_bone_fragment",
			"material_fallen_relic",
			"material_ancient_shard",
		} do
			assert(ItemDefinitions[itemId] ~= nil, "missing mob content material " .. itemId)
		end
		assert(ItemDefinitions.consumable_minor_healing_draught.consumableEffect.kind == "HealHP")
		assert(ItemDefinitions.consumable_minor_resource_draught.consumableEffect.kind == "RestoreResource")
		assert(ItemDefinitions.accessory_lunar_sigil.rarity == "Epic")
		assert(ItemDefinitions.accessory_lunar_sigil.requiredLevel == 10)
	end)
end
