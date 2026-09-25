--!strict

local Rules = {}

Rules.QuestId = "quest_ancient_approach"
Rules.ObjectiveId = "kill_moonbound_warden"

function Rules.isUnlocked(quests: any): boolean
	if typeof(quests) ~= "table" then return false end
	local record = quests[Rules.QuestId]
	if typeof(record) ~= "table" then return false end
	if record.State == "ReadyToTurnIn" or record.State == "Completed" then return true end
	return record.State == "Active"
		and typeof(record.Progress) == "table"
		and (record.Progress[Rules.ObjectiveId] or 0) >= 1
end

return table.freeze(Rules)
