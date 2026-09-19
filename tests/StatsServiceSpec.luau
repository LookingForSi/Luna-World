--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local StatsService = require(ServerScriptService.Server.services.StatsService)

return function(TestRunner)
	TestRunner.run("equipped item modifiers aggregate exactly once", function()
		local profile = ProfileSchema.createDefault()
		profile.Items["weapon"] = { ItemId = "weapon_iron_blade", Quantity = 1 }
		profile.Equipment.Weapon = "weapon"
		profile.Items["chest"] = { ItemId = "armor_guard_chest", Quantity = 1 }
		profile.Equipment.Chest = "chest"

		local modifiers = StatsService.aggregateEquipmentModifiers(profile)
		assert(modifiers.physicalAttack == 5)
		assert(modifiers.physicalDefense == 8)
		assert(modifiers.maxHealth == 18)
	end)

	TestRunner.run("empty equipment contributes no derived modifiers", function()
		local profile = ProfileSchema.createDefault()
		local modifiers = StatsService.aggregateEquipmentModifiers(profile)
		assert(modifiers.maxHealth == nil)
		assert(modifiers.physicalAttack == nil)
		assert(modifiers.magicAttack == nil)
	end)
end
