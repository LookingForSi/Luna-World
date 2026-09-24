--!strict

local PartyRequestRules = {}

local function validUserId(value: unknown, allowStudioSyntheticUserIds: boolean): boolean
	if typeof(value) ~= "number" or value ~= value or math.abs(value) == math.huge or value == 0 or value % 1 ~= 0 then
		return false
	end
	return value > 0 or (allowStudioSyntheticUserIds and value < 0)
end

local function validInviteId(value: unknown): boolean
	return typeof(value) == "string" and #value >= 8 and #value <= 64
end

function PartyRequestRules.validate(argumentCount: number, payload: unknown, allowStudioSyntheticUserIds: boolean?): (string?, number?, string?)
	if argumentCount ~= 1 or typeof(payload) ~= "table" then return nil, nil, nil end
	local value = payload :: any
	if value.action == "Invite" or value.action == "Kick" then
		if not validUserId(value.targetUserId, allowStudioSyntheticUserIds == true) then return nil, nil, nil end
		return value.action, value.targetUserId, nil
	elseif value.action == "Accept" or value.action == "Decline" then
		if not validInviteId(value.inviteId) then return nil, nil, nil end
		return value.action, nil, value.inviteId
	elseif value.action == "Leave" then
		return "Leave", nil, nil
	end
	return nil, nil, nil
end

return table.freeze(PartyRequestRules)
