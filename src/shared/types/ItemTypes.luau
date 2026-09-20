--!strict

local ProgressionTypes = require(script.Parent.ProgressionTypes)

export type ItemCategory = "Weapon" | "Armor" | "Accessory" | "Consumable" | "Material"
export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic"
export type ItemGrade = "Newbie" | "NoGrade" | "Future"
export type EquipmentSlot = "Weapon" | "Head" | "Chest" | "Gloves" | "Boots" | "Accessory"
export type ConsumableKind = "HealHP" | "RestoreResource" | "ReturnToSettlement"

export type ConsumableEffect = {
	kind: ConsumableKind,
	amount: number,
}

export type ItemDefinition = {
	id: string,
	displayName: string,
	category: ItemCategory,
	rarity: ItemRarity,
	grade: ItemGrade,
	merchantRetail: number,
	stackable: boolean,
	maxStack: number,
	equipmentSlot: EquipmentSlot?,
	requiredLevel: number,
	allowedArchetypes: { string }?,
	statModifiers: ProgressionTypes.StatModifiers,
	consumableEffect: ConsumableEffect?,
}

return table.freeze({})
