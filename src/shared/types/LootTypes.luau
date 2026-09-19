--!strict

export type LootEntry = {
	itemId: string,
	chance: number,
	minQuantity: number,
	maxQuantity: number,
}

export type LootTableDefinition = {
	id: string,
	lunaMin: number,
	lunaMax: number,
	entries: { LootEntry },
}

export type ItemReward = {
	itemId: string,
	quantity: number,
}

export type RollResult = {
	luna: number,
	items: { ItemReward },
}

return table.freeze({})
