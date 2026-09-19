--!strict

local ProgressionTypes = require(script.Parent.ProgressionTypes)

export type ItemCategory = "Weapon" | "Armor" | "Accessory" | "Consumable" | "Material"
export type ItemRarity = "Common" | "Uncommon" | "Rare" | "Epic"
export type EquipmentSlot = "Weapon" | "Head" | "Chest" | "Gloves" | "Boots" | "Accessory"
export type ConsumableKind = "HealHP" | "RestoreResource"

export type ConsumableEffect = {
	kind: ConsumableKind,
	amount: number,
}

export type ItemDefinition = {
	id: string,
	displayName: string,
	category: ItemCategory,
	rarity: ItemRarity,
	stackable: boolean,
	maxStack: number,
	equipmentSlot: EquipmentSlot?,
	requiredLevel: number,
	allowedArchetypes: { string }?,
	statModifiers: ProgressionTypes.StatModifiers,
	consumableEffect: ConsumableEffect?,
}

return table.freeze({})
