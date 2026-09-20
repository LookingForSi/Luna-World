--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CraftingDefinitions = require(ReplicatedStorage.Shared.definitions.CraftingDefinitions)
local EconomyBalance = require(ReplicatedStorage.Shared.economy.EconomyBalance)
local EconomyRequestRules = require(ReplicatedStorage.Shared.economy.EconomyRequestRules)
local EconomyRules = require(ReplicatedStorage.Shared.economy.EconomyRules)
local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local LootTableDefinitions = require(ReplicatedStorage.Shared.definitions.LootTableDefinitions)
local ProfileSchema = require(ReplicatedStorage.Shared.persistence.ProfileSchema)
local StarterGearRules = require(ReplicatedStorage.Shared.economy.StarterGearRules)

local function generator(prefix: string): () -> string local n = 0; return function() n += 1; return prefix .. n end end
local function fundedRecipe(id: string): any
	local profile = ProfileSchema.createDefault(); profile.Luna = 10000; profile.Level = 15
	for _, ingredient in CraftingDefinitions[id].ingredients do profile = assert(InventoryRules.add(profile, ingredient.itemId, ingredient.quantity, generator(ingredient.itemId))) end
	return profile
end
local function levelSixRouteProfile(): any
	local profile = ProfileSchema.createDefault()
	profile.Level = 6
	profile.Luna = math.floor(EconomyBalance.expectedDirectLuna(EconomyBalance.LevelSixRoute))
	for itemId, quantity in EconomyBalance.expectedRouteItems(EconomyBalance.LevelSixRoute) do
		local whole = math.floor(quantity)
		if whole > 0 then profile = assert(InventoryRules.add(profile, itemId, whole, generator(itemId))) end
	end
	return profile
end
local function craftRepeated(profile: any, recipeId: string, count: number): any
	for _ = 1, count do profile = assert(EconomyRules.craft(profile, recipeId, generator(recipeId))) end
	return profile
end

