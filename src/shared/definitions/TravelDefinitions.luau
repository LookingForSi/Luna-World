--!strict

-- Teleport routes are unlocked by completed quests rather than a second
-- persistence flag. This keeps travel progression derived from authoritative
-- quest state and makes future routes cheap to add.
local definitions = {
	travel_farm = table.freeze({
		id = "travel_farm",
		displayName = "Ферма Moonfall",
		unlockQuestId = "quest_young_wolf_problem",
		villageNpcId = "npc_gatekeeper",
		fieldNpcId = "npc_farmer",
		representativeLootTableId = "loot_young_wolf",
		killEquivalent = 4,
		villageArrivalOffset = Vector3.new(10, 3, 5),
		fieldArrivalOffset = Vector3.new(9, 3, 7),
	}),
	travel_moonfall = table.freeze({
		id = "travel_moonfall",
		displayName = "Дозор Moonfall",
		unlockQuestId = "quest_stone_circle_pack",
		villageNpcId = "npc_gatekeeper",
		fieldNpcId = "npc_moonfall_scout",
		representativeLootTableId = "loot_grey_wolf",
		killEquivalent = 4,
		villageArrivalOffset = Vector3.new(10, 3, 5),
		fieldArrivalOffset = Vector3.new(9, 3, 7),
	}),
	travel_dark_woodland = table.freeze({
		id = "travel_dark_woodland",
		displayName = "Дозор Dark Woodland",
		unlockQuestId = "quest_spider_hollow",
		villageNpcId = "npc_gatekeeper",
		fieldNpcId = "npc_dark_woodland_scout",
		representativeLootTableId = "loot_dire_wolf",
		killEquivalent = 4,
		villageArrivalOffset = Vector3.new(10, 3, 5),
		fieldArrivalOffset = Vector3.new(-10, 3, -8),
	}),
}

return table.freeze(definitions)
