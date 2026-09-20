--!strict

local ItemTypes = require(script.Parent.Parent.types.ItemTypes)

local function mods(values: any?): any
	return table.freeze(values or {})
end

local function weapon(
	id: string,
	displayName: string,
	rarity: ItemTypes.ItemRarity,
	requiredLevel: number,
	archetypeId: string,
	statModifiers: any
): ItemTypes.ItemDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		category = "Weapon",
		rarity = rarity,
		grade = if string.find(id, "training") or id == "weapon_ash_bow" or id == "weapon_ash_staff" then "Newbie" else if string.find(id, "moonsteel") or string.find(id, "moonstring") or string.find(id, "moonveil") then "Future" else "NoGrade",
		merchantRetail = 0,
		stackable = false,
		maxStack = 1,
		equipmentSlot = "Weapon",
		requiredLevel = requiredLevel,
		allowedArchetypes = table.freeze({ archetypeId }),
		statModifiers = mods(statModifiers),
		consumableEffect = nil,
	})
end

local function equipment(
	id: string,
	displayName: string,
	category: "Armor" | "Accessory",
	rarity: ItemTypes.ItemRarity,
	requiredLevel: number,
	slot: ItemTypes.EquipmentSlot,
	statModifiers: any
): ItemTypes.ItemDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		category = category,
		rarity = rarity,
		grade = if string.find(id, "lunar_sigil") then "Future" else "NoGrade",
		merchantRetail = 0,
		stackable = false,
		maxStack = 1,
		equipmentSlot = slot,
		requiredLevel = requiredLevel,
		allowedArchetypes = nil,
		statModifiers = mods(statModifiers),
		consumableEffect = nil,
	})
end

local function stackable(
	id: string,
	displayName: string,
	category: "Consumable" | "Material",
	rarity: ItemTypes.ItemRarity,
	consumableEffect: ItemTypes.ConsumableEffect?,
	merchantRetail: number?
): ItemTypes.ItemDefinition
	return table.freeze({
		id = id,
		displayName = displayName,
		category = category,
		rarity = rarity,
		grade = "NoGrade",
		merchantRetail = merchantRetail or 0,
		stackable = true,
		maxStack = 99,
		equipmentSlot = nil,
		requiredLevel = 1,
		allowedArchetypes = nil,
		statModifiers = mods(),
		consumableEffect = if consumableEffect ~= nil then table.freeze(consumableEffect) else nil,
	})
end

