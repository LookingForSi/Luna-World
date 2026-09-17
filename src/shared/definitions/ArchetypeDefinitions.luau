--!strict

local CombatTypes = require(script.Parent.Parent.types.CombatTypes)

local definitions: { [string]: CombatTypes.ArchetypeDefinition } = {
	knight = {
		id = "knight",
		displayName = "Рыцарь",
		resourceType = "Stamina",
		basicAttackId = "knight_basic_attack",
	},
	ranger = {
		id = "ranger",
		displayName = "Следопыт",
		resourceType = "Focus",
		basicAttackId = "ranger_basic_attack",
	},
	mystic = {
		id = "mystic",
		displayName = "Мистик",
		resourceType = "Mana",
		basicAttackId = "mystic_basic_attack",
	},
}

return table.freeze(definitions)
