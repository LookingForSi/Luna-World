--!strict
local TransferIntentRules = {}
local AUTHORITATIVE_KEYS = { Luna=true, Inventory=true, Equipment=true, XP=true, Quests=true, Health=true, Rewards=true }
function TransferIntentRules.validate(value: any, now: number, destinationRole: string): (boolean, string?)
	if typeof(value) ~= "table" then return false, "Malformed" end
	if value.transferVersion ~= 1 or typeof(value.transferId) ~= "string" or value.transferId == "" then return false, "Malformed" end
	if typeof(value.userId) ~= "number" or typeof(value.characterId) ~= "string" or value.characterId == "" then return false, "Malformed" end
	if value.destinationRole ~= destinationRole then return false, "WrongDestination" end
	if typeof(value.expiresAt) ~= "number" or value.expiresAt <= now then return false, "Expired" end
	for key in AUTHORITATIVE_KEYS do if value[key] ~= nil then return false, "AuthoritativeStateForbidden" end end
	return true
end
function TransferIntentRules.validateRouting(value: any, destinationRole: string): (boolean, string?)
	if typeof(value) ~= "table" or value.transferVersion ~= 1 then return false, "Malformed" end
	if typeof(value.transferId) ~= "string" or value.transferId == "" then return false, "Malformed" end
	if typeof(value.characterId) ~= "string" or value.characterId == "" then return false, "Malformed" end
	if value.destinationRole ~= destinationRole then return false, "WrongDestination" end
	for key in AUTHORITATIVE_KEYS do if value[key] ~= nil then return false, "AuthoritativeStateForbidden" end end
	return true, nil
end
function TransferIntentRules.routingPayload(intent: any): any
	return { transferVersion=1, transferId=intent.transferId, characterId=intent.characterId, destinationRole=intent.destinationRole, entryPointId=intent.entryPointId }
end
return table.freeze(TransferIntentRules)
