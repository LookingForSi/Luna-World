--!strict

local PlaceRole = {}

export type PlaceRole = "Lobby" | "World" | "Dungeon" | "DevCombined"

PlaceRole.Lobby = "Lobby"
PlaceRole.World = "World"
PlaceRole.Dungeon = "Dungeon"
PlaceRole.DevCombined = "DevCombined"

function PlaceRole.isValid(value: any): boolean
	return value == PlaceRole.Lobby
		or value == PlaceRole.World
		or value == PlaceRole.Dungeon
		or value == PlaceRole.DevCombined
end

function PlaceRole.assertValid(value: any): PlaceRole
	assert(PlaceRole.isValid(value), string.format("Unknown PlaceRole: %s", tostring(value)))
	return value :: PlaceRole
end

return table.freeze(PlaceRole)
