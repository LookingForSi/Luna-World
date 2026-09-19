--!strict

local LootTypes = require(script.Parent.Parent.types.LootTypes)

local LootRules = {}

local function finite(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local function rollInteger(minimum: number, maximum: number, randomUnit: () -> number): number
	assert(minimum % 1 == 0 and maximum % 1 == 0 and minimum <= maximum, "loot integer range is invalid")
	if minimum == maximum then return minimum end
	local roll = randomUnit()
	assert(finite(roll) and roll >= 0 and roll < 1, "random source must return [0, 1)")
	return minimum + math.floor(roll * (maximum - minimum + 1))
end

function LootRules.roll(definition: LootTypes.LootTableDefinition, randomUnit: () -> number): LootTypes.RollResult
	local luna = rollInteger(definition.lunaMin, definition.lunaMax, randomUnit)
	local items: { LootTypes.ItemReward } = {}

	for _, entry in definition.entries do
		assert(finite(entry.chance) and entry.chance >= 0 and entry.chance <= 1, "loot chance must be within [0, 1]")
		local chanceRoll = randomUnit()
		assert(finite(chanceRoll) and chanceRoll >= 0 and chanceRoll < 1, "random source must return [0, 1)")
		if chanceRoll < entry.chance then
			table.insert(items, {
				itemId = entry.itemId,
				quantity = rollInteger(entry.minQuantity, entry.maxQuantity, randomUnit),
			})
		end
	end

	return {
		luna = luna,
		items = items,
	}
end

return table.freeze(LootRules)
