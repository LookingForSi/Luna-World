--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local QuestRules = require(ReplicatedStorage.Shared.quests.QuestRules)
return function(TestRunner: any)
	TestRunner.run("Selene entrance stays locked before Moonbound Warden death", function()
		assert(not Rules.isUnlocked({}))
		assert(not Rules.isUnlocked({ quest_ancient_approach={State="Active",Progress={kill_moonbound_warden=0}} }))
	end)
	TestRunner.run("Selene entrance unlock is persistent and idempotent", function()
		assert(Rules.isUnlocked({ quest_ancient_approach={State="Active",Progress={kill_moonbound_warden=1}} }))
		assert(Rules.isUnlocked({ quest_ancient_approach={State="ReadyToTurnIn",Progress={}} }))
		assert(Rules.isUnlocked({ quest_ancient_approach={State="Completed",Progress={}} }))
	end)
	TestRunner.run("Production Warden credit requires an active Ancient Approach quest", function()
		local absent = { Quests = {} }
		QuestRules.credit(absent, "KillMob", "mob_moonbound_warden")
		assert(not Rules.isUnlocked(absent.Quests))

		local active = { Quests = { [Rules.QuestId] = { State="Active", Progress={} } } }
		QuestRules.credit(active, "KillMob", "mob_moonbound_warden")
		assert(Rules.isUnlocked(active.Quests))
	end)
	TestRunner.run("Studio unlock prepares a schema-valid ready quest from definitions", function()
		local definition = require(ReplicatedStorage.Shared.definitions.QuestDefinitions)[Rules.QuestId]
		local quests = {}
		assert(Rules.prepareStudioUnlock(quests, definition))
		local record = quests[Rules.QuestId]
		assert(record.State == "ReadyToTurnIn")
		for _, objective in definition.objectives do
			assert(record.Progress[objective.id] == objective.required)
		end
		assert(Rules.isUnlocked(quests))
		local completed = { [Rules.QuestId] = { State="Completed", Progress=record.Progress } }
		assert(not Rules.prepareStudioUnlock(completed, definition))
		assert(completed[Rules.QuestId].State == "Completed")
	end)
end
