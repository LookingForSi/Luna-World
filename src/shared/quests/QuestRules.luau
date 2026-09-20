--!strict
local QuestDefinitions = require(script.Parent.Parent.definitions.QuestDefinitions)
local ProgressionRules = require(script.Parent.Parent.progression.ProgressionRules)

local QuestRules = {}

local function complete(record: any, definition: any): boolean
	for _, objective in definition.objectives do
		if (record.Progress[objective.id] or 0) < objective.required then return false end
	end
	return true
end

function QuestRules.isAvailable(quests: any, questId: string): boolean
	local definition = QuestDefinitions[questId]
	if definition == nil or quests[questId] ~= nil then return false end
	for _, prerequisiteId in definition.prerequisiteQuestIds do
		local prerequisite = quests[prerequisiteId]
		if prerequisite == nil or prerequisite.State ~= "Completed" then return false end
	end
	return true
end

function QuestRules.accept(profile: any, questId: string, npcId: string): (boolean, string?)
	local definition = QuestDefinitions[questId]
	if definition == nil then return false, "UnknownQuest" end
	if definition.giverNpcId ~= npcId then return false, "WrongNpc" end
	if not QuestRules.isAvailable(profile.Quests, questId) then return false, "Unavailable" end
	profile.Quests[questId] = { State = "Active", Progress = {} }
	return true, nil
end

function QuestRules.credit(profile: any, kind: string, targetId: string, amount: number?): { string }
	local changed = {}
	for questId, record in profile.Quests do
		if record.State ~= "Active" then continue end
		local definition = QuestDefinitions[questId]
		for _, objective in definition.objectives do
			local matches = objective.kind == kind and ((kind == "KillMob" and objective.mobId == targetId) or (kind == "TalkToNpc" and objective.npcId == targetId) or (kind == "ReachLocation" and objective.poiId == targetId))
			if matches then
				record.Progress[objective.id] = math.min(objective.required, (record.Progress[objective.id] or 0) + (amount or 1))
				table.insert(changed, questId)
			end
		end
		if complete(record, definition) then record.State = "ReadyToTurnIn" end
	end
	return changed
end

function QuestRules.turnIn(profile: any, questId: string, npcId: string): (boolean, string?)
	local definition = QuestDefinitions[questId]
	local record = profile.Quests[questId]
	if definition == nil then return false, "UnknownQuest" end
	if definition.turnInNpcId ~= npcId then return false, "WrongNpc" end
	if record == nil or record.State ~= "ReadyToTurnIn" then return false, "NotReady" end
	-- State and rewards are changed inside one profile mutation. Completed makes replay idempotent.
	local progression = ProgressionRules.applyXP(profile.Level, profile.XP, definition.rewardXP)
	profile.Level, profile.XP = progression.level, progression.xp
	profile.Luna += definition.rewardLuna
	record.State = "Completed"
	return true, nil
end

return table.freeze(QuestRules)
