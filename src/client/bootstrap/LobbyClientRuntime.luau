--!strict

local Components = require(script.Parent.adapters.ExistingClientComponents)

local LobbyClientRuntime = {}
LobbyClientRuntime.__index = LobbyClientRuntime

export type Runtime = typeof(setmetatable({
	stopStockHealth = nil :: (() -> ())?,
	stopLobby = nil :: (() -> ())?,
}, LobbyClientRuntime))

function LobbyClientRuntime.new(): Runtime
	return setmetatable({ stopStockHealth = nil, stopLobby = nil }, LobbyClientRuntime)
end

function LobbyClientRuntime.start(self: Runtime, onEnterWorld: (string) -> ()): ()
	if self.stopLobby ~= nil then
		return
	end
	local stockHealth = Components.stockHealthGui()
	local lobby = Components.characterLobby(onEnterWorld)
	self.stopStockHealth = stockHealth.stop
	self.stopLobby = lobby.stop
	stockHealth.start()
	lobby.start()
end

function LobbyClientRuntime.stop(self: Runtime): ()
	if self.stopLobby ~= nil then
		self.stopLobby()
		self.stopLobby = nil
	end
	if self.stopStockHealth ~= nil then
		self.stopStockHealth()
		self.stopStockHealth = nil
	end
end

return LobbyClientRuntime
