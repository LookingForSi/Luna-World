--!strict

local InventoryConfig = require(script.Parent.Parent.config.InventoryConfig)
local ItemDefinitions = require(script.Parent.Parent.definitions.ItemDefinitions)
local ProfileSchema = require(script.Parent.Parent.persistence.ProfileSchema)
local ItemTypes = require(script.Parent.Parent.types.ItemTypes)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local EquipmentRules = {}

export type FailureReason =
	"NotOwned"
	| "NotEquippable"
	| "WrongArchetype"
	| "LevelTooLow"
	| "InventoryFull"
	| "EmptySlot"
	| "InvalidSlot"

local function findInventoryIndex(profile: PersistenceTypes.Profile, instanceId: string): number?
	for index, candidate in profile.Inventory do
		if candidate == instanceId then return index end
	end
	return nil
end

local function archetypeAllowed(allowed: { string }?, archetypeId: string): boolean
	if allowed == nil then return true end
	for _, candidate in allowed do
		if candidate == archetypeId then return true end
	end
	return false
end

function EquipmentRules.equip(
	profile: PersistenceTypes.Profile,
	instanceId: string,
	archetypeId: string,
	level: number
): (PersistenceTypes.Profile?, FailureReason?)
	local index = findInventoryIndex(profile, instanceId)
	if index == nil then return nil, "NotOwned" end
	local record = profile.Items[instanceId]
	if record == nil or record.Quantity ~= 1 then return nil, "NotOwned" end
	local definition = ItemDefinitions[record.ItemId]
	if definition == nil or definition.equipmentSlot == nil then return nil, "NotEquippable" end
	if not archetypeAllowed(definition.allowedArchetypes, archetypeId) then return nil, "WrongArchetype" end
	if level < definition.requiredLevel then return nil, "LevelTooLow" end

	local nextProfile = ProfileSchema.clone(profile)
	table.remove(nextProfile.Inventory, index)

	local slot = definition.equipmentSlot :: ItemTypes.EquipmentSlot
	local previous = nextProfile.Equipment[slot]
	if previous ~= nil then
		table.insert(nextProfile.Inventory, previous)
	end
	nextProfile.Equipment[slot] = instanceId

	local valid = ProfileSchema.validateCurrent(nextProfile)
	assert(valid, "EquipmentRules.equip created an invalid profile")
	return nextProfile, nil
end

function EquipmentRules.unequip(
	profile: PersistenceTypes.Profile,
	slot: ItemTypes.EquipmentSlot
): (PersistenceTypes.Profile?, FailureReason?)
	if InventoryConfig.EquipmentSlotSet[slot] ~= true then return nil, "InvalidSlot" end
	local instanceId = profile.Equipment[slot]
	if instanceId == nil then return nil, "EmptySlot" end
	if #profile.Inventory >= InventoryConfig.Capacity then return nil, "InventoryFull" end

	local nextProfile = ProfileSchema.clone(profile)
	nextProfile.Equipment[slot] = nil
	table.insert(nextProfile.Inventory, instanceId)

	local valid = ProfileSchema.validateCurrent(nextProfile)
	assert(valid, "EquipmentRules.unequip created an invalid profile")
	return nextProfile, nil
end

return table.freeze(EquipmentRules)
