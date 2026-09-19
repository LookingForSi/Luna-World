--!strict

local LootTypes = require(script.Parent.Parent.types.LootTypes)

local definitions: { [string]: LootTypes.LootTableDefinition } = {
	loot_young_wolf = table.freeze({
		id = "loot_young_wolf",
		lunaMin = 1,
		lunaMax = 3,
		entries = table.freeze({
			table.freeze({ itemId = "material_wolf_pelt", chance = 0.45, minQuantity = 1, maxQuantity = 1 }),
			table.freeze({ itemId = "material_sharp_fang", chance = 0.15, minQuantity = 1, maxQuantity = 1 }),
			table.freeze({ itemId = "consumable_minor_healing_draught", chance = 0.05, minQuantity = 1, maxQuantity = 1 }),
			table.freeze({ itemId = "armor_worn_gloves", chance = 0.03, minQuantity = 1, maxQuantity = 1 }),
		}),
	}),
	loot_grey_wolf = table.freeze({
		id = "loot_grey_wolf",
		lunaMin = 2,
		lunaMax = 5,
		entries = table.freeze({
			table.freeze({ itemId = "material_wolf_pelt", chance = 0.65, minQuantity = 1, maxQuantity = 2 }),
			table.freeze({ itemId = "material_sharp_fang", chance = 0.35, minQuantity = 1, maxQuantity = 1 }),
			table.freeze({ itemId = "consumable_minor_healing_draught", chance = 0.08, minQuantity = 1, maxQuantity = 1 }),
			table.freeze({ itemId = "armor_worn_chest", chance = 0.04, minQuantity = 1, maxQuantity = 1 }),
		}),
	}),
	loot_spider = table.freeze({
		id = "loot_spider",
		lunaMin = 2,
		lunaMax = 4,
		entries = table.freeze({
			table.freeze({ itemId = "material_spider_silk", chance = 0.65, minQuantity = 1, maxQuantity = 2 }),
			table.freeze({ itemId = "consumable_minor_resource_draught", chance = 0.07, minQuantity = 1, maxQuantity = 1 }),
			table.freeze({ itemId = "accessory_moon_charm", chance = 0.04, minQuantity = 1, maxQuantity = 1 }),
		}),
	}),
}

return table.freeze(definitions)
