--!strict

local LootTableDefinitions = require(script.Parent.Parent.definitions.LootTableDefinitions)

local TravelRules = {}

function TravelRules.isUnlocked(quests: any, definition: any): boolean
	if typeof(quests) ~= "table" or typeof(definition) ~= "table" then return false end
	local record = quests[definition.unlockQuestId]
	return typeof(record) == "table" and record.State == "Completed"
end

function TravelRules.costLuna(definition: any): number
	local loot = LootTableDefinitions[definition.representativeLootTableId]
	if loot == nil then return 1 end
	local averageLuna = (loot.lunaMin + loot.lunaMax) / 2
	return math.max(1, math.ceil(averageLuna * definition.killEquivalent))
end

function TravelRules.destinationNpcId(definition: any, sourceNpcId: string): string?
	if sourceNpcId == definition.villageNpcId then return definition.fieldNpcId end
	if sourceNpcId == definition.fieldNpcId then return definition.villageNpcId end
	return nil
end

function TravelRules.arrivalOffset(definition: any, destinationNpcId: string): Vector3
	if destinationNpcId == definition.villageNpcId then return definition.villageArrivalOffset end
	return definition.fieldArrivalOffset
end

return table.freeze(TravelRules)
