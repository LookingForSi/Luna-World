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
	RewardClaimed: boolean?,
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

export type BodyType = "male" | "female"

export type CharacterProfile = Profile & {
	CharacterId: string,
	Nickname: string?,
	BodyType: BodyType?,
	AppearancePresetId: string?,
	CreatedAt: number,
	LastPlayedAt: number,
	LastZoneId: string?,
	NeedsIdentity: boolean,
}

export type AccountProfile = {
	DataVersion: number,
	CharacterSlotLimit: number,
	CharacterOrder: { string },
	Characters: { [string]: CharacterProfile },
	SelectedCharacterId: string?,
	Settings: { UiScale: number, TextScale: number, SoundVolume: number },
}

return table.freeze({})
