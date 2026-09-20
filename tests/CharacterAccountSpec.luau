--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AccountSchema = require(ReplicatedStorage.Shared.persistence.AccountSchema)
local CharacterRules = require(ReplicatedStorage.Shared.characters.CharacterRules)
local MigrationRules = require(ReplicatedStorage.Shared.persistence.MigrationRules)
local NicknameRules = require(ReplicatedStorage.Shared.characters.NicknameRules)
return function(TestRunner)
	TestRunner.run("v2 migration preserves gameplay data in legacy character", function()
		local old = {
			DataVersion = 2,
			Level = 6,
			XP = 44,
			Luna = 77,
			ArchetypeId = "ranger",
			Items = { p = { ItemId = "material_wolf_pelt", Quantity = 3 } },
			Inventory = { "p" },
			Equipment = {},
			Quests = {},
		}
		local account, reason = MigrationRules.run(old)
		assert(account and not reason and account.DataVersion == 3 and #account.CharacterOrder == 1)
		local c = account.Characters[account.CharacterOrder[1]]
		assert(c.Level == 6 and c.XP == 44 and c.Luna == 77 and c.Items.p.Quantity == 3 and c.NeedsIdentity)
		assert(old.DataVersion == 2 and old.CharacterId == nil)
	end)
	TestRunner.run("nickname normalization prevents case duplicates and rejects unsafe input", function()
		assert(NicknameRules.normalize(" LunaFox ") == "lunafox")
		assert(NicknameRules.normalize("Astrafox") == "astrafox")
		assert(NicknameRules.normalize("LookingFor") == "lookingfor")
		assert(NicknameRules.normalize("Luna_Fox") == "luna_fox")
		assert(NicknameRules.normalize("a b") == nil)
		assert(NicknameRules.normalize("--bad") == nil)
		assert(NicknameRules.normalize("bad_") == nil)
	end)
	TestRunner.run("Studio creation validation can bypass live nickname syntax only", function()
		local payload = { nickname = "Любое имя ✦", archetypeId = "ranger", bodyType = "female", appearancePresetId = "default" }
		assert(CharacterRules.validateCreation(payload, true))
		assert(not CharacterRules.validateCreation(payload, false))
		payload.archetypeId = "invalid"
		assert(not CharacterRules.validateCreation(payload, true), "Studio stub must not bypass class/body validation")
	end)
	TestRunner.run("slot limit is configurable and enforced", function()
		assert(CharacterRules.hasCapacity(4, 5))
		assert(not CharacterRules.hasCapacity(5, 5))
	end)
	TestRunner.run("account schema keeps independent character state", function()
		local a = AccountSchema.createDefault()
		assert(a.Characters ~= nil and a.CharacterOrder ~= nil)
		assert(AccountSchema.validateCurrent(a))
	end)
end
