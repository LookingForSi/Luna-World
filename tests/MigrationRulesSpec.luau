--!strict

local MigrationRules = require(game.ReplicatedStorage.Shared.persistence.MigrationRules)

return function(TestRunner)
	TestRunner.run("synthetic version zero migrates to current profile without mutating input", function()
		local old = {
			DataVersion = 0,
			Level = 2,
			SessionXP = 25,
			Luna = 7,
			ArchetypeId = "ranger",
		}
		local migrated, reason = MigrationRules.run(old)
		assert(reason == nil and migrated ~= nil)
		assert(migrated.DataVersion == 1)
		assert(migrated.Level == 2 and migrated.XP == 25 and migrated.Luna == 7)
		assert(migrated.ArchetypeId == "ranger")
		assert(old.DataVersion == 0 and old.SessionXP == 25)
	end)

	TestRunner.run("current profile round trip is accepted", function()
		local current = {
			DataVersion = 1,
			Level = 1,
			XP = 0,
			Luna = 0,
			ArchetypeId = "knight",
			Items = {},
			Inventory = {},
			Equipment = {},
		}
		local migrated, reason = MigrationRules.run(current)
		assert(reason == nil and migrated ~= nil and migrated.DataVersion == 1)
	end)

	TestRunner.run("future invalid and broken migration profiles fail safely", function()
		assert(MigrationRules.run({ DataVersion = 2 }) == nil)
		assert(MigrationRules.run({ DataVersion = "one" }) == nil)

		local result = MigrationRules.run({ DataVersion = 0 }, {
			[0] = function(profile)
				profile.DataVersion = 0
				return profile
			end,
		})
		assert(result == nil)
	end)
end
