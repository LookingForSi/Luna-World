--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
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
end
