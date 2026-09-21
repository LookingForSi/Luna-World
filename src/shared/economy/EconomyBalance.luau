--!strict

local EconomyRules = require(script.Parent.EconomyRules)
local CraftingDefinitions = require(script.Parent.Parent.definitions.CraftingDefinitions)
local ItemDefinitions = require(script.Parent.Parent.definitions.ItemDefinitions)
local LootTableDefinitions = require(script.Parent.Parent.definitions.LootTableDefinitions)

local EconomyBalance = {}
EconomyBalance.NaturalRoute = table.freeze({
	loot_young_wolf = 5, loot_grey_wolf = 5, loot_wolf_pack_leader = 1,
	loot_goblin_scout = 6, loot_goblin_warrior = 3, loot_goblin_shaman = 1, loot_goblin_chieftain = 1,
	loot_spider = 5, loot_brood_spider = 1, loot_dire_wolf = 4, loot_forest_spider = 2, loot_dire_wolf_alpha = 1,
	loot_skeleton = 4, loot_skeleton_archer = 2, loot_grave_guardian = 1,
	loot_fallen_acolyte = 3, loot_shrine_guardian = 2, loot_ancient_sentinel = 3, loot_ancient_watcher = 1,
	loot_moonbound_warden = 1,
})
EconomyBalance.LevelSixRoute = table.freeze({
	-- Q2-Q5 objective kills plus one Goblin Shaman as the natural final XP push
	-- from late LV5 into LV6. This route totals 963 mob XP; with the 360 XP from
	-- those quests it reaches LV6 without silently modeling LV9-LV10 farming.
	loot_young_wolf = 4, loot_grey_wolf = 4, loot_wolf_pack_leader = 1,
	loot_goblin_scout = 4, loot_goblin_warrior = 1, loot_goblin_shaman = 1,
	loot_spider = 4, loot_brood_spider = 1,
})

function EconomyBalance.expectedRouteValue(route: { [string]: number }): number
	local value = 0
	for lootId, kills in route do
		local loot = LootTableDefinitions[lootId]
		value += ((loot.lunaMin + loot.lunaMax) / 2) * kills
		for _, entry in loot.entries do
			local definition = ItemDefinitions[entry.itemId]
			local sell = EconomyRules.buybackPrice(entry.itemId) or 0
			local averageQuantity = (entry.minQuantity + entry.maxQuantity) / 2
			if definition.category == "Material" then value += sell * entry.chance * averageQuantity * kills end
		end
	end
	return value
end

function EconomyBalance.expectedDirectLuna(route: { [string]: number }): number
	local value = 0
	for lootId, kills in route do
		local loot = LootTableDefinitions[lootId]
		value += ((loot.lunaMin + loot.lunaMax) / 2) * kills
	end
	return value
end

function EconomyBalance.fullSetCraftCost(archetypeId: string): number
	local weapon = if archetypeId == "ranger" then "craft_weapon_hunter_bow" else if archetypeId == "mystic" then "craft_weapon_rune_staff" else "craft_weapon_iron_blade"
	local prefix = if archetypeId == "ranger" then "craft_armor_hunter_" else if archetypeId == "mystic" then "craft_armor_adept_" else "craft_armor_guard_"
	local total = 0
	for _, id in { weapon, prefix .. "head", prefix .. "chest", prefix .. "gloves", prefix .. "boots" } do
		total += EconomyRules.craftCost(id) or 0
	end
	return total
end

function EconomyBalance.expectedRouteItems(route: { [string]: number }): { [string]: number }
	local items = {}
	for lootId, kills in route do
		for _, entry in LootTableDefinitions[lootId].entries do
			if ItemDefinitions[entry.itemId].category == "Material" then
				items[entry.itemId] = (items[entry.itemId] or 0) + entry.chance * ((entry.minQuantity + entry.maxQuantity) / 2) * kills
			end
		end
	end
	return items
end

return table.freeze(EconomyBalance)
