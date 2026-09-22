--!nonstrict

return function(TestRunner)
	local root = game:GetService("StarterPlayer").StarterPlayerScripts.Client.bootstrap
	local State = require(root.ClientApplicationState)
	local Gate = require(root.ArrivalReadyGate)
	local Application = require(root.ClientApplication)

	local function fakePlayer()
		local attributes = { CharacterReady = false, ArrivalReady = false }
		local callbacks = { CharacterReady = {}, ArrivalReady = {} }
		local player = {}
		function player:GetAttribute(name)
			return attributes[name]
		end
		function player:GetAttributeChangedSignal(name)
			return {
				Connect = function(_signal, callback)
					table.insert(callbacks[name], callback)
					local connected = true
					return {
						Disconnect = function()
							connected = false
						end,
						_isConnected = function()
							return connected
						end,
					}
				end,
			}
		end
		local function set(name, value)
			attributes[name] = value
			for _, callback in callbacks[name] do
				callback()
			end
		end
		return player, set
	end

	local function runtime(startFn, stopFn)
		local value = { starts = 0, stops = 0 }
		function value:start(...)
			self.starts += 1
			if startFn ~= nil then
				startFn(...)
			end
		end
		function value:stop()
			self.stops += 1
			if stopFn ~= nil then
				stopFn()
			end
		end
		return value
	end

	TestRunner.run("client application state allows only lifecycle transitions", function()
		assert(State.canTransition(State.Boot, State.Lobby))
		assert(State.canTransition(State.Lobby, State.Transitioning))
		assert(State.canTransition(State.Transitioning, State.Gameplay))
		assert(State.canTransition(State.Gameplay, State.Disconnected))
		assert(not State.canTransition(State.Lobby, State.Gameplay))
		assert(not State.canTransition(State.Gameplay, State.Lobby))
		assert(not State.canTransition(State.Disconnected, State.Boot))
	end)

	TestRunner.run("arrival gate opens once after both authoritative signals", function()
		local calls = 0
		local gate = Gate.new(function()
			calls += 1
		end)
		gate:setCharacterReady(true)
		assert(calls == 0)
		gate:setArrivalReady(true)
		gate:setArrivalReady(true)
		gate:setCharacterReady(true)
		assert(calls == 1)
	end)

	TestRunner.run("destroyed arrival gate never opens", function()
		local calls = 0
		local gate = Gate.new(function()
			calls += 1
		end)
		gate:setCharacterReady(true)
		gate:destroy()
		gate:setArrivalReady(true)
		assert(calls == 0)
	end)

	TestRunner.run("application waits for both signals and enters gameplay once", function()
		local player, setReady = fakePlayer()
		local enterWorld
		local lobby = runtime(function(callback)
			enterWorld = callback
		end)
		local gameplay = runtime(nil)
		local adapterCalls = 0
		local app = Application.new(lobby, gameplay, {
			enterWorld = function(_characterId)
				adapterCalls += 1
				return true, nil
			end,
		}, player)
		assert(app:start({ mode = "DevCombined" }))
		enterWorld("hero-1")
		enterWorld("hero-1")
		assert(adapterCalls == 1)
		setReady("CharacterReady", true)
		assert(gameplay.starts == 0)
		setReady("ArrivalReady", true)
		assert(gameplay.starts == 1)
		assert(app:getState() == State.Gameplay)
		app:stop()
		app:stop()
		assert(gameplay.stops == 1)
	end)

	TestRunner.run("application rolls back runtime and readiness on adapter error", function()
		local player = fakePlayer()
		local enterWorld
		local lobby = runtime(function(callback)
			enterWorld = callback
		end)
		local gameplay = runtime(nil)
		local app = Application.new(lobby, gameplay, {
			enterWorld = function(_characterId)
				error("adapter failed")
			end,
		}, player)
		assert(app:start({ mode = "DevCombined" }))
		enterWorld("hero-1")
		assert(app:getState() == State.Error)
		assert(lobby.stops == 1)
		assert(gameplay.stops == 1)
		assert(app.characterReadyConnection == nil)
		assert(app.arrivalReadyConnection == nil)
		assert(app.gate == nil)
	end)

	TestRunner.run("application rolls back a failed gameplay start", function()
		local player, setReady = fakePlayer()
		local lobby = runtime(nil)
		local gameplay = runtime(function()
			error("gameplay failed")
		end)
		local app = Application.new(lobby, gameplay, { enterWorld = function() return true, nil end }, player)
		assert(app:start({ mode = "World" }))
		setReady("CharacterReady", true)
		setReady("ArrivalReady", true)
		assert(app:getState() == State.Error)
		assert(gameplay.stops == 1)
	end)

	TestRunner.run("application reaches Error when lobby cleanup throws", function()
		local player, setReady = fakePlayer()
		local lobby = runtime(nil, function()
			error("lobby stop failed")
		end)
		local gameplay = runtime(nil)
		local app = Application.new(lobby, gameplay, { enterWorld = function() return true, nil end }, player)
		assert(app:start({ mode = "World" }))
		setReady("CharacterReady", true)
		setReady("ArrivalReady", true)
		assert(app:getState() == State.Error)
		assert(gameplay.stops == 1)
	end)
end
