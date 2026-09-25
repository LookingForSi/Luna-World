--!strict

local Rules = {}

Rules.QuestId = "quest_ancient_approach"
Rules.ObjectiveId = "kill_moonbound_warden"

function Rules.prepareStudioUnlock(quests: any, definition: any): boolean
	if typeof(quests) ~= "table" or typeof(definition) ~= "table" or definition.id ~= Rules.QuestId then
		return false
	end
	local existing = quests[Rules.QuestId]
	if typeof(existing) == "table" and existing.State == "Completed" then
		return false
	end
	local progress = {}
	for _, objective in definition.objectives do
		progress[objective.id] = objective.required
	end
	quests[Rules.QuestId] = {
		State = "ReadyToTurnIn",
		Progress = progress,
	}
	return true
end

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
