--!strict

local LootTypes = require(script.Parent.Parent.types.LootTypes)

local function loot(values: any): LootTypes.LootTableDefinition
	return table.freeze({
		id = values.id,
		lunaMin = values.lunaMin,
		lunaMax = values.lunaMax,
		entries = table.freeze(values.entries),
	}) :: LootTypes.LootTableDefinition
end

local function entry(itemId: string, chance: number, minQuantity: number?, maxQuantity: number?): any
	return table.freeze({
		itemId = itemId,
		chance = chance,
		minQuantity = minQuantity or 1,
		maxQuantity = maxQuantity or minQuantity or 1,
	})
end

local function resourceEntry(itemId: string, chance: number, minQuantity: number?, maxQuantity: number?): any
	-- Ordinary crafting materials keep the reduced global drop rate.
	return entry(itemId, chance * 0.5, minQuantity, maxQuantity)
end

local function signatureResourceEntry(itemId: string, chance: number, minQuantity: number?, maxQuantity: number?): any
	-- Signature materials with a single thematic source must not require
	-- repetitive farming of one rare mob just to unlock an early class recipe.
	return entry(itemId, chance, minQuantity, maxQuantity)
end

local definitions: { [string]: LootTypes.LootTableDefinition } = {
	loot_empty = loot({ id = "loot_empty", lunaMin = 0, lunaMax = 0, entries = {} }),
	loot_young_wolf = loot({ id = "loot_young_wolf", lunaMin = 1, lunaMax = 3, entries = {
		resourceEntry("material_wolf_pelt", 0.45), resourceEntry("material_sharp_fang", 0.15),
		entry("consumable_minor_healing_draught", 0.05), entry("armor_worn_gloves", 0.01),
	} }),
	loot_grey_wolf = loot({ id = "loot_grey_wolf", lunaMin = 2, lunaMax = 5, entries = {
		resourceEntry("material_wolf_pelt", 0.65, 1, 2), resourceEntry("material_sharp_fang", 0.35),
		entry("consumable_minor_healing_draught", 0.08), entry("armor_worn_chest", 0.015),
	} }),
	loot_wolf_pack_leader = loot({ id = "loot_wolf_pack_leader", lunaMin = 5, lunaMax = 9, entries = {
		resourceEntry("material_wolf_pelt", 0.85, 1, 2), resourceEntry("material_sharp_fang", 0.55, 1, 2),
		entry("armor_guard_gloves", 0.04), entry("weapon_hunter_bow", 0.03),
	} }),
	loot_goblin_scout = loot({ id = "loot_goblin_scout", lunaMin = 4, lunaMax = 8, entries = {
		resourceEntry("material_goblin_token", 0.55), resourceEntry("material_iron_scrap", 0.75), entry("consumable_minor_healing_draught", 0.07),
		entry("armor_guard_boots", 0.015),
	} }),
	loot_goblin_warrior = loot({ id = "loot_goblin_warrior", lunaMin = 6, lunaMax = 11, entries = {
		resourceEntry("material_goblin_token", 0.75, 1, 2), resourceEntry("material_iron_scrap", 0.85, 1, 2), entry("consumable_minor_healing_draught", 0.10),
		entry("armor_guard_head", 0.015), entry("weapon_iron_blade", 0.015),
	} }),
	loot_goblin_shaman = loot({ id = "loot_goblin_shaman", lunaMin = 8, lunaMax = 14, entries = {
		resourceEntry("material_goblin_token", 0.8, 1, 2), signatureResourceEntry("material_magic_dust", 1.0), entry("consumable_minor_resource_draught", 0.14),
		entry("accessory_silver_moon_charm", 0.05), entry("weapon_rune_staff", 0.03),
	} }),
	loot_goblin_chieftain = loot({ id = "loot_goblin_chieftain", lunaMin = 18, lunaMax = 28, entries = {
		resourceEntry("material_goblin_token", 1, 2, 4), entry("armor_guard_chest", 0.03),
		entry("weapon_iron_blade", 0.015), entry("weapon_hunter_bow", 0.015), entry("weapon_rune_staff", 0.015),
	} }),
	loot_spider = loot({ id = "loot_spider", lunaMin = 4, lunaMax = 7, entries = {
		resourceEntry("material_spider_silk", 0.75, 1, 2), resourceEntry("material_venom_sac", 0.20),
		entry("consumable_minor_resource_draught", 0.08), entry("accessory_moon_charm", 0.015),
	} }),
	loot_brood_spider = loot({ id = "loot_brood_spider", lunaMin = 9, lunaMax = 15, entries = {
		resourceEntry("material_spider_silk", 0.9, 1, 3), resourceEntry("material_venom_sac", 0.55),
		entry("consumable_minor_resource_draught", 0.14), entry("accessory_silver_moon_charm", 0.03),
	} }),
	loot_dire_wolf = loot({ id = "loot_dire_wolf", lunaMin = 8, lunaMax = 13, entries = {
		resourceEntry("material_dire_hide", 0.55), resourceEntry("material_cured_leather", 0.65), resourceEntry("material_sharp_fang", 0.45, 1, 2),
		entry("armor_guard_gloves", 0.015),
	} }),
	loot_dire_wolf_alpha = loot({ id = "loot_dire_wolf_alpha", lunaMin = 16, lunaMax = 25, entries = {
		resourceEntry("material_dire_hide", 0.9, 1, 2), resourceEntry("material_sharp_fang", 0.75, 1, 2),
		resourceEntry("material_cured_leather", 0.65), entry("armor_guard_gloves", 0.04),
	} }),
	loot_forest_spider = loot({ id = "loot_forest_spider", lunaMin = 9, lunaMax = 14, entries = {
		resourceEntry("material_spider_silk", 0.65, 1, 2), resourceEntry("material_venom_sac", 0.3),
		entry("consumable_minor_resource_draught", 0.09),
	} }),
	loot_skeleton = loot({ id = "loot_skeleton", lunaMin = 10, lunaMax = 16, entries = {
		resourceEntry("material_bone_fragment", 0.7, 1, 2), resourceEntry("material_iron_scrap", 0.55), entry("armor_guard_boots", 0.015),
	} }),
	loot_skeleton_archer = loot({ id = "loot_skeleton_archer", lunaMin = 11, lunaMax = 18, entries = {
		resourceEntry("material_bone_fragment", 0.75, 1, 2), entry("weapon_hunter_bow", 0.012),
	} }),
	loot_grave_guardian = loot({ id = "loot_grave_guardian", lunaMin = 24, lunaMax = 34, entries = {
		resourceEntry("material_bone_fragment", 1, 2, 4), entry("armor_guard_chest", 0.03),
		entry("weapon_iron_blade", 0.04),
	} }),
	loot_fallen_acolyte = loot({ id = "loot_fallen_acolyte", lunaMin = 12, lunaMax = 19, entries = {
		resourceEntry("material_fallen_relic", 0.55), resourceEntry("material_magic_dust", 0.55), entry("consumable_minor_resource_draught", 0.1),
		entry("weapon_rune_staff", 0.012),
	} }),
	loot_shrine_guardian = loot({ id = "loot_shrine_guardian", lunaMin = 15, lunaMax = 22, entries = {
		resourceEntry("material_fallen_relic", 0.65), entry("armor_guard_head", 0.015),
		entry("armor_guard_chest", 0.015),
	} }),
	loot_ancient_sentinel = loot({ id = "loot_ancient_sentinel", lunaMin = 16, lunaMax = 24, entries = {
		resourceEntry("material_ancient_shard", 0.65), resourceEntry("material_magic_dust", 0.6), entry("armor_guard_chest", 0.015),
	} }),
	loot_ancient_watcher = loot({ id = "loot_ancient_watcher", lunaMin = 18, lunaMax = 26, entries = {
		resourceEntry("material_ancient_shard", 0.7), entry("accessory_silver_moon_charm", 0.05),
	} }),
	loot_moonbound_warden = loot({ id = "loot_moonbound_warden", lunaMin = 45, lunaMax = 65, entries = {
		resourceEntry("material_ancient_shard", 1, 2, 4), resourceEntry("material_magic_dust", 1, 3, 5),
		entry("weapon_iron_blade", 0.02), entry("weapon_hunter_bow", 0.02), entry("weapon_rune_staff", 0.02),
	} }),
}

return table.freeze(definitions)
