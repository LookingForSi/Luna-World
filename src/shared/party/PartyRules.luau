--!strict

local PartyConfig = require(script.Parent.PartyConfig)

type PartyState = {
	leaderUserId: number,
	memberUserIds: { number },
	nextLootCursor: number,
}

local PartyRules = {}

local function contains(values: { number }, value: number): boolean
	return table.find(values, value) ~= nil
end

local function copyState(state: PartyState): PartyState
	return {
		leaderUserId = state.leaderUserId,
		memberUserIds = table.clone(state.memberUserIds),
		nextLootCursor = state.nextLootCursor,
	}
end

function PartyRules.canInvite(state: PartyState?, inviterUserId: number, targetUserId: number): boolean
	if inviterUserId == targetUserId then return false end
	if state == nil then return true end
	return state.leaderUserId == inviterUserId
		and #state.memberUserIds < PartyConfig.MaxMembers
		and not contains(state.memberUserIds, targetUserId)
end

function PartyRules.canAccept(state: PartyState?, targetAlreadyInParty: boolean, inviterChanged: boolean, inviteActive: boolean): boolean
	return inviteActive
		and not targetAlreadyInParty
		and not inviterChanged
		and (state == nil or #state.memberUserIds < PartyConfig.MaxMembers)
end

function PartyRules.addMember(state: PartyState, userId: number): PartyState
	if #state.memberUserIds >= PartyConfig.MaxMembers or contains(state.memberUserIds, userId) then return state end
	local nextState = copyState(state)
	table.insert(nextState.memberUserIds, userId)
	return nextState
end

function PartyRules.removeMember(state: PartyState, userId: number): PartyState?
	local index = table.find(state.memberUserIds, userId)
	if index == nil then return state end
	local nextState = copyState(state)
	table.remove(nextState.memberUserIds, index)
	if #nextState.memberUserIds < 2 then return nil end
	if nextState.leaderUserId == userId then nextState.leaderUserId = nextState.memberUserIds[1] end
	if nextState.nextLootCursor > #nextState.memberUserIds then nextState.nextLootCursor = 1 end
	return nextState
end

function PartyRules.splitXP(totalXP: number, orderedUserIds: { number }): { [number]: number }
	assert(totalXP >= 0 and totalXP % 1 == 0, "totalXP must be a non-negative integer")
	local result: { [number]: number } = {}
	if #orderedUserIds == 0 then return result end
	local base = math.floor(totalXP / #orderedUserIds)
	local remainder = totalXP % #orderedUserIds
	for index, userId in orderedUserIds do result[userId] = base + if index <= remainder then 1 else 0 end
	return result
end

function PartyRules.selectRoundRobin(orderedUserIds: { number }, eligible: { [number]: boolean }, cursor: number): (number?, number)
	local count = #orderedUserIds
	if count == 0 then return nil, cursor end
	local start = math.clamp(math.floor(cursor), 1, count)
	for offset = 0, count - 1 do
		local index = ((start - 1 + offset) % count) + 1
		if eligible[orderedUserIds[index]] then return orderedUserIds[index], (index % count) + 1 end
	end
	return nil, cursor
end

function PartyRules.isInviteExpired(createdAt: number, now: number, ttlSeconds: number?): boolean
	return now >= createdAt + (ttlSeconds or PartyConfig.InviteTtlSeconds)
end

return table.freeze(PartyRules)
