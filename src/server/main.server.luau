--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local CombatService = require(script.Parent.services.CombatService)
local MobService = require(script.Parent.services.MobService)
local MobAIService = require(script.Parent.services.MobAIService)
local ProgressionService = require(script.Parent.services.ProgressionService)
local RespawnService = require(script.Parent.services.RespawnService)
local StudioDebugService = require(script.Parent.services.StudioDebugService)

local function findMobDefinitionById(mobId: string)
	for _, definition in MobDefinitions do
		if definition.id == mobId then
			return definition
		end
	end
	return nil
end

ProgressionService.start()
CombatService.start()
RespawnService.start()
StudioDebugService.start()
MobAIService.start(CombatService.requestMobBasicAttack)
MobService.start()

MobService.MobDied:Connect(function(killer: Player?, mobId: string, _entityId: string)
	local definition = findMobDefinitionById(mobId)
	if definition ~= nil and killer ~= nil then
		-- Milestone 0 intentionally awards the kill to MobService's last valid attacker;
		-- this is session-only behavior, not the final shared-reward economy.
		ProgressionService.awardXP(killer, definition.rewardXP)
	end
end)
