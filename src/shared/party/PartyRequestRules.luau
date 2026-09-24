--!strict

local PartyRequestRules = {}

local function validUserId(value: unknown): boolean
	return typeof(value) == "number" and value == value and value > 0 and value % 1 == 0 and value < math.huge
end

local function validInviteId(value: unknown): boolean
	return typeof(value) == "string" and #value >= 8 and #value <= 64
end

function PartyRequestRules.validate(argumentCount: number, payload: unknown): (string?, number?, string?)
	if argumentCount ~= 1 or typeof(payload) ~= "table" then return nil, nil, nil end
	local value = payload :: any
	if value.action == "Invite" then
		if not validUserId(value.targetUserId) then return nil, nil, nil end
		return "Invite", value.targetUserId, nil
	elseif value.action == "Accept" or value.action == "Decline" then
		if not validInviteId(value.inviteId) then return nil, nil, nil end
		return value.action, nil, value.inviteId
	elseif value.action == "Leave" then
		return "Leave", nil, nil
	end
	return nil, nil, nil
end

return table.freeze(PartyRequestRules)
