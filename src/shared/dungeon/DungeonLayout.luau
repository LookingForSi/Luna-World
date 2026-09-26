--!strict

local Layout = {}

Layout.DevCombinedOffset = Vector3.new(0, 500, -12000)
Layout.FloorY = 0
Layout.OutOfBoundsY = -60
Layout.RouteMinZ = -55
Layout.RouteMaxZ = 695
Layout.CorridorWidth = 90
Layout.RouteHalfWidth = Layout.CorridorWidth * 0.5 + 4

Layout.Rooms = table.freeze({
	{ id = "Entrance", displayName = "Безопасный вход", startZ = -50, endZ = 50, width = Layout.CorridorWidth },
	{ id = "Pack1", displayName = "Внешний зал", startZ = 50, endZ = 170, width = Layout.CorridorWidth },
	{ id = "Miniboss", displayName = "Зал Стража руин", startZ = 170, endZ = 310, width = Layout.CorridorWidth },
	{ id = "Pack2", displayName = "Внутреннее святилище", startZ = 310, endZ = 450, width = Layout.CorridorWidth },
	{ id = "Guardian", displayName = "Арена Падшего Стража", startZ = 450, endZ = 610, width = Layout.CorridorWidth },
	{ id = "Exit", displayName = "Выход", startZ = 610, endZ = 690, width = Layout.CorridorWidth },
})

Layout.GateZ = table.freeze({ 170, 310, 450 })
Layout.EncounterPositions = table.freeze({
	Vector3.new(0, 5, 110),
	Vector3.new(0, 5, 240),
	Vector3.new(0, 5, 380),
	Vector3.new(0, 5, 530),
})
Layout.CheckpointPositions = table.freeze({
	Vector3.new(0, 1, 0),
	Vector3.new(0, 1, 190),
	Vector3.new(0, 1, 330),
	Vector3.new(0, 1, 470),
})
Layout.EntrancePosition = Vector3.new(0, 1, 0)
Layout.ExitPosition = Vector3.new(0, 1, 650)

return table.freeze(Layout)
