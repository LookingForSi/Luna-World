--!strict

export type ProfileItemRecord = {
	ItemId: string,
	Quantity: number,
}

export type Equipment = {
	Weapon: string?,
	Head: string?,
	Chest: string?,
	Gloves: string?,
	Boots: string?,
	Accessory: string?,
}

export type QuestRecord = {
	State: "Active" | "ReadyToTurnIn" | "Completed",
	Progress: { [string]: number },
}

export type Profile = {
	DataVersion: number,
	Level: number,
	XP: number,
	Luna: number,
	ArchetypeId: string,
	Items: { [string]: ProfileItemRecord },
	Inventory: { string },
	Equipment: Equipment,
	Quests: { [string]: QuestRecord },
}

return table.freeze({})
