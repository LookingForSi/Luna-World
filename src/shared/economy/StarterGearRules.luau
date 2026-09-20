--!strict

local EquipmentRules = require(script.Parent.Parent.inventory.EquipmentRules)
local InventoryRules = require(script.Parent.Parent.inventory.InventoryRules)
local PersistenceTypes = require(script.Parent.Parent.types.PersistenceTypes)

local StarterGearRules = {}
local archetypeValues: { [string]: string } = { knight = "weapon_training_sword", ranger = "weapon_ash_bow", mystic = "weapon_ash_staff" }
local byArchetype = table.freeze(archetypeValues)

function StarterGearRules.itemForArchetype(archetypeId: string): string?
	return byArchetype[archetypeId]
end

function StarterGearRules.grantAndEquip(profile: PersistenceTypes.Profile, generateId: () -> string): (PersistenceTypes.Profile?, string?)
	local itemId = byArchetype[profile.ArchetypeId]
	if itemId == nil then return nil, "InvalidArchetype" end
	for instanceId, record in profile.Items do
		if record.ItemId == itemId then
			if profile.Equipment.Weapon == instanceId then return profile, nil end
			if InventoryRules.contains(profile, instanceId) then
				return EquipmentRules.equip(profile, instanceId, profile.ArchetypeId, profile.Level)
			end
			return profile, nil
		end
	end
	local withItem, reason = InventoryRules.add(profile, itemId, 1, generateId)
	if withItem == nil then return nil, reason end
	local instanceId = withItem.Inventory[#withItem.Inventory]
	local equipped, equipReason = EquipmentRules.equip(withItem, instanceId, profile.ArchetypeId, profile.Level)
	if equipped == nil then return nil, equipReason end
	return equipped, nil
end

return table.freeze(StarterGearRules)
