--!strict

local PresentationRules = require(game.ReplicatedStorage.Shared.combat.CombatPresentationRules)
local PresentationService = require(game.ServerScriptService.Server.services.CombatPresentationService)

return function(TestRunner)
	TestRunner.run("presentation delivery cannot mutate authoritative state", function()
		local authority = { health = 100, resource = 50 }
		local delivered = 0
		local message = PresentationRules.create("Result", "action", "player:1", 123, { amount = 10, outcome = "Applied" })
		assert(PresentationService.deliver(message, function(received)
			delivered += 1
			assert(received.actionId == "action")
		end))
		assert(delivered == 1)
		assert(authority.health == 100 and authority.resource == 50)
	end)

	TestRunner.run("rejection routing addresses only its requesting player", function()
		local requestingPlayer = Instance.new("Player")
		local deliveries = 0
		local message = PresentationRules.create("Result", "request", "player:1", 123, {
			outcome = "Rejected", reasonCode = "RateLimited",
		})
		assert(PresentationService.deliverToPlayer(requestingPlayer, message, function(recipient, received)
			deliveries += 1
			assert(recipient == requestingPlayer and received.reasonCode == "RateLimited")
		end))
		assert(deliveries == 1)
		requestingPlayer:Destroy()
	end)
end
