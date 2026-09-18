--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local presentationEvent = ReplicatedStorage.Remotes.CombatPresentation

local CombatPresentationController = {}
local connection: RBXScriptConnection? = nil

local function onPresentation(message: unknown): ()
	if not CombatPresentationRules.isSupported(message) then return end
	-- Task 14 intentionally provides a safe hook only. Final animation, sound, and
	-- visual assets are content work and are not part of this combat contract.
end

function CombatPresentationController.start(): ()
	if connection ~= nil then return end
	connection = presentationEvent.OnClientEvent:Connect(onPresentation)
end

function CombatPresentationController.stop(): ()
	if connection ~= nil then connection:Disconnect() end
	connection = nil
end

return CombatPresentationController
