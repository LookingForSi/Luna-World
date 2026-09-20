--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local EquipmentRules = require(ReplicatedStorage.Shared.inventory.EquipmentRules)
local InMemoryProfileStore = require(script.Parent.support.InMemoryProfileStore)
local function addCharacter(account: any): any
	local c: any = ProfileSchema.createDefault()
	c.CharacterId = "hero"
	c.Nickname = "RoundTrip"
	c.BodyType = "male"
	c.AppearancePresetId = "default"
	c.CreatedAt = 1
	c.LastPlayedAt = 1
	c.NeedsIdentity = false
	account.Characters.hero = c
	table.insert(account.CharacterOrder, "hero")
	return c
end
return function(TestRunner)
	TestRunner.run("account round trip preserves independent character gameplay state", function()
		local store = InMemoryProfileStore.new()
		local claimed = store:claim(501, "a", 0)
		assert(claimed.ok)
		if not claimed.ok then
			return
		end
		local c = addCharacter(claimed.profile)
		c.Level = 4
		c.XP = 125
		c.Luna = 73
		local seq = 0
		local withWeapon = InventoryRules.add(c, "weapon_iron_blade", 1, function()
			seq += 1
			return "i" .. seq
		end)
		assert(withWeapon)
		claimed.profile.Characters.hero = withWeapon
		local equipped = EquipmentRules.equip(withWeapon, "i1", "knight", 4)
		assert(equipped)
		claimed.profile.Characters.hero = equipped
		assert(store:release(501, "a", claimed.profile, 1).ok)
		local loaded = store:claim(501, "b", 2)
		assert(loaded.ok)
		if not loaded.ok then
			return
		end
		local restored = loaded.profile.Characters.hero
		assert(restored.Level == 4 and restored.XP == 125 and restored.Luna == 73 and restored.Equipment.Weapon == "i1")
	end)
	TestRunner.run("stale account owner cannot overwrite newer owner", function()
		local store = InMemoryProfileStore.new()
		local a = store:claim(502, "a", 0)
		assert(a.ok)
		if not a.ok then
			return
		end
		assert(store:release(502, "a", a.profile, 1).ok)
		local b = store:claim(502, "b", 2)
		assert(b.ok)
		local stale = store:save(502, "a", a.profile, 3)
		assert(not stale.ok and stale.reason == "Conflict")
	end)
end
