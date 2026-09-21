--!strict
local ApplicationState = {
	Boot = "Boot",
	Lobby = "Lobby",
	Transitioning = "Transitioning",
	Gameplay = "Gameplay",
	Error = "Error",
	Disconnected = "Disconnected",
}

export type State = "Boot" | "Lobby" | "Transitioning" | "Gameplay" | "Error" | "Disconnected"

local allowed = {
	Boot = { Lobby = true, Transitioning = true, Error = true },
	Lobby = { Transitioning = true, Error = true, Disconnected = true },
	Transitioning = { Lobby = true, Gameplay = true, Error = true, Disconnected = true },
	Gameplay = { Error = true, Disconnected = true },
	Error = { Lobby = true, Disconnected = true },
	Disconnected = {},
}

function ApplicationState.canTransition(from: State, to: State): boolean
	return allowed[from][to] == true
end

return table.freeze(ApplicationState)
