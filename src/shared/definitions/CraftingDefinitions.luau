--!strict

export type CraftDiscipline = "Knight" | "Ranger" | "Mystic" | "Material"
export type Ingredient = { itemId: string, quantity: number }
export type CraftDefinition = {
	id: string, displayName: string?, discipline: CraftDiscipline, requiredLevel: number,
	outputItemId: string, outputQuantity: number, fee: number, sortOrder: number,
	ingredients: { Ingredient },
}

local function ingredient(itemId: string, quantity: number): Ingredient
	return table.freeze({ itemId = itemId, quantity = quantity }) :: any
end
local function recipe(values: CraftDefinition): CraftDefinition
	values.ingredients = table.freeze(values.ingredients)
	return table.freeze(values)
end
local function r(id: string, discipline: CraftDiscipline, level: number, output: string, quantity: number, fee: number, order: number, ingredients: { Ingredient }): CraftDefinition
	return recipe({ id = id, displayName = nil, discipline = discipline, requiredLevel = level, outputItemId = output, outputQuantity = quantity, fee = fee, sortOrder = order, ingredients = ingredients })
end
local i = ingredient

local definitions: { [string]: CraftDefinition } = {
	craft_material_cured_leather = r("craft_material_cured_leather", "Material", 2, "material_cured_leather", 2, 4, 10, { i("material_wolf_pelt", 3) }),
	craft_material_sturdy_thread = r("craft_material_sturdy_thread", "Material", 4, "material_sturdy_thread", 2, 4, 20, { i("material_spider_silk", 3) }),
	craft_material_iron_billet = r("craft_material_iron_billet", "Material", 4, "material_iron_billet", 1, 8, 30, { i("material_iron_scrap", 4), i("material_goblin_token", 1) }),
	craft_material_arcane_thread = r("craft_material_arcane_thread", "Material", 6, "material_arcane_thread", 1, 10, 40, { i("material_sturdy_thread", 2), i("material_magic_dust", 2) }),

	craft_weapon_iron_blade = r("craft_weapon_iron_blade", "Knight", 4, "weapon_iron_blade", 1, 30, 10, { i("material_iron_billet", 2), i("material_sharp_fang", 1) }),
	craft_armor_guard_head = r("craft_armor_guard_head", "Knight", 4, "armor_guard_head", 1, 18, 20, { i("material_iron_billet", 1), i("material_cured_leather", 1) }),
	craft_armor_guard_chest = r("craft_armor_guard_chest", "Knight", 5, "armor_guard_chest", 1, 35, 30, { i("material_iron_billet", 2), i("material_cured_leather", 3) }),
	craft_armor_guard_gloves = r("craft_armor_guard_gloves", "Knight", 4, "armor_guard_gloves", 1, 16, 40, { i("material_iron_billet", 1), i("material_cured_leather", 1), i("material_sturdy_thread", 1) }),
	craft_armor_guard_boots = r("craft_armor_guard_boots", "Knight", 4, "armor_guard_boots", 1, 16, 50, { i("material_iron_billet", 1), i("material_cured_leather", 2) }),

	craft_weapon_hunter_bow = r("craft_weapon_hunter_bow", "Ranger", 4, "weapon_hunter_bow", 1, 30, 10, { i("material_iron_billet", 1), i("material_sturdy_thread", 2), i("material_cured_leather", 1), i("material_sharp_fang", 1) }),
	craft_armor_hunter_head = r("craft_armor_hunter_head", "Ranger", 4, "armor_hunter_head", 1, 18, 20, { i("material_cured_leather", 2), i("material_sturdy_thread", 1) }),
	craft_armor_hunter_chest = r("craft_armor_hunter_chest", "Ranger", 5, "armor_hunter_chest", 1, 32, 30, { i("material_cured_leather", 3), i("material_sturdy_thread", 2) }),
	craft_armor_hunter_gloves = r("craft_armor_hunter_gloves", "Ranger", 4, "armor_hunter_gloves", 1, 18, 40, { i("material_cured_leather", 2), i("material_sturdy_thread", 2), i("material_sharp_fang", 1) }),
	craft_armor_hunter_boots = r("craft_armor_hunter_boots", "Ranger", 4, "armor_hunter_boots", 1, 16, 50, { i("material_cured_leather", 2), i("material_sturdy_thread", 1) }),

	craft_weapon_rune_staff = r("craft_weapon_rune_staff", "Mystic", 6, "weapon_rune_staff", 1, 30, 10, { i("material_iron_billet", 1), i("material_magic_dust", 2), i("material_sturdy_thread", 2) }),
	craft_armor_adept_head = r("craft_armor_adept_head", "Mystic", 5, "armor_adept_head", 1, 18, 20, { i("material_cured_leather", 1), i("material_sturdy_thread", 2), i("material_magic_dust", 1) }),
	craft_armor_adept_chest = r("craft_armor_adept_chest", "Mystic", 6, "armor_adept_chest", 1, 32, 30, { i("material_cured_leather", 2), i("material_sturdy_thread", 3), i("material_magic_dust", 2) }),
	craft_armor_adept_gloves = r("craft_armor_adept_gloves", "Mystic", 6, "armor_adept_gloves", 1, 18, 40, { i("material_cured_leather", 1), i("material_arcane_thread", 1), i("material_magic_dust", 1) }),
	craft_armor_adept_boots = r("craft_armor_adept_boots", "Mystic", 5, "armor_adept_boots", 1, 16, 50, { i("material_cured_leather", 1), i("material_sturdy_thread", 2), i("material_magic_dust", 1) }),

	craft_accessory_silver_moon_charm = r("craft_accessory_silver_moon_charm", "Knight", 6, "accessory_silver_moon_charm", 1, 25, 60, { i("material_magic_dust", 3), i("material_arcane_thread", 1), i("material_venom_sac", 1) }),
}

return table.freeze(definitions)
