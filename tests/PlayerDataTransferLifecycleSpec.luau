--!strict

return function(TestRunner)
	local Server = game:GetService("ServerScriptService").Server

	TestRunner.run("stale autosave completion cannot replace transfer release state", function()
		local Rules = require(Server.core.transfer.PlayerDataTransferRules)
		local autosaveOperation = 1
		local releaseOperation = 2
		assert(not Rules.isCurrentOperation(releaseOperation, autosaveOperation))
		assert(Rules.isCurrentOperation(releaseOperation, releaseOperation))
		assert(Rules.canAutosave("CharacterReady"))
		assert(not Rules.canAutosave("Transferring"))
		assert(not Rules.canAutosave("Released"))
	end)

	TestRunner.run("gameplay and account mutations reject Transferring", function()
		local Rules = require(Server.core.transfer.PlayerDataTransferRules)
		assert(Rules.canMutate("AccountReady"))
		assert(Rules.canMutate("CharacterReady"))
		assert(not Rules.canMutate("Transferring"))
		assert(not Rules.canMutate("Saving"))
		assert(not Rules.canMutate("Released"))
	end)

	TestRunner.run("destination activation failure releases lease for next owner", function()
		local Store = require(Server.persistence.SessionProfileStore)
		local Arrival = require(Server.core.transfer.PlaceArrivalService)
		local store = Store.new()
		local source = store:claim(77, "source", 1)
		assert(source.ok)
		assert(store:release(77, "source", source.profile, 2).ok)
		local destination = store:claim(77, "destination", 3)
		assert(destination.ok)

		local payload = { transferVersion = 1, transferId = "t", characterId = "missing", destinationRole = "World", entryPointId = "spawn" }
		local player = { UserId = 77, GetJoinData = function() return { TeleportData = payload } end }
		local service = Arrival.new({
			playerData = {
				selectCharacter = function() return false, "CharacterNotOwned" end,
				confirmArrival = function() error("must not confirm") end,
				failSession = function()
					assert(store:release(77, "destination", destination.profile, 4).ok)
				end,
			},
			intentStore = { consume = function()
				return { transferVersion = 1, transferId = "t", userId = 77, characterId = "missing", sourceRole = "Lobby", destinationRole = "World", entryPointId = "spawn", expiresAt = 20 }
			end },
			destinationRole = "World", clock = function() return 10 end,
		})
		service:_arrive(player)
		assert(store:claim(77, "next-owner", 5).ok)
		assert(not store:save(77, "destination", destination.profile, 6).ok)
	end)

	TestRunner.run("PlayerRemoving during release prevents intent creation", function()
		local Service = require(Server.core.transfer.PlaceTransferService)
		local created = false
		local player = { UserId = 9, Parent = game:GetService("Players") }
		local service = Service.new({
			playerData = {
				getActiveCharacterId = function() return "c" end,
				beginTransfer = function() player.Parent = nil; return true end,
				recoverTransfer = function() error("departed player must not reclaim") end,
			},
			intentStore = { create = function() created = true; return true end },
			gateway = {},
		})
		service.running = true
		assert(not service:begin(player, "c", { placeId = 2, role = "World", entryPointId = "spawn" }))
		assert(not created)
	end)

	TestRunner.run("BindToClose during intent creation removes intent before teleport", function()
		local Service = require(Server.core.transfer.PlaceTransferService)
		local removed, teleported = false, false
		local service
		service = Service.new({
			playerData = {
				getActiveCharacterId = function() return "c" end,
				beginTransfer = function() return true end,
				recoverTransfer = function() return true end,
				failSession = function() end,
			},
			intentStore = {
				create = function() service:stop(); return true end,
				remove = function() removed = true; return true end,
			},
			gateway = {
				onInitFailed = function() return { Disconnect = function() end } end,
				teleport = function() teleported = true; return true end,
			},
		})
		service:start()
		local player = { UserId = 9, Parent = game:GetService("Players") }
		assert(not service:begin(player, "c", { placeId = 2, role = "World", entryPointId = "spawn" }))
		assert(removed and not teleported)
	end)
end
