--!strict
local TransferIntentRules = {}
local TransferConfig = require(script.Parent.Parent.Parent.config.TransferConfig)
local AUTHORITATIVE_KEYS = { Luna=true, Inventory=true, Equipment=true, XP=true, Quests=true, Health=true, Rewards=true }
local ALLOWED_TRANSITIONS = { Lobby = { World = true }, World = { Dungeon = true }, Dungeon = { World = true } }
function TransferIntentRules.validate(value: any, now: number, destinationRole: string): (boolean, string?)
	if typeof(value) ~= "table" then return false, "Malformed" end
	if value.transferVersion ~= TransferConfig.Version or typeof(value.transferId) ~= "string" or value.transferId == "" then return false, "Malformed" end
	if typeof(value.userId) ~= "number" or typeof(value.characterId) ~= "string" or value.characterId == "" then return false, "Malformed" end
	if typeof(value.sourceRole) ~= "string" or ALLOWED_TRANSITIONS[value.sourceRole] == nil
		or not ALLOWED_TRANSITIONS[value.sourceRole][destinationRole] then return false, "TransitionNotAllowed" end
	if value.destinationRole ~= destinationRole then return false, "WrongDestination" end
	if typeof(value.entryPointId) ~= "string" or value.entryPointId == "" then return false, "Malformed" end
	if typeof(value.expiresAt) ~= "number" or value.expiresAt <= now then return false, "Expired" end
	for key in AUTHORITATIVE_KEYS do if value[key] ~= nil then return false, "AuthoritativeStateForbidden" end end
	return true
end
function TransferIntentRules.validateRouting(value: any, destinationRole: string): (boolean, string?)
	if typeof(value) ~= "table" or value.transferVersion ~= TransferConfig.Version then return false, "Malformed" end
	if typeof(value.transferId) ~= "string" or value.transferId == "" then return false, "Malformed" end
	if typeof(value.characterId) ~= "string" or value.characterId == "" then return false, "Malformed" end
	if value.destinationRole ~= destinationRole then return false, "WrongDestination" end
	if typeof(value.entryPointId) ~= "string" or value.entryPointId == "" then return false, "Malformed" end
	for key in AUTHORITATIVE_KEYS do if value[key] ~= nil then return false, "AuthoritativeStateForbidden" end end
	return true, nil
end
function TransferIntentRules.routingPayload(intent: any): any
	return { transferVersion=TransferConfig.Version, transferId=intent.transferId, characterId=intent.characterId, destinationRole=intent.destinationRole, entryPointId=intent.entryPointId }
end
return table.freeze(TransferIntentRules)
