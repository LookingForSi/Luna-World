--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local presentationEvent = ReplicatedStorage.Remotes.CombatPresentation

local CombatPresentationService = {}

export type Transport = (CombatPresentationRules.Message) -> ()
export type PlayerTransport = (Player, CombatPresentationRules.Message) -> ()

function CombatPresentationService.deliver(message: CombatPresentationRules.Message, transport: Transport): boolean
	if not CombatPresentationRules.isSupported(message) then return false end
	transport(message)
	return true
end

-- This boundary only publishes server-confirmed display data. It deliberately has
-- no reference to damage, resource, cooldown, or random-number services.
function CombatPresentationService.publish(message: CombatPresentationRules.Message): ()
	CombatPresentationService.deliver(message, function(publicMessage)
		presentationEvent:FireAllClients(publicMessage)
	end)
end

function CombatPresentationService.publishToPlayer(player: Player, message: CombatPresentationRules.Message): ()
	CombatPresentationService.deliverToPlayer(player, message, function(recipient, publicMessage)
		presentationEvent:FireClient(recipient, publicMessage)
	end)
end

function CombatPresentationService.deliverToPlayer(player: Player, message: CombatPresentationRules.Message, transport: PlayerTransport): boolean
	if not CombatPresentationRules.isSupported(message) then return false end
	transport(player, message)
	return true
end

return table.freeze(CombatPresentationService)
