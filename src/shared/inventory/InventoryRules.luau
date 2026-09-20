--!strict

local InventoryConfig = require(script.Parent.Parent.config.InventoryConfig)
local ItemDefinitions = require(script.Parent.Parent.definitions.ItemDefinitions)
local ProfileSchema = require(script.Parent.Parent.persistence.ProfileSchema)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local InventoryRules = {}

export type FailureReason =
	"InvalidItem"
	| "InvalidQuantity"
	| "InventoryFull"
	| "DuplicateInstance"
	| "NotOwned"
	| "EquippedItem"

local function positiveInteger(value: number): boolean
	return value == value and value > 0 and value < math.huge and value % 1 == 0
end

local function findInventoryIndex(profile: PersistenceTypes.Profile, instanceId: string): number?
	for index, candidate in profile.Inventory do
		if candidate == instanceId then return index end
	end
	return nil
end

local function createUniqueInstanceId(
	profile: PersistenceTypes.Profile,
	generateInstanceId: () -> string
): string?
	for _ = 1, 16 do
		local candidate = generateInstanceId()
		if candidate ~= "" and profile.Items[candidate] == nil then return candidate end
	end
	return nil
end

function InventoryRules.usedSlots(profile: PersistenceTypes.Profile): number
	return #profile.Inventory
end

function InventoryRules.contains(profile: PersistenceTypes.Profile, instanceId: string): boolean
	return findInventoryIndex(profile, instanceId) ~= nil
end

function InventoryRules.add(
	profile: PersistenceTypes.Profile,
	itemId: string,
	quantity: number,
	generateInstanceId: () -> string
): (PersistenceTypes.Profile?, FailureReason?)
	local definition = ItemDefinitions[itemId]
	if definition == nil then return nil, "InvalidItem" end
	if not positiveInteger(quantity) then return nil, "InvalidQuantity" end

	local nextProfile = ProfileSchema.clone(profile)
	local remaining = quantity

	if definition.stackable then
		for _, instanceId in nextProfile.Inventory do
			local record = nextProfile.Items[instanceId]
			if record ~= nil and record.ItemId == itemId and record.Quantity < definition.maxStack then
				local room = definition.maxStack - record.Quantity
				local moved = math.min(room, remaining)
				record.Quantity += moved
				remaining -= moved
				if remaining == 0 then break end
			end
		end
	end

	while remaining > 0 do
		if #nextProfile.Inventory >= InventoryConfig.Capacity then
			return nil, "InventoryFull"
		end
		local instanceId = createUniqueInstanceId(nextProfile, generateInstanceId)
		if instanceId == nil then return nil, "DuplicateInstance" end

		local stackQuantity = if definition.stackable then math.min(definition.maxStack, remaining) else 1
		nextProfile.Items[instanceId] = {
			ItemId = itemId,
			Quantity = stackQuantity,
		}
		table.insert(nextProfile.Inventory, instanceId)
		remaining -= stackQuantity
	end

	local valid = ProfileSchema.validateCurrent(nextProfile)
	assert(valid, "InventoryRules.add created an invalid profile")
	return nextProfile, nil
end

function InventoryRules.discard(
	profile: PersistenceTypes.Profile,
	instanceId: string,
	quantity: number?
): (PersistenceTypes.Profile?, FailureReason?)
	local index = findInventoryIndex(profile, instanceId)
	if index == nil then
		if profile.Items[instanceId] ~= nil then return nil, "EquippedItem" end
		return nil, "NotOwned"
	end
	local record = profile.Items[instanceId]
	if record == nil then return nil, "NotOwned" end

	local removeQuantity = quantity or record.Quantity
	if not positiveInteger(removeQuantity) or removeQuantity > record.Quantity then
		return nil, "InvalidQuantity"
	end

	local nextProfile = ProfileSchema.clone(profile)
	local nextRecord = nextProfile.Items[instanceId]
	assert(nextRecord ~= nil)
	if removeQuantity < nextRecord.Quantity then
		nextRecord.Quantity -= removeQuantity
	else
		table.remove(nextProfile.Inventory, index)
		nextProfile.Items[instanceId] = nil
	end

	local valid = ProfileSchema.validateCurrent(nextProfile)
	assert(valid, "InventoryRules.discard created an invalid profile")
	return nextProfile, nil
end

return table.freeze(InventoryRules)
