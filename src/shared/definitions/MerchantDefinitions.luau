--!strict

local stock = {
	"consumable_minor_healing_draught", "consumable_minor_resource_draught", "consumable_scroll_return_luna",
}

return table.freeze({ Stock = table.freeze(stock), BuybackRatio = 0.60, CraftMarkup = 1.30 })
