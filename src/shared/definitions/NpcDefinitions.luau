--!strict
local definitions = {
	npc_gatekeeper = { id = "npc_gatekeeper", displayName = "Страж ворот", poiId = "poi_main_gate", modelName = "GatekeeperNpc", positionOffset = Vector3.new(12, 0, -8) },
	npc_farmer = { id = "npc_farmer", displayName = "Фермер", poiId = "poi_moonfall_farm", modelName = "FarmerNpc", positionOffset = Vector3.new(28, 0, -20) },
	npc_moonfall_scout = { id = "npc_moonfall_scout", displayName = "Дозорный Moonfall", poiId = "poi_moonfall_crossroads", modelName = "MoonfallScoutNpc", positionOffset = Vector3.new(-25, 0, -20) },
	npc_merchant = { id = "npc_merchant", displayName = "Торговец", poiId = "poi_merchant", modelName = "MerchantNpc", economy = "Merchant" },
	npc_blacksmith = { id = "npc_blacksmith", displayName = "Кузнец", poiId = "poi_blacksmith", modelName = "BlacksmithNpc", economy = "Craft" },
}
return table.freeze(definitions)
