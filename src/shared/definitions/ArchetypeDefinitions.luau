--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

local definitions: { [string]: CombatTypes.ArchetypeDefinition } = {
	knight = {
		id = "knight",
		displayName = "Рыцарь",
		resourceType = "Stamina",
		basicAttackId = "knight_basic_attack",
		skillIds = table.freeze({ "power_strike", "shield_bash", "defensive_stance" }),
	},
	ranger = {
		id = "ranger",
		displayName = "Следопыт",
		resourceType = "Focus",
		basicAttackId = "ranger_basic_attack",
		skillIds = table.freeze({ "power_shot", "rapid_shot", "snare" }),
	},
	mystic = {
		id = "mystic",
		displayName = "Мистик",
		resourceType = "Mana",
		basicAttackId = "mystic_basic_attack",
		skillIds = table.freeze({ "arcane_bolt", "flame_burst", "heal" }),
	},
}

return table.freeze(definitions)
