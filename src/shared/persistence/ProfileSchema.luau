--!strict

local ArchetypeDefinitions = require(script.Parent.Parent.definitions.ArchetypeDefinitions)
local InventoryConfig = require(script.Parent.Parent.config.InventoryConfig)
local ProgressionRules = require(script.Parent.Parent.progression.ProgressionRules)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local ProfileSchema = {}

ProfileSchema.DataVersion = 1

local function finiteInteger(value: unknown): boolean
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and value % 1 == 0
end

local function fail(message: string): (boolean, string)
	return false, message
end

function ProfileSchema.createDefault(): PersistenceTypes.Profile
	return {
		DataVersion = ProfileSchema.DataVersion,
		Level = 1,
		XP = 0,
		Luna = 0,
		ArchetypeId = "knight",
		Items = {},
		Inventory = {},
		Equipment = {
			Weapon = nil,
			Head = nil,
			Chest = nil,
			Gloves = nil,
			Boots = nil,
			Accessory = nil,
		},
	}
end

function ProfileSchema.clone(profile: PersistenceTypes.Profile): PersistenceTypes.Profile
	local items: { [string]: PersistenceTypes.ProfileItemRecord } = {}
	for instanceId, record in profile.Items do
		items[instanceId] = { ItemId = record.ItemId, Quantity = record.Quantity }
	end
	local inventory = table.clone(profile.Inventory)
	local equipment: PersistenceTypes.Equipment = {
		Weapon = profile.Equipment.Weapon,
		Head = profile.Equipment.Head,
		Chest = profile.Equipment.Chest,
		Gloves = profile.Equipment.Gloves,
		Boots = profile.Equipment.Boots,
		Accessory = profile.Equipment.Accessory,
	}
	return {
		DataVersion = profile.DataVersion,
		Level = profile.Level,
		XP = profile.XP,
		Luna = profile.Luna,
		ArchetypeId = profile.ArchetypeId,
		Items = items,
		Inventory = inventory,
		Equipment = equipment,
	}
end

function ProfileSchema.validateCurrent(profile: unknown): (boolean, string?)
	if typeof(profile) ~= "table" then return fail("profile must be a table") end
	local value: any = profile

	if value.DataVersion ~= ProfileSchema.DataVersion then
		return fail("profile DataVersion is not current")
	end
	if not finiteInteger(value.Level) or not finiteInteger(value.XP) then
		return fail("profile progression must use integer Level and XP")
	end
	if not ProgressionRules.isValidState(value.Level, value.XP) then
		return fail("profile progression state is invalid")
	end
	if not finiteInteger(value.Luna) or value.Luna < 0 then
		return fail("profile Luna must be a nonnegative integer")
	end
	if typeof(value.ArchetypeId) ~= "string" or ArchetypeDefinitions[value.ArchetypeId] == nil then
		return fail("profile ArchetypeId is invalid")
	end
	if typeof(value.Items) ~= "table" then return fail("profile Items must be a table") end
	if typeof(value.Inventory) ~= "table" then return fail("profile Inventory must be a table") end
	if typeof(value.Equipment) ~= "table" then return fail("profile Equipment must be a table") end

	local locations: { [string]: number } = {}
	for instanceId, record in value.Items do
		if typeof(instanceId) ~= "string" or instanceId == "" then
			return fail("item instance id must be a nonempty string")
		end
		if typeof(record) ~= "table"
			or typeof(record.ItemId) ~= "string"
			or record.ItemId == ""
			or not finiteInteger(record.Quantity)
			or record.Quantity <= 0
		then
			return fail("item record is invalid")
		end
		locations[instanceId] = 0
	end

	local inventoryCount = 0
	local maximumIndex = 0
	for index, instanceId in value.Inventory do
		if not finiteInteger(index) or index < 1 then
			return fail("Inventory must be a dense array")
		end
		inventoryCount += 1
		maximumIndex = math.max(maximumIndex, index)
		if typeof(instanceId) ~= "string" or locations[instanceId] == nil then
			return fail("Inventory references an unknown item")
		end
		locations[instanceId] += 1
	end
	if inventoryCount ~= maximumIndex then
		return fail("Inventory must not contain holes")
	end
	if inventoryCount > InventoryConfig.Capacity then
		return fail("Inventory exceeds capacity")
	end

	for slot, instanceId in value.Equipment do
		if InventoryConfig.EquipmentSlotSet[slot] ~= true then
			return fail("Equipment contains an unknown slot")
		end
		if instanceId ~= nil then
			if typeof(instanceId) ~= "string" or locations[instanceId] == nil then
				return fail("Equipment references an unknown item")
			end
			local record = value.Items[instanceId]
			if record.Quantity ~= 1 then
				return fail("equipped items must have quantity one")
			end
			locations[instanceId] += 1
		end
	end

	for instanceId, count in locations do
		if count ~= 1 then
			return fail(string.format("item %s must have exactly one canonical location", instanceId))
		end
	end

	return true, nil
end

return table.freeze(ProfileSchema)