return function(TestRunner)
	TestRunner.run("grade is separate and current obtainable gear never exceeds NoGrade", function()
		assert(ItemDefinitions.weapon_training_sword.grade == "Newbie")
		assert(ItemDefinitions.weapon_iron_blade.grade == "NoGrade")
		assert(ItemDefinitions.weapon_moonsteel_sword.grade == "Future")
		for _, recipe in CraftingDefinitions do assert(ItemDefinitions[recipe.outputItemId].grade == "NoGrade") end
	end)
	TestRunner.run("NoGrade weapons have target power", function()
		assert(ItemDefinitions.weapon_iron_blade.statModifiers.physicalAttack == 6)
		assert(ItemDefinitions.weapon_hunter_bow.statModifiers.physicalAttack == 6)
		assert(ItemDefinitions.weapon_rune_staff.statModifiers.magicAttack == 6)
	end)
	TestRunner.run("strong mobs keep total ready-gear chance between three and eight percent", function()
		for _, lootId in { "loot_wolf_pack_leader", "loot_goblin_shaman", "loot_goblin_chieftain", "loot_brood_spider", "loot_dire_wolf_alpha", "loot_grave_guardian", "loot_shrine_guardian", "loot_moonbound_warden" } do
			local chance = 0
			for _, entry in LootTableDefinitions[lootId].entries do
				local item = ItemDefinitions[entry.itemId]
				if item.equipmentSlot ~= nil then chance += entry.chance; assert(item.grade == "NoGrade") end
			end
			assert(chance >= 0.03 and chance <= 0.08, string.format("%s gear chance %.3f", lootId, chance))
		end
	end)
	TestRunner.run("craft definitions reference valid materials and resist arbitrage", function()
		for id, recipe in CraftingDefinitions do
			assert(ItemDefinitions[recipe.outputItemId] ~= nil and recipe.fee > 0)
			for _, ingredient in recipe.ingredients do assert(ItemDefinitions[ingredient.itemId].category == "Material" and ingredient.quantity > 0) end
			local retail = ItemDefinitions[recipe.outputItemId].merchantRetail
			local cost = assert(EconomyRules.craftCost(id)); local sell = assert(EconomyRules.buybackPrice(recipe.outputItemId))
			assert(retail == EconomyRules.expectedCraftRetail(id)); assert(sell * recipe.outputQuantity < cost)
		end
	end)
	TestRunner.run("craft is atomic for success and rejection", function()
		local profile = fundedRecipe("craft_armor_guard_head"); local before = profile.Luna
		local crafted = assert(EconomyRules.craft(profile, "craft_armor_guard_head", generator("gear")))
		assert(crafted.Luna == before - CraftingDefinitions.craft_armor_guard_head.fee); assert(#crafted.Inventory == 1)
		local empty = ProfileSchema.createDefault(); empty.Level = 15; local rejected, reason = EconomyRules.craft(empty, "craft_armor_guard_head", generator("none")); assert(rejected == nil and reason == "InsufficientLuna")
		empty.Luna = 100; rejected, reason = EconomyRules.craft(empty, "craft_armor_guard_head", generator("none")); assert(rejected == nil and reason == "InsufficientMaterials")
		local full = fundedRecipe("craft_armor_guard_head")
		for _, ingredient in CraftingDefinitions.craft_armor_guard_head.ingredients do full = assert(InventoryRules.add(full, ingredient.itemId, 1, generator("extra"))) end
		for index = #full.Inventory + 1, 40 do local instanceId = "filler" .. index; full.Items[instanceId] = { ItemId = "material_wolf_pelt", Quantity = 1 }; full.Inventory[index] = instanceId end
		local fullResult, fullReason = EconomyRules.craft(full, "craft_armor_guard_head", generator("full")); assert(fullResult == nil and fullReason == "InventoryFull")
	end)
	TestRunner.run("craft enforces level and material output quantity", function()
		local low = fundedRecipe("craft_weapon_rune_staff"); low.Level = 5
		local denied, reason = EconomyRules.craft(low, "craft_weapon_rune_staff", generator("low"))
		assert(denied == nil and reason == "LevelTooLow")
		local processed = assert(EconomyRules.craft(fundedRecipe("craft_material_cured_leather"), "craft_material_cured_leather", generator("leather")))
		assert(EconomyRules.ownedQuantity(processed, "material_cured_leather") == 2)
	end)
	TestRunner.run("merchant buy sell ratio and equipped protection", function()
		local profile = ProfileSchema.createDefault(); profile.Luna = 1000
		local bought = assert(EconomyRules.buy(profile, "consumable_minor_healing_draught", 2, generator("buy"))); assert(bought.Luna == 940)
		local sold = assert(EconomyRules.sell(bought, bought.Inventory[1], 1)); assert(sold.Luna == 958)
		local equippedProfile = ProfileSchema.createDefault(); equippedProfile.Items.x = { ItemId = "weapon_iron_blade", Quantity = 1 }; equippedProfile.Equipment.Weapon = "x"
		local denied, reason = EconomyRules.sell(equippedProfile, "x", 1); assert(denied == nil and reason == "EquippedItem")
	end)
	TestRunner.run("merchant batch sale is atomic and totals selected quantities", function()
		local profile = ProfileSchema.createDefault()
		profile = assert(InventoryRules.add(profile, "material_wolf_pelt", 5, generator("pelt")))
		profile = assert(InventoryRules.add(profile, "material_iron_scrap", 3, generator("iron")))
		local peltId = profile.Inventory[1]
		local ironId = profile.Inventory[2]
		local peltPrice = assert(EconomyRules.buybackPrice("material_wolf_pelt"))
		local ironPrice = assert(EconomyRules.buybackPrice("material_iron_scrap"))
		local sold, reason, total = EconomyRules.sellBatch(profile, {
			{ instanceId = peltId, quantity = 2 },
			{ instanceId = ironId, quantity = 3 },
		})
		assert(reason == nil and sold ~= nil)
		assert(total == peltPrice * 2 + ironPrice * 3)
		assert(sold.Luna == total)
		assert(sold.Items[peltId].Quantity == 3)
		assert(sold.Items[ironId] == nil)

		local rejected = EconomyRules.sellBatch(profile, {
			{ instanceId = peltId, quantity = 2 },
			{ instanceId = "missing", quantity = 1 },
		})
		assert(rejected == nil)
		assert(profile.Items[peltId].Quantity == 5, "failed batch must not mutate the source profile")
	end)
	TestRunner.run("starter grant is archetype-specific and idempotent", function()
		for _, archetype in { "knight", "ranger", "mystic" } do
			local profile = ProfileSchema.createDefault(); profile.ArchetypeId = archetype
			local first = assert(StarterGearRules.grantAndEquip(profile, generator(archetype))); local second = assert(StarterGearRules.grantAndEquip(first, generator("again")))
			assert(#first.Inventory == 0 and #second.Inventory == 0); assert(first.Equipment.Weapon ~= nil and first.Equipment.Weapon == second.Equipment.Weapon)
			assert(first.Items[first.Equipment.Weapon].ItemId == StarterGearRules.itemForArchetype(archetype))
		end
		local inventoryOnly = ProfileSchema.createDefault(); inventoryOnly = assert(InventoryRules.add(inventoryOnly, "weapon_training_sword", 1, generator("legacy")))
		local equipped = assert(StarterGearRules.grantAndEquip(inventoryOnly, generator("unused"))); assert(equipped.Equipment.Weapon ~= nil and #equipped.Inventory == 0)

		local switched = assert(StarterGearRules.switchArchetype(equipped, "ranger", generator("switch")))
		assert(switched.ArchetypeId == "ranger")
		assert(switched.Equipment.Weapon ~= nil)
		assert(switched.Items[switched.Equipment.Weapon].ItemId == "weapon_ash_bow")
		assert(ItemDefinitions.weapon_ash_bow.displayName == "Учебный лук")
		assert(ItemDefinitions.weapon_ash_staff.displayName == "Учебный посох")
	end)
	TestRunner.run("hostile economy quantities and shapes are rejected", function()
		for _, value in { -1, 0, 0/0, math.huge, 1.5 } do assert(EconomyRequestRules.validate(3, "Buy", "material_iron_scrap", value) == nil) end
		assert(EconomyRequestRules.validate(3, "Unknown", "x", 1) == nil); assert(EconomyRequestRules.validate(3, "Craft", "x", 2) == nil)
		assert(EconomyRequestRules.validateSellBatch(2, "SellBatch", {
			{ instanceId = "a", quantity = 2 },
			{ instanceId = "b", quantity = 1 },
		}) ~= nil)
		assert(EconomyRequestRules.validateSellBatch(2, "SellBatch", {
			{ instanceId = "a", quantity = 1 },
			{ instanceId = "a", quantity = 1 },
		}) == nil)
		assert(EconomyRequestRules.validateSellBatch(2, "SellBatch", {}) == nil)
	end)
	TestRunner.run("class set route values stay within fifteen percent", function()
		local costs = { EconomyBalance.fullSetCraftCost("knight"), EconomyBalance.fullSetCraftCost("ranger"), EconomyBalance.fullSetCraftCost("mystic") }
		table.sort(costs)
		assert(costs[3] <= costs[1] * 1.15, string.format("class set spread %d..%d", costs[1], costs[3]))
		local resources = EconomyBalance.expectedRouteItems(EconomyBalance.LevelSixRoute)
		assert((resources.material_wolf_pelt or 0) >= 9)
		assert((resources.material_spider_silk or 0) >= 9)
		assert((resources.material_iron_scrap or 0) >= 12)
		assert((resources.material_goblin_token or 0) >= 2)
		assert((resources.material_magic_dust or 0) >= 3)
		assert(EconomyBalance.expectedRouteValue(EconomyBalance.LevelSixRoute) >= 100)
	end)
	TestRunner.run("level-six route crafts a weapon and armor for every class", function()
		local plans = {
			knight = { cured = 1, sturdy = 0, billet = 3, weapon = "craft_weapon_iron_blade", armor = "craft_armor_guard_head" },
			ranger = { cured = 2, sturdy = 2, billet = 1, weapon = "craft_weapon_hunter_bow", armor = "craft_armor_hunter_head" },
			mystic = { cured = 1, sturdy = 2, billet = 1, weapon = "craft_weapon_rune_staff", armor = "craft_armor_adept_head" },
		}
		for archetype, plan in plans do
			local profile = levelSixRouteProfile(); profile.ArchetypeId = archetype
			profile = craftRepeated(profile, "craft_material_cured_leather", plan.cured)
			profile = craftRepeated(profile, "craft_material_sturdy_thread", plan.sturdy)
			profile = craftRepeated(profile, "craft_material_iron_billet", plan.billet)
			profile = assert(EconomyRules.craft(profile, plan.weapon, generator(archetype .. "weapon")))
			profile = assert(EconomyRules.craft(profile, plan.armor, generator(archetype .. "armor")))
			assert(EconomyRules.ownedQuantity(profile, CraftingDefinitions[plan.weapon].outputItemId) == 1)
			assert(EconomyRules.ownedQuantity(profile, CraftingDefinitions[plan.armor].outputItemId) == 1)
		end
	end)
end
