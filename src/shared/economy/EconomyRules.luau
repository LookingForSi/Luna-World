--!strict

local CraftingDefinitions = require(script.Parent.Parent.definitions.CraftingDefinitions)
local InventoryRules = require(script.Parent.Parent.inventory.InventoryRules)
local ItemDefinitions = require(script.Parent.Parent.definitions.ItemDefinitions)
local MerchantDefinitions = require(script.Parent.Parent.definitions.MerchantDefinitions)
local ProfileSchema = require(script.Parent.Parent.persistence.ProfileSchema)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local EconomyRules = {}
export type FailureReason = "InvalidItem" | "InvalidCraft" | "InvalidQuantity" | "NotForSale" | "NotOwned" | "EquippedItem" | "InsufficientLuna" | "InsufficientMaterials" | "InventoryFull" | "DuplicateInstance"
local stock: { [string]: boolean } = {}
for _, itemId in MerchantDefinitions.Stock do stock[itemId] = true end

function EconomyRules.positiveInteger(value: unknown): boolean
	return typeof(value) == "number" and value == value and value > 0 and value < math.huge and value % 1 == 0
end

function EconomyRules.buybackPrice(itemId: string): number?
	local item = ItemDefinitions[itemId]
	if item == nil or item.merchantRetail <= 0 or item.grade == "Newbie" or item.grade == "Future" then return nil end
	return math.floor(item.merchantRetail * MerchantDefinitions.BuybackRatio)
end

function EconomyRules.craftCost(recipeId: string): number?
	local recipe = CraftingDefinitions[recipeId]
	if recipe == nil then return nil end
	local total = recipe.fee
	for _, ingredient in recipe.ingredients do
		local definition = ItemDefinitions[ingredient.itemId]
		if definition == nil then return nil end
		total += definition.merchantRetail * ingredient.quantity
	end
	return total
end

function EconomyRules.expectedCraftRetail(recipeId: string): number?
	local cost = EconomyRules.craftCost(recipeId)
	return if cost == nil then nil else math.floor(cost * MerchantDefinitions.CraftMarkup + 0.5)
end

local function ownedQuantity(profile: PersistenceTypes.Profile, itemId: string): number
	local total = 0
	for _, instanceId in profile.Inventory do
		local record = profile.Items[instanceId]
		if record ~= nil and record.ItemId == itemId then total += record.Quantity end
	end
	return total
end
EconomyRules.ownedQuantity = ownedQuantity

local function removeByItem(profile: PersistenceTypes.Profile, itemId: string, quantity: number): PersistenceTypes.Profile?
	local nextProfile = profile
	local remaining = quantity
	while remaining > 0 do
		local found: string? = nil
		for _, instanceId in nextProfile.Inventory do
			local record = nextProfile.Items[instanceId]
			if record ~= nil and record.ItemId == itemId then found = instanceId; break end
		end
		if found == nil then return nil end
		local record = nextProfile.Items[found]
		local remove = math.min(remaining, record.Quantity)
		local after = InventoryRules.discard(nextProfile, found, remove)
		if after == nil then return nil end
		nextProfile = after
		remaining -= remove
	end
	return nextProfile
end

function EconomyRules.buy(profile: PersistenceTypes.Profile, itemId: string, quantity: number, generateId: () -> string): (PersistenceTypes.Profile?, FailureReason?)
	local item = ItemDefinitions[itemId]
	if item == nil then return nil, "InvalidItem" end
	if not EconomyRules.positiveInteger(quantity) then return nil, "InvalidQuantity" end
	if stock[itemId] ~= true or item.merchantRetail <= 0 or item.grade == "Newbie" or item.grade == "Future" then return nil, "NotForSale" end
	local cost = item.merchantRetail * quantity
	if profile.Luna < cost then return nil, "InsufficientLuna" end
	local nextProfile, reason = InventoryRules.add(profile, itemId, quantity, generateId)
	if nextProfile == nil then return nil, reason :: FailureReason end
	nextProfile.Luna -= cost
	return nextProfile, nil
end

function EconomyRules.sell(profile: PersistenceTypes.Profile, instanceId: string, quantity: number): (PersistenceTypes.Profile?, FailureReason?)
	if not EconomyRules.positiveInteger(quantity) then return nil, "InvalidQuantity" end
	local record = profile.Items[instanceId]
	if record == nil then return nil, "NotOwned" end
	local price = EconomyRules.buybackPrice(record.ItemId)
	if price == nil then return nil, "NotForSale" end
	local nextProfile, reason = InventoryRules.discard(profile, instanceId, quantity)
	if nextProfile == nil then return nil, reason :: FailureReason end
	nextProfile.Luna += price * quantity
	return nextProfile, nil
end

function EconomyRules.sellBatch(
	profile: PersistenceTypes.Profile,
	selections: { any }
): (PersistenceTypes.Profile?, FailureReason?, number?)
	if #selections < 1 or #selections > 40 then return nil, "InvalidQuantity", nil end
	local nextProfile = ProfileSchema.clone(profile)
	local total = 0
	local seen: { [string]: boolean } = {}

	for _, selection in selections do
		local instanceId = selection.instanceId
		local quantity = selection.quantity
		if typeof(instanceId) ~= "string" or seen[instanceId] or not EconomyRules.positiveInteger(quantity) then
			return nil, "InvalidQuantity", nil
		end
		seen[instanceId] = true

		local record = nextProfile.Items[instanceId]
		if record == nil then return nil, "NotOwned", nil end
		local price = EconomyRules.buybackPrice(record.ItemId)
		if price == nil then return nil, "NotForSale", nil end
		if quantity > record.Quantity then return nil, "InvalidQuantity", nil end

		local after, reason = InventoryRules.discard(nextProfile, instanceId, quantity)
		if after == nil then return nil, reason :: FailureReason, nil end
		nextProfile = after
		total += price * quantity
	end

	nextProfile.Luna += total
	return nextProfile, nil, total
end

function EconomyRules.craft(profile: PersistenceTypes.Profile, recipeId: string, generateId: () -> string): (PersistenceTypes.Profile?, FailureReason?)
	local recipe = CraftingDefinitions[recipeId]
	if recipe == nil then return nil, "InvalidCraft" end
	if profile.Luna < recipe.fee then return nil, "InsufficientLuna" end
	for _, ingredient in recipe.ingredients do
		if ownedQuantity(profile, ingredient.itemId) < ingredient.quantity then return nil, "InsufficientMaterials" end
	end
	local nextProfile = ProfileSchema.clone(profile)
	for _, ingredient in recipe.ingredients do
		local after = removeByItem(nextProfile, ingredient.itemId, ingredient.quantity)
		if after == nil then return nil, "InsufficientMaterials" end
		nextProfile = after
	end
	local afterAdd, reason = InventoryRules.add(nextProfile, recipe.outputItemId, 1, generateId)
	if afterAdd == nil then return nil, reason :: FailureReason end
	afterAdd.Luna -= recipe.fee
	return afterAdd, nil
end

return table.freeze(EconomyRules)
