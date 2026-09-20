--!strict

export type Ingredient = { itemId: string, quantity: number }
export type CraftDefinition = { id: string, outputItemId: string, fee: number, ingredients: { Ingredient } }

local function recipe(id: string, outputItemId: string, fee: number, ingredients: { Ingredient }): CraftDefinition
	return table.freeze({ id = id, outputItemId = outputItemId, fee = fee, ingredients = table.freeze(ingredients) }) :: any
end
local function ingredient(itemId: string, quantity: number): Ingredient
	return table.freeze({ itemId = itemId, quantity = quantity }) :: any
end

local definitions: { [string]: CraftDefinition } = {
	craft_weapon_iron_blade = recipe("craft_weapon_iron_blade", "weapon_iron_blade", 50, { ingredient("material_iron_scrap", 8), ingredient("material_sharp_fang", 3), ingredient("material_goblin_token", 2) }),
	craft_weapon_hunter_bow = recipe("craft_weapon_hunter_bow", "weapon_hunter_bow", 50, { ingredient("material_iron_scrap", 4), ingredient("material_spider_silk", 6), ingredient("material_wolf_pelt", 3) }),
	craft_weapon_rune_staff = recipe("craft_weapon_rune_staff", "weapon_rune_staff", 50, { ingredient("material_iron_scrap", 4), ingredient("material_magic_dust", 6), ingredient("material_fallen_relic", 2) }),
	craft_armor_guard_head = recipe("craft_armor_guard_head", "armor_guard_head", 30, { ingredient("material_iron_scrap", 4), ingredient("material_cured_leather", 2) }),
	craft_armor_guard_chest = recipe("craft_armor_guard_chest", "armor_guard_chest", 55, { ingredient("material_iron_scrap", 7), ingredient("material_cured_leather", 5) }),
	craft_armor_guard_gloves = recipe("craft_armor_guard_gloves", "armor_guard_gloves", 25, { ingredient("material_iron_scrap", 3), ingredient("material_cured_leather", 2), ingredient("material_spider_silk", 2) }),
	craft_armor_guard_boots = recipe("craft_armor_guard_boots", "armor_guard_boots", 25, { ingredient("material_iron_scrap", 3), ingredient("material_cured_leather", 4) }),
	craft_accessory_silver_moon_charm = recipe("craft_accessory_silver_moon_charm", "accessory_silver_moon_charm", 40, { ingredient("material_magic_dust", 4), ingredient("material_ancient_shard", 2), ingredient("material_fallen_relic", 2) }),
}

return table.freeze(definitions)
