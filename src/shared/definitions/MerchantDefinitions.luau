--!strict

local stock = {
	"material_wolf_pelt", "material_sharp_fang", "material_spider_silk", "material_venom_sac",
	"material_goblin_token", "material_dire_hide", "material_bone_fragment", "material_fallen_relic",
	"material_ancient_shard", "material_iron_scrap", "material_cured_leather", "material_magic_dust",
	"consumable_minor_healing_draught", "consumable_minor_resource_draught", "consumable_scroll_return_luna",
	"weapon_iron_blade", "weapon_hunter_bow", "weapon_rune_staff", "armor_guard_head", "armor_guard_chest",
	"armor_guard_gloves", "armor_guard_boots", "accessory_silver_moon_charm",
}

return table.freeze({ Stock = table.freeze(stock), BuybackRatio = 0.60, CraftMarkup = 1.30 })
