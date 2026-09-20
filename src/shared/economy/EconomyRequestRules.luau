--!strict

local EconomyRequestRules = {}
local actionValues: { [string]: boolean } = { Buy = true, Sell = true, Craft = true }
local actions = table.freeze(actionValues)

function EconomyRequestRules.validateSellBatch(
	argumentCount: number,
	action: unknown,
	selections: unknown
): { any }?
	if argumentCount ~= 2 or action ~= "SellBatch" or typeof(selections) ~= "table" then return nil end
	local rows: any = selections
	local rowCount = #rows
	if rowCount < 1 or rowCount > 40 then return nil end
	local keyCount = 0
	for key in rows do
		keyCount += 1
		if typeof(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > rowCount then return nil end
	end
	if keyCount ~= rowCount then return nil end

	local normalized = {}
	local seen: { [string]: boolean } = {}
	for index = 1, rowCount do
		local row = rows[index]
		if typeof(row) ~= "table" then return nil end
		local instanceId = row.instanceId
		local quantity = row.quantity
		if typeof(instanceId) ~= "string" or instanceId == "" or #instanceId > 96 or seen[instanceId] then return nil end
		if typeof(quantity) ~= "number"
			or quantity ~= quantity
			or quantity <= 0
			or quantity == math.huge
			or quantity % 1 ~= 0
		then
			return nil
		end
		seen[instanceId] = true
		table.insert(normalized, { instanceId = instanceId, quantity = quantity })
	end
	return normalized
end

function EconomyRequestRules.validate(argumentCount: number, action: unknown, identifier: unknown, quantity: unknown): (string?, string?, number?)
	if argumentCount < 2 or argumentCount > 3 or typeof(action) ~= "string" or actions[action] ~= true then return nil, nil, nil end
	if typeof(identifier) ~= "string" or identifier == "" or #identifier > 96 then return nil, nil, nil end
	local normalized = if quantity == nil then 1 else quantity
	if typeof(normalized) ~= "number" or normalized ~= normalized or normalized <= 0 or normalized == math.huge or normalized % 1 ~= 0 then return nil, nil, nil end
	if action == "Craft" and normalized ~= 1 then return nil, nil, nil end
	return action, identifier, normalized
end

return table.freeze(EconomyRequestRules)
