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
		assert(not service:begin({ UserId = 8 }, "c", { placeId = 2, role = "World", entryPointId = "spawn" }))
		assert(failed)
	end)
end
