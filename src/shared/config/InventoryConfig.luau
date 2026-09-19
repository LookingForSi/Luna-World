--!strict

local slots = table.freeze({ "Weapon", "Head", "Chest", "Gloves", "Boots", "Accessory" })

local slotSet = {}
for _, slot in slots do
	slotSet[slot] = true
end

return table.freeze({
	Capacity = 40,
	DefaultStackLimit = 99,
	MaxIdentifierLength = 128,
	ActionRequestMinIntervalSeconds = 0.08,
	SnapshotRequestMinIntervalSeconds = 0.25,
	ConsumableCooldownSeconds = 5,
	EquipmentSlots = slots,
	EquipmentSlotSet = table.freeze(slotSet),
})
