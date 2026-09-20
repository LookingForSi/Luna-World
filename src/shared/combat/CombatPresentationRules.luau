--!strict

local CombatPresentationRules = {}

export type Kind = "Action" | "Result" | "Interruption" | "Effect" | "Death" | "Respawn" | "Reward"
export type ReasonCode = "Cooldown" | "InvalidTarget" | "OutOfRange" | "InsufficientResource" | "ForbiddenState" | "RateLimited"
export type Fields = {
	targetEntityId: string?,
	skillId: string?,
	presentationKey: string?,
	outcome: string?,
	amount: number?,
	isCritical: boolean?,
	effectPhase: "Started" | "Ended"?,
	reasonCode: ReasonCode?,
	definitionId: string?,
}
export type Message = Fields & {
	kind: Kind,
	actionId: string,
	actorEntityId: string,
	serverTime: number,
}

local supportedKinds: { [string]: boolean } = {
	Action = true,
	Result = true,
	Interruption = true,
	Effect = true,
	Death = true,
	Respawn = true,
	Reward = true,
}
local supportedOutcomes: { [string]: boolean } = {
	Accepted = true,
	Applied = true,
	ResolveFailed = true,
	Canceled = true,
	Rejected = true,
	Dead = true,
	Respawned = true,
	Ended = true,
	Granted = true,
}
local publicFields: { [string]: boolean } = {
	kind = true,
	actionId = true,
	actorEntityId = true,
	targetEntityId = true,
	skillId = true,
	presentationKey = true,
	outcome = true,
	amount = true,
	isCritical = true,
	effectPhase = true,
	serverTime = true,
	reasonCode = true,
	definitionId = true,
}

function CombatPresentationRules.create(kind: Kind, actionId: string, actorEntityId: string, serverTime: number, fields: Fields?): Message
	assert(supportedKinds[kind] == true and actionId ~= "" and actorEntityId ~= "", "invalid presentation identity")
	assert(serverTime == serverTime and math.abs(serverTime) < math.huge, "serverTime must be finite")
	local values = fields or {}
	return table.freeze({
		kind = kind,
		actionId = actionId,
		actorEntityId = actorEntityId,
		serverTime = serverTime,
		targetEntityId = values.targetEntityId,
		skillId = values.skillId,
		presentationKey = values.presentationKey,
		outcome = values.outcome,
		amount = values.amount,
		isCritical = values.isCritical,
		effectPhase = values.effectPhase,
		reasonCode = values.reasonCode,
		definitionId = values.definitionId,
	})
end

function CombatPresentationRules.isSupported(value: unknown): boolean
	if typeof(value) ~= "table" then return false end
	local message = value :: { [any]: any }
	for key in message do
		if typeof(key) ~= "string" or publicFields[key] ~= true then return false end
	end
	local identityValid = typeof(message.kind) == "string"
		and supportedKinds[message.kind] == true
		and typeof(message.actionId) == "string"
		and message.actionId ~= ""
		and typeof(message.actorEntityId) == "string"
		and message.actorEntityId ~= ""
		and typeof(message.serverTime) == "number"
		and message.serverTime == message.serverTime
		and math.abs(message.serverTime) < math.huge
	if not identityValid then return false end
	for _, key in { "targetEntityId", "skillId", "presentationKey", "outcome", "definitionId" } do
		if message[key] ~= nil and typeof(message[key]) ~= "string" then return false end
	end
	if message.outcome ~= nil and supportedOutcomes[message.outcome] ~= true then return false end
	if message.amount ~= nil and (typeof(message.amount) ~= "number" or message.amount ~= message.amount or math.abs(message.amount) == math.huge) then return false end
	if message.isCritical ~= nil and typeof(message.isCritical) ~= "boolean" then return false end
	if message.effectPhase ~= nil and message.effectPhase ~= "Started" and message.effectPhase ~= "Ended" then return false end
	if message.reasonCode ~= nil
		and message.reasonCode ~= "Cooldown"
		and message.reasonCode ~= "InvalidTarget"
		and message.reasonCode ~= "OutOfRange"
		and message.reasonCode ~= "InsufficientResource"
		and message.reasonCode ~= "ForbiddenState"
		and message.reasonCode ~= "RateLimited"
	then return false end
	return true
end

function CombatPresentationRules.isTerminalFor(action: Message, terminal: Message): boolean
	return CombatPresentationRules.isSupported(action)
		and CombatPresentationRules.isSupported(terminal)
		and action.kind == "Action"
		and (terminal.kind == "Result" or terminal.kind == "Interruption")
		and action.actionId == terminal.actionId
end

return table.freeze(CombatPresentationRules)
