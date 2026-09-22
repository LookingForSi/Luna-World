--!strict

local ClientApplicationState = {}

export type State = "Boot" | "Lobby" | "Transitioning" | "Gameplay" | "Error" | "Disconnected"

ClientApplicationState.Boot = "Boot" :: State
ClientApplicationState.Lobby = "Lobby" :: State
ClientApplicationState.Transitioning = "Transitioning" :: State
ClientApplicationState.Gameplay = "Gameplay" :: State
ClientApplicationState.Error = "Error" :: State
ClientApplicationState.Disconnected = "Disconnected" :: State

local allowed: { [State]: { [State]: boolean } } = {
	Boot = { Lobby = true, Transitioning = true, Error = true, Disconnected = true },
	Lobby = { Transitioning = true, Error = true, Disconnected = true },
	Transitioning = { Lobby = true, Gameplay = true, Error = true, Disconnected = true },
	Gameplay = { Error = true, Disconnected = true },
	Error = { Disconnected = true },
	Disconnected = {},
}

function ClientApplicationState.canTransition(from: State, to: State): boolean
	return allowed[from][to] == true
end

return table.freeze(ClientApplicationState)
