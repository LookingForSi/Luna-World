--!strict

local Players = game:GetService("Players")

local State = require(script.Parent.ClientApplicationState)
local ArrivalReadyGate = require(script.Parent.ArrivalReadyGate)

local ClientApplication = {}
ClientApplication.__index = ClientApplication

export type Runtime = {
	start: (self: any, ...any) -> (),
	stop: (self: any) -> (),
}

export type TransitionAdapter = {
	enterWorld: (characterId: string) -> (boolean, string?),
}

export type InitialContext = {
	mode: "Lobby" | "World" | "Dungeon" | "DevCombined",
}

export type Application = typeof(setmetatable(
	{} :: {
		state: State.State,
		lobby: Runtime,
		gameplay: Runtime,
		adapter: TransitionAdapter,
		gate: ArrivalReadyGate.Gate?,
		characterReadyConnection: RBXScriptConnection?,
		arrivalReadyConnection: RBXScriptConnection?,
		mode: ("Lobby" | "World" | "Dungeon" | "DevCombined")?,
		player: any,
		errorReason: string?,
	},
	ClientApplication
))

function ClientApplication.new(lobby: Runtime, gameplay: Runtime, adapter: TransitionAdapter, playerOverride: any?): Application
	return setmetatable({
		state = State.Boot,
		lobby = lobby,
		gameplay = gameplay,
		adapter = adapter,
		gate = nil,
		characterReadyConnection = nil,
		arrivalReadyConnection = nil,
		mode = nil,
		player = playerOverride or Players.LocalPlayer,
		errorReason = nil,
	}, ClientApplication)
end

function ClientApplication.getState(self: Application): State.State
	return self.state
end

function ClientApplication._setState(self: Application, nextState: State.State): ()
	assert(State.canTransition(self.state, nextState), string.format("Invalid client transition %s -> %s", self.state, nextState))
	self.state = nextState
end

function ClientApplication._fail(self: Application, reason: any): ()
	if self.characterReadyConnection ~= nil then
		self.characterReadyConnection:Disconnect()
		self.characterReadyConnection = nil
	end
	if self.arrivalReadyConnection ~= nil then
		self.arrivalReadyConnection:Disconnect()
		self.arrivalReadyConnection = nil
	end
	if self.gate ~= nil then
		self.gate:destroy()
		self.gate = nil
	end
	pcall(function()
		self.gameplay:stop()
	end)
	pcall(function()
		self.lobby:stop()
	end)
	if self.state ~= State.Error then
		self:_setState(State.Error)
	end
	self.errorReason = tostring(reason)
end

function ClientApplication._beginReadiness(self: Application): ()
	local player = self.player
	local gate = ArrivalReadyGate.new(function()
		if self.state ~= State.Transitioning then
			return
		end
		if self.characterReadyConnection ~= nil then
			self.characterReadyConnection:Disconnect()
			self.characterReadyConnection = nil
		end
		if self.arrivalReadyConnection ~= nil then
			self.arrivalReadyConnection:Disconnect()
			self.arrivalReadyConnection = nil
		end
		local lobbyStopped, lobbyStopError = pcall(function()
			self.lobby:stop()
		end)
		if not lobbyStopped then
			self:_fail(lobbyStopError)
			return
		end
		local ok, startError = pcall(function()
			self.gameplay:start()
		end)
		if not ok then
			self:_fail(startError)
			return
		end
		self:_setState(State.Gameplay)
	end)
	self.gate = gate
	self.characterReadyConnection = player:GetAttributeChangedSignal("CharacterReady"):Connect(function()
		gate:setCharacterReady(player:GetAttribute("CharacterReady") == true)
	end)
	self.arrivalReadyConnection = player:GetAttributeChangedSignal("ArrivalReady"):Connect(function()
		gate:setArrivalReady(player:GetAttribute("ArrivalReady") == true)
	end)
	gate:setArrivalReady(player:GetAttribute("ArrivalReady") == true)
	gate:setCharacterReady(player:GetAttribute("CharacterReady") == true)
end

function ClientApplication.transition(self: Application, nextState: State.State, context: any?): (boolean, string?)
	if nextState == self.state then
		return true, nil
	end
	if not State.canTransition(self.state, nextState) then
		return false, string.format("InvalidTransition:%s:%s", self.state, nextState)
	end
	if nextState == State.Transitioning then
		if typeof(context) ~= "table" or typeof(context.characterId) ~= "string" or context.characterId == "" then
			return false, "InvalidCharacterId"
		end
		self:_setState(State.Transitioning)
		local callOk, transitionOk, reason = pcall(self.adapter.enterWorld, context.characterId)
		if not callOk or not transitionOk then
			self:_fail(if callOk then reason else transitionOk)
			return false, self.errorReason
		end
		return true, nil
	end
	return false, "TransitionRequiresLifecycleContext"
end

function ClientApplication.start(self: Application, context: InitialContext): (boolean, string?)
	if self.state ~= State.Boot then
		return false, "ApplicationAlreadyStarted"
	end
	self.mode = context.mode
	if context.mode == "Lobby" or context.mode == "DevCombined" then
		self:_setState(State.Lobby)
		if context.mode == "DevCombined" then
			self:_beginReadiness()
		end
		local ok, startError = pcall(function()
			self.lobby:start(function(characterId: string)
				if context.mode == "DevCombined" then
					self:transition(State.Transitioning, { characterId = characterId })
				else
					self.adapter.enterWorld(characterId)
				end
			end)
		end)
		if not ok then
			self:_fail(startError)
			return false, self.errorReason
		end
		return true, nil
	end
	if context.mode == "World" or context.mode == "Dungeon" then
		self:_setState(State.Transitioning)
		self:_beginReadiness()
		return true, nil
	end
	self:_fail("Unsupported client application mode")
	return false, self.errorReason
end

function ClientApplication.stop(self: Application): ()
	if self.state == State.Disconnected then
		return
	end
	if self.characterReadyConnection ~= nil then
		self.characterReadyConnection:Disconnect()
		self.characterReadyConnection = nil
	end
	if self.arrivalReadyConnection ~= nil then
		self.arrivalReadyConnection:Disconnect()
		self.arrivalReadyConnection = nil
	end
	if self.gate ~= nil then
		self.gate:destroy()
		self.gate = nil
	end
	pcall(function()
		self.gameplay:stop()
	end)
	pcall(function()
		self.lobby:stop()
	end)
	self:_setState(State.Disconnected)
end

return ClientApplication
