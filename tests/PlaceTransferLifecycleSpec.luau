--!strict

return function(TestRunner)
	TestRunner.test("transfer routing payload excludes authoritative state", function()
		local Rules = require(game:GetService("ReplicatedStorage").Shared.core.transfer.TransferIntentRules)
		local payload = Rules.routingPayload({
			transferId = "transfer-1", characterId = "character-1", destinationRole = "World",
			entryPointId = "luna_village", Luna = 999, XP = 999,
		})
		assert(payload.Luna == nil and payload.XP == nil)
		assert(Rules.validateRouting(payload, "World"))
		assert(not Rules.validateRouting(payload, "Dungeon"))
	end)

	TestRunner.test("transfer intent is consumed once and expires", function()
		local Store = require(game:GetService("ServerScriptService").Server.core.transfer.InMemoryTransferIntentStore)
		local now = 10
		local store = Store.new(function() return now end)
		assert(store:create({ transferId = "one", expiresAt = 20 }, 10))
		assert(not store:create({ transferId = "one", expiresAt = 20 }, 10))
		assert(store:consume("one") ~= nil)
		assert(store:consume("one") == nil)
		assert(store:create({ transferId = "expired", expiresAt = 10 }, 10))
		assert(store:consume("expired") == nil)
	end)

	TestRunner.test("mismatched consume does not destroy a valid intent", function()
		local Store = require(game:GetService("ServerScriptService").Server.core.transfer.InMemoryTransferIntentStore)
		local store = Store.new(function() return 10 end)
		assert(store:create({ transferId = "one", userId = 7, characterId = "owned", expiresAt = 20 }, 10))
		local stolen, reason = store:consume("one", { userId = 8 })
		assert(stolen == nil and reason == "Mismatch")
		local valid = store:consume("one", { userId = 7, characterId = "owned" })
		assert(valid ~= nil)
	end)

	TestRunner.test("source orders release, intent, gateway and rejects concurrent entry", function()
		local Service = require(game:GetService("ServerScriptService").Server.core.transfer.PlaceTransferService)
		local calls = {}
		local data = {
			getActiveCharacterId = function() return "character-1" end,
			beginTransfer = function() table.insert(calls, "release"); return true end,
			recoverTransfer = function() table.insert(calls, "recover"); return true end,
			failSession = function() table.insert(calls, "error") end,
		}
		local intents = {
			create = function() table.insert(calls, "intent"); return true end,
			remove = function() table.insert(calls, "remove"); return true end,
		}
		local gateway = { teleport = function() table.insert(calls, "teleport"); return true end }
		local service = Service.new({ playerData = data, intentStore = intents, gateway = gateway, clock = function() return 1 end })
		service.running = true
		local player = { UserId = 42 }
		assert(service:begin(player, "character-1", { placeId = 2, role = "World", entryPointId = "luna_village" }))
		assert(table.concat(calls, ",") == "release,intent,teleport")
		local duplicate, reason = service:begin(player, "character-1", { placeId = 2, role = "World", entryPointId = "luna_village" })
		assert(not duplicate and reason == "TransferInProgress")
	end)

	TestRunner.test("synchronous gateway failure removes intent before safe recovery", function()
		local Service = require(game:GetService("ServerScriptService").Server.core.transfer.PlaceTransferService)
		local calls = {}
		local service = Service.new({
			playerData = {
				getActiveCharacterId = function() return "c" end,
				beginTransfer = function() return true end,
				recoverTransfer = function() table.insert(calls, "recover"); return true end,
				failSession = function() table.insert(calls, "error") end,
			},
			intentStore = {
				create = function() return true end,
				remove = function() table.insert(calls, "remove"); return true end,
			},
			gateway = { teleport = function() return false, "GatewayFailed" end },
		})
		service.running = true
		local ok = service:begin({ UserId = 7 }, "c", { placeId = 2, role = "World", entryPointId = "spawn" })
		assert(not ok and table.concat(calls, ",") == "remove,recover")
	end)

	TestRunner.test("cleanup failure is fail closed", function()
		local Service = require(game:GetService("ServerScriptService").Server.core.transfer.PlaceTransferService)
		local failed = false
		local service = Service.new({
			playerData = {
				getActiveCharacterId = function() return "c" end, beginTransfer = function() return true end,
				recoverTransfer = function() error("must not reclaim") end,
				failSession = function() failed = true end,
			},
			intentStore = { create = function() return true end, remove = function() return false, "StoreError" end },
			gateway = { teleport = function() return false, "GatewayFailed" end },
		})
		service.running = true
		assert(not service:begin({ UserId = 8 }, "c", { placeId = 2, role = "World", entryPointId = "spawn" }))
		assert(failed)
	end)

	TestRunner.test("shutdown during release cancels before intent creation", function()
		local Service = require(game:GetService("ServerScriptService").Server.core.transfer.PlaceTransferService)
		local created, teleported = false, false
		local service
		local data = {
			getActiveCharacterId = function() return "c" end,
			beginTransfer = function() service:stop(); return true end,
			recoverTransfer = function() return true end,
			failSession = function() end,
		}
		service = Service.new({
			playerData = data,
			intentStore = { create = function() created = true; return true end, remove = function() return true end },
			gateway = {
				onInitFailed = function() return { Disconnect = function() end } end,
				teleport = function() teleported = true; return true end,
			},
		})
		service:start()
		local player = { UserId = 7, Parent = game:GetService("Players") }
		local ok, reason = service:begin(player, "c", { placeId = 2, role = "World", entryPointId = "spawn" })
		assert(not ok and reason == "TransferCancelled" and not created and not teleported)
	end)

	TestRunner.test("destination confirms arrival only after matched intent and activation", function()
		local Arrival = require(game:GetService("ServerScriptService").Server.core.transfer.PlaceArrivalService)
		local calls = {}
		local payload = { transferVersion = 1, transferId = "t", characterId = "c", destinationRole = "World", entryPointId = "spawn" }
		local player = { UserId = 7, GetJoinData = function() return { TeleportData = payload } end }
		local service = Arrival.new({
			playerData = {
				selectCharacter = function(_, _, id) table.insert(calls, "select:" .. id); return true end,
				confirmArrival = function() table.insert(calls, "confirm"); return true end,
				failSession = function() table.insert(calls, "fail") end,
			},
			intentStore = { consume = function(_, _, expected)
				assert(expected.userId == 7 and expected.characterId == "c" and expected.entryPointId == "spawn")
				return { transferVersion = 1, transferId = "t", userId = 7, characterId = "c", sourceRole = "Lobby", destinationRole = "World", entryPointId = "spawn", expiresAt = 20 }
			end },
			destinationRole = "World", clock = function() return 10 end,
		})
		service:_arrive(player)
		assert(table.concat(calls, ",") == "select:c,confirm")
	end)

	TestRunner.test("destination releases its claim after post-claim validation failure", function()
		local Arrival = require(game:GetService("ServerScriptService").Server.core.transfer.PlaceArrivalService)
		local failed = false
		local payload = { transferVersion = 1, transferId = "t", characterId = "forged", destinationRole = "World", entryPointId = "spawn" }
		local player = { UserId = 7, GetJoinData = function() return { TeleportData = payload } end }
		local service = Arrival.new({
			playerData = {
				selectCharacter = function() error("must not activate") end,
				confirmArrival = function() error("must not confirm") end,
				failSession = function() failed = true end,
			},
			intentStore = { consume = function() return nil, "Mismatch" end },
			destinationRole = "World", clock = function() return 10 end,
		})
		service:_arrive(player)
		assert(failed)
	end)
end
