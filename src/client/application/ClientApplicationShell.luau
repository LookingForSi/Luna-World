--!strict
local ApplicationState = require(script.Parent.ApplicationState)
local ClientApplicationShell = {}; ClientApplicationShell.__index = ClientApplicationShell
export type Shell = typeof(setmetatable({} :: { state: ApplicationState.State, lobby: any, gameplay: any, transition: any, errorReason: string? }, ClientApplicationShell))
function ClientApplicationShell.new(lobby: any, gameplay: any, transition: any): Shell
	return setmetatable({ state = ApplicationState.Boot, lobby = lobby, gameplay = gameplay, transition = transition, errorReason = nil }, ClientApplicationShell)
end
function ClientApplicationShell._set(self: Shell, nextState: ApplicationState.State): () assert(ApplicationState.canTransition(self.state, nextState), `invalid transition {self.state} -> {nextState}`); self.state = nextState end
function ClientApplicationShell.startLobby(self: Shell): (boolean, string?)
	if self.state == ApplicationState.Lobby then return true end
	self:_set(ApplicationState.Lobby); local ok, reason = self.lobby:start(); if not ok then self.state = ApplicationState.Error; self.errorReason = reason end; return ok, reason
end
function ClientApplicationShell.enterGameplay(self: Shell, characterId: string): (boolean, string?)
	if self.state == ApplicationState.Gameplay or self.state == ApplicationState.Transitioning then return true end
	self:_set(ApplicationState.Transitioning)
	local transitionOk, transitionReason = pcall(self.transition, characterId)
	if not transitionOk then self.state = ApplicationState.Error; self.errorReason = tostring(transitionReason); return false, self.errorReason end
	self.lobby:stop(); local ok, reason = self.gameplay:start()
	if not ok then self.gameplay:stop(); self.state = ApplicationState.Error; self.errorReason = reason; return false, reason end
	self:_set(ApplicationState.Gameplay); return true
end
function ClientApplicationShell.stop(self: Shell): () self.gameplay:stop(); self.lobby:stop(); self.state = ApplicationState.Disconnected end
return ClientApplicationShell
