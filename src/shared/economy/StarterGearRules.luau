--!strict

local EquipmentRules = require(script.Parent.Parent.inventory.EquipmentRules)
local InventoryRules = require(script.Parent.Parent.inventory.InventoryRules)
local ProfileSchema = require(script.Parent.Parent.persistence.ProfileSchema)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local StarterGearRules = {}
local archetypeValues: { [string]: string } = { knight = "weapon_training_sword", ranger = "weapon_ash_bow", mystic = "weapon_ash_staff" }
local byArchetype = table.freeze(archetypeValues)

function StarterGearRules.itemForArchetype(archetypeId: string): string?
	return byArchetype[archetypeId]
end

function StarterGearRules.grantAndEquipForArchetype(
	profile: PersistenceTypes.Profile,
	archetypeId: string,
	generateId: () -> string
): (PersistenceTypes.Profile?, string?)
	local itemId = byArchetype[archetypeId]
	if itemId == nil then return nil, "InvalidArchetype" end
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
	return StarterGearRules.grantAndEquipForArchetype(staged, archetypeId, generateId)
end

return table.freeze(StarterGearRules)
