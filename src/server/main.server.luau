--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local CombatService = require(script.services.CombatService)
local MobService = require(script.services.MobService)
local ProgressionService = require(script.services.ProgressionService)

local function findMobDefinitionById(mobId: string)
	for _, definition in MobDefinitions do
		if definition.id == mobId then
			return definition
		end
	end
	return nil
end

ProgressionService.start()
MobService.start()
CombatService.start()

MobService.MobDied:Connect(function(killer: Player, mobId: string)
	local definition = findMobDefinitionById(mobId)
	if definition ~= nil then
		-- Milestone 0 intentionally awards the kill to MobService's last valid attacker;
		-- this is session-only behavior, not the final shared-reward economy.
		ProgressionService.awardXP(killer, definition.rewardXP)
	end
end)
