--!strict

export type PartyState = {
	leaderUserId: number,
	memberUserIds: { number },
	nextLootCursor: number,
}

export type PartySnapshot = {
	partyId: string,
	revision: number,
	leaderUserId: number,
	memberUserIds: { number },
}

export type Invite = {
	id: string,
	inviterUserId: number,
	targetUserId: number,
	createdAt: number,
}

export type KillContext = {
	killer: Player,
	mobId: string,
	entityId: string,
	deathPosition: Vector3,
	eligiblePlayers: { Player },
	lootRecipient: Player?,
}

return nil
