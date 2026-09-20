--!strict
local MigrationRules = require(game.ReplicatedStorage.Shared.persistence.MigrationRules)
return function(TestRunner)
	TestRunner.run("version zero migrates sequentially without mutating input", function()
		local old = { DataVersion = 0, Level = 2, SessionXP = 25, Luna = 7, ArchetypeId = "ranger" }
		local a, e = MigrationRules.run(old)
		assert(a and not e and a.DataVersion == 3)
		local c = a.Characters[a.CharacterOrder[1]]
		assert(c.Level == 2 and c.XP == 25 and c.Luna == 7 and c.ArchetypeId == "ranger")
		assert(old.DataVersion == 0)
	end)
	TestRunner.run("current account round trip is accepted", function()
		local current = {
			DataVersion = 3,
			CharacterSlotLimit = 5,
			CharacterOrder = {},
			Characters = {},
			SelectedCharacterId = nil,
			Settings = { UiScale = 1, TextScale = 1, SoundVolume = 1 },
		}
		local a, e = MigrationRules.run(current)
		assert(a and not e and a.DataVersion == 3)
	end)
	TestRunner.run("future invalid and broken migrations fail safely", function()
		assert(MigrationRules.run({ DataVersion = 4 }) == nil)
		assert(MigrationRules.run({ DataVersion = "one" }) == nil)
		assert(MigrationRules.run({ DataVersion = 0 }, {
			[0] = function(p)
				p.DataVersion = 0
				return p
			end,
		}) == nil)
	end)
end
