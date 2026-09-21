--!strict

local EquipmentRules = require(script.Parent.Parent.inventory.EquipmentRules)
local InventoryRules = require(script.Parent.Parent.inventory.InventoryRules)
local ItemDefinitions = require(script.Parent.Parent.definitions.ItemDefinitions)
local ProfileSchema = require(script.Parent.Parent.persistence.ProfileSchema)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local StarterGearRules = {}
local archetypeValues: { [string]: string } = { knight = "weapon_training_sword", ranger = "weapon_ash_bow", mystic = "weapon_ash_staff" }
local byArchetype = table.freeze(archetypeValues)

function StarterGearRules.itemForArchetype(archetypeId: string): string?
	return byArchetype[archetypeId]
end

local function equippedWeaponMatchesArchetype(profile: PersistenceTypes.Profile, archetypeId: string): boolean
	local instanceId = profile.Equipment.Weapon
	if instanceId == nil then return false end
	local record = profile.Items[instanceId]
	local definition = if record ~= nil then ItemDefinitions[record.ItemId] else nil
	if definition == nil or definition.equipmentSlot ~= "Weapon" then return false end
	local allowed = definition.allowedArchetypes
	if allowed == nil then return true end
	for _, candidate in allowed do
		if candidate == archetypeId then return true end
	end
	return false
end

function StarterGearRules.grantAndEquipForArchetype(
	profile: PersistenceTypes.Profile,
	archetypeId: string,
	generateId: () -> string,
	forceStarterWeapon: boolean?
): (PersistenceTypes.Profile?, string?)
	local itemId = byArchetype[archetypeId]
	if itemId == nil then return nil, "InvalidArchetype" end
	-- Normal login must never downgrade a character that already has a valid
	-- class weapon equipped. We only repair missing/incompatible legacy weapons.
	if forceStarterWeapon ~= true and equippedWeaponMatchesArchetype(profile, archetypeId) then
		return profile, nil
	end
	for instanceId, record in profile.Items do
		if record.ItemId == itemId then
			if profile.Equipment.Weapon == instanceId then return profile, nil end
			if InventoryRules.contains(profile, instanceId) then
				return EquipmentRules.equip(profile, instanceId, archetypeId, profile.Level)
			end
			return profile, nil
		end
	end
	local withItem, reason = InventoryRules.add(profile, itemId, 1, generateId)
	if withItem == nil then return nil, reason end
	local instanceId = withItem.Inventory[#withItem.Inventory]
	local equipped, equipReason = EquipmentRules.equip(withItem, instanceId, archetypeId, profile.Level)
	if equipped == nil then return nil, equipReason end
	return equipped, nil
end

function StarterGearRules.grantAndEquip(profile: PersistenceTypes.Profile, generateId: () -> string): (PersistenceTypes.Profile?, string?)
	return StarterGearRules.grantAndEquipForArchetype(profile, profile.ArchetypeId, generateId)
end

function StarterGearRules.switchArchetype(
	profile: PersistenceTypes.Profile,
	archetypeId: string,
	generateId: () -> string
): (PersistenceTypes.Profile?, string?)
	if byArchetype[archetypeId] == nil then return nil, "InvalidArchetype" end
	local staged = ProfileSchema.clone(profile)
	staged.ArchetypeId = archetypeId
	return StarterGearRules.grantAndEquipForArchetype(staged, archetypeId, generateId, true)
end

return table.freeze(StarterGearRules)
