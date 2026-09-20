--!strict

local EconomyRequestRules = {}
local actionValues: { [string]: boolean } = { Buy = true, Sell = true, Craft = true }
local actions = table.freeze(actionValues)

function EconomyRequestRules.validate(argumentCount: number, action: unknown, identifier: unknown, quantity: unknown): (string?, string?, number?)
	if argumentCount < 2 or argumentCount > 3 or typeof(action) ~= "string" or actions[action] ~= true then return nil, nil, nil end
	if typeof(identifier) ~= "string" or identifier == "" or #identifier > 96 then return nil, nil, nil end
	local normalized = if quantity == nil then 1 else quantity
	if typeof(normalized) ~= "number" or normalized ~= normalized or normalized <= 0 or normalized == math.huge or normalized % 1 ~= 0 then return nil, nil, nil end
	if action == "Craft" and normalized ~= 1 then return nil, nil, nil end
	return action, identifier, normalized
end

return table.freeze(EconomyRequestRules)
