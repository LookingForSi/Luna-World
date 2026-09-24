--!strict

local PartyInviteRules = {}

function PartyInviteRules.isPairCoolingDown(lastInviteAt: number?, now: number, cooldown: number): boolean
	return lastInviteAt ~= nil and now - lastInviteAt < cooldown
end

function PartyInviteRules.findForTarget(invites: { [string]: any }, targetUserId: number): string?
	for inviteId, invite in invites do
		if invite.targetUserId == targetUserId then return inviteId end
	end
	return nil
end

function PartyInviteRules.canConsume(invite: any?, targetUserId: number, now: number, ttl: number): (boolean, string?)
	if invite == nil or invite.targetUserId ~= targetUserId then return false, "InvalidInvite" end
	if now >= invite.createdAt + ttl then return false, "ExpiredInvite" end
	return true, nil
end

return table.freeze(PartyInviteRules)
