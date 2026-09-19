--!strict

local InventoryConfig = require(script.Parent.Parent.config.InventoryConfig)

local InventoryRequestRules = {}

export type Action = "Equip" | "Unequip" | "Consume" | "Discard"

local VALID_ACTIONS: { [string]: boolean } = {
	Equip = true,
	Unequip = true,
	Consume = true,
	Discard = true,
}

local function validIdentifier(value: unknown): string?
	if typeof(value) ~= "string" or value == "" or #value > InventoryConfig.MaxIdentifierLength then
		return nil
	end
	return value
end

function InventoryRequestRules.validateAction(
	argumentCount: number,
	action: unknown,
	identifier: unknown
): (Action?, string?)
	if argumentCount ~= 2 or typeof(action) ~= "string" or VALID_ACTIONS[action] ~= true then
		return nil, nil
	end
	local safeIdentifier = validIdentifier(identifier)
	if safeIdentifier == nil then return nil, nil end
	return action :: Action, safeIdentifier
end

function InventoryRequestRules.validateSnapshotRequest(argumentCount: number): boolean
	return argumentCount == 0
end

return table.freeze(InventoryRequestRules)