local definitions: { [string]: ItemTypes.ItemDefinition } = {
	weapon_training_sword = weapon("weapon_training_sword", "Учебный меч", "Common", 1, "knight", { physicalAttack = 3 }),
	weapon_iron_blade = weapon("weapon_iron_blade", "Железный клинок", "Uncommon", 4, "knight", { physicalAttack = 6 }),
	weapon_moonsteel_sword = weapon("weapon_moonsteel_sword", "Меч лунной стали", "Rare", 7, "knight", { physicalAttack = 9, criticalChance = 0.01 }),

	weapon_ash_bow = weapon("weapon_ash_bow", "Учебный лук", "Common", 1, "ranger", { physicalAttack = 3 }),
	weapon_hunter_bow = weapon("weapon_hunter_bow", "Охотничий лук", "Uncommon", 4, "ranger", { physicalAttack = 6, criticalChance = 0.005 }),
	weapon_moonstring_bow = weapon("weapon_moonstring_bow", "Лук лунной тетивы", "Rare", 7, "ranger", { physicalAttack = 9, criticalChance = 0.015 }),

	weapon_ash_staff = weapon("weapon_ash_staff", "Учебный посох", "Common", 1, "mystic", { magicAttack = 3 }),
	weapon_rune_staff = weapon("weapon_rune_staff", "Рунный посох", "Uncommon", 4, "mystic", { magicAttack = 6 }),
	weapon_moonveil_staff = weapon("weapon_moonveil_staff", "Посох лунной вуали", "Rare", 7, "mystic", { magicAttack = 9, criticalChance = 0.01 }),

	armor_worn_head = equipment("armor_worn_head", "Потрёпанный капюшон", "Armor", "Common", 1, "Head", { physicalDefense = 2 }),
	armor_guard_head = equipment("armor_guard_head", "Шлем стража", "Armor", "Uncommon", 4, "Head", { physicalDefense = 4, maxHealth = 8 }),
	armor_worn_chest = equipment("armor_worn_chest", "Потрёпанный доспех", "Armor", "Common", 1, "Chest", { physicalDefense = 4, maxHealth = 8 }),
	armor_guard_chest = equipment("armor_guard_chest", "Доспех стража", "Armor", "Uncommon", 4, "Chest", { physicalDefense = 8, maxHealth = 18 }),
	armor_worn_gloves = equipment("armor_worn_gloves", "Потрёпанные перчатки", "Armor", "Common", 1, "Gloves", { physicalDefense = 1 }),
	armor_guard_gloves = equipment("armor_guard_gloves", "Перчатки стража", "Armor", "Uncommon", 4, "Gloves", { physicalDefense = 2, criticalChance = 0.005 }),
	armor_worn_boots = equipment("armor_worn_boots", "Потрёпанные сапоги", "Armor", "Common", 1, "Boots", { physicalDefense = 1 }),
	armor_guard_boots = equipment("armor_guard_boots", "Сапоги стража", "Armor", "Uncommon", 4, "Boots", { physicalDefense = 2, maxHealth = 5 }),
	accessory_moon_charm = equipment("accessory_moon_charm", "Лунный талисман", "Accessory", "Common", 1, "Accessory", { maxResource = 5 }),
	accessory_silver_moon_charm = equipment("accessory_silver_moon_charm", "Серебряный лунный талисман", "Accessory", "Uncommon", 4, "Accessory", { maxResource = 12, criticalChance = 0.005 }),

	material_wolf_pelt = stackable("material_wolf_pelt", "Волчья шкура", "Material", "Common", nil),
	material_sharp_fang = stackable("material_sharp_fang", "Острый клык", "Material", "Common", nil),
	material_spider_silk = stackable("material_spider_silk", "Паучий шёлк", "Material", "Common", nil),
	material_venom_sac = stackable("material_venom_sac", "Ядовитая железа", "Material", "Uncommon", nil),
	material_goblin_token = stackable("material_goblin_token", "Гоблинский жетон", "Material", "Common", nil),
	material_dire_hide = stackable("material_dire_hide", "Шкура лютого волка", "Material", "Uncommon", nil),
	material_bone_fragment = stackable("material_bone_fragment", "Фрагмент древней кости", "Material", "Common", nil),
	material_fallen_relic = stackable("material_fallen_relic", "Осквернённая реликвия", "Material", "Uncommon", nil),
	material_ancient_shard = stackable("material_ancient_shard", "Осколок древнего камня", "Material", "Uncommon", nil),
	material_iron_scrap = stackable("material_iron_scrap", "Железный лом", "Material", "Common", nil, 18),
	material_cured_leather = stackable("material_cured_leather", "Выделанная кожа", "Material", "Common", nil, 16),
	material_magic_dust = stackable("material_magic_dust", "Магическая пыль", "Material", "Uncommon", nil, 24),
	consumable_minor_healing_draught = stackable(
		"consumable_minor_healing_draught",
		"Малое лечебное зелье",
		"Consumable",
		"Common",
		{ kind = "HealHP", amount = 30 }
	),
	consumable_minor_resource_draught = stackable(
		"consumable_minor_resource_draught",
		"Малое зелье ресурса",
		"Consumable",
		"Common",
		{ kind = "RestoreResource", amount = 30 }
	),
	consumable_scroll_return_luna = stackable(
		"consumable_scroll_return_luna",
		"Свиток возвращения в Luna Village",
		"Consumable",
		"Common",
		{ kind = "ReturnToSettlement", amount = 0 },
		45
	),

	accessory_lunar_sigil = equipment(
		"accessory_lunar_sigil",
		"Лунная печать",
		"Accessory",
		"Epic",
		10,
		"Accessory",
		{ maxHealth = 25, maxResource = 20, physicalDefense = 5, criticalChance = 0.03 }
	),
}

local retailOverrides = {
	material_wolf_pelt = 12, material_sharp_fang = 16, material_spider_silk = 15,
	material_venom_sac = 22, material_goblin_token = 14, material_dire_hide = 24,
	material_bone_fragment = 15, material_fallen_relic = 26, material_ancient_shard = 28,
	consumable_minor_healing_draught = 30, consumable_minor_resource_draught = 32,
	armor_worn_head = 55, armor_worn_chest = 90, armor_worn_gloves = 40, armor_worn_boots = 40, accessory_moon_charm = 70,
	weapon_iron_blade = 351, weapon_hunter_bow = 322, weapon_rune_staff = 413,
	armor_guard_head = 174, armor_guard_chest = 339, armor_guard_gloves = 183,
	armor_guard_boots = 186, accessory_silver_moon_charm = 317,
}
for id, price in retailOverrides do
	local original: any = definitions[id]
	local copy = table.clone(original)
	copy.merchantRetail = price
	definitions[id] = table.freeze(copy)
end

return table.freeze(definitions)
