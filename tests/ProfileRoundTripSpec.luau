--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local EquipmentRules = require(ReplicatedStorage.Shared.inventory.EquipmentRules)
local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local StatsService = require(ServerScriptService.Server.services.StatsService)
local InMemoryProfileStore = require(script.Parent.support.InMemoryProfileStore)

local function ids(): () -> string
	local sequence = 0
	return function()
		sequence += 1
		return "roundtrip-" .. tostring(sequence)
	end
end

return function(TestRunner)
	TestRunner.run("profile round trip preserves progression currency inventory and equipment", function()
		local store = InMemoryProfileStore.new()
		local claimed = store:claim(501, "session-a", 0)
		assert(claimed.ok)
		if not claimed.ok then return end

		local profile = claimed.profile
		profile.Level = 4
		profile.XP = 125
		profile.Luna = 73

		local withWeapon = InventoryRules.add(profile, "weapon_iron_blade", 1, ids())
		assert(withWeapon ~= nil)
		local withPelts = InventoryRules.add(withWeapon, "material_wolf_pelt", 7, function()
			return "roundtrip-2"
		end)
		assert(withPelts ~= nil)
		local equipped = EquipmentRules.equip(withPelts, "roundtrip-1", "knight", 4)
		assert(equipped ~= nil)

		assert(store:save(501, "session-a", equipped, 1).ok)
		assert(store:release(501, "session-a", equipped, 2).ok)

		local reloaded = store:claim(501, "session-b", 3)
		assert(reloaded.ok)
		if not reloaded.ok then return end
		assert(reloaded.profile.Level == 4)
		assert(reloaded.profile.XP == 125)
		assert(reloaded.profile.Luna == 73)
		assert(reloaded.profile.Equipment.Weapon == "roundtrip-1")
		assert(reloaded.profile.Items["roundtrip-1"].ItemId == "weapon_iron_blade")
		assert(reloaded.profile.Items["roundtrip-2"].Quantity == 7)

		local modifiers = StatsService.aggregateEquipmentModifiers(reloaded.profile)
		assert(modifiers.physicalAttack == 5)
	end)

	TestRunner.run("failed stale-session save cannot overwrite a newer profile owner", function()
		local store = InMemoryProfileStore.new()
		local first = store:claim(502, "session-a", 0)
		assert(first.ok)
		if not first.ok then return end
		first.profile.Luna = 10
		assert(store:release(502, "session-a", first.profile, 1).ok)

		local second = store:claim(502, "session-b", 2)
		assert(second.ok)
		if not second.ok then return end
		second.profile.Luna = 20
		assert(store:save(502, "session-b", second.profile, 3).ok)

		first.profile.Luna = 999
		local stale = store:save(502, "session-a", first.profile, 4)
		assert(not stale.ok and stale.reason == "Conflict")

		assert(store:release(502, "session-b", second.profile, 5).ok)
		local final = store:claim(502, "session-c", 6)
		assert(final.ok)
		if not final.ok then return end
		assert(final.profile.Luna == 20)
	end)
end
