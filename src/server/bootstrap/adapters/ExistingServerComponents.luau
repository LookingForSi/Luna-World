--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeComponent = require(ReplicatedStorage.Shared.core.runtime.RuntimeComponent)
local RespawnConfig = require(ReplicatedStorage.Shared.config.RespawnConfig)

local serverRoot = script.Parent.Parent.Parent
local WorldBootstrap = require(serverRoot.world.WorldBootstrap)
local CombatService = require(serverRoot.services.CombatService)
local MobService = require(serverRoot.services.MobService)
local MobAIService = require(serverRoot.services.MobAIService)
local MobAbilityService = require(serverRoot.services.MobAbilityService)
local LootService = require(serverRoot.services.LootService)
local InventoryNetworkService = require(serverRoot.services.InventoryNetworkService)
local WorldDropService = require(serverRoot.services.WorldDropService)
local EconomyService = require(serverRoot.services.EconomyService)
local EconomyNetworkService = require(serverRoot.services.EconomyNetworkService)
local EconomyWorldService = require(serverRoot.services.EconomyWorldService)
local NpcWorldService = require(serverRoot.services.NpcWorldService)
local QuestService = require(serverRoot.services.QuestService)
local TravelService = require(serverRoot.services.TravelService)
local PlayerDataService = require(serverRoot.services.PlayerDataService)
local CharacterService = require(serverRoot.services.CharacterService)
local ProgressionService = require(serverRoot.services.ProgressionService)
local PlayerRegenerationService = require(serverRoot.services.PlayerRegenerationService)
local RespawnService = require(serverRoot.services.RespawnService)
local StudioDebugService = require(serverRoot.services.StudioDebugService)

local ExistingServerComponents = {}

local function component(
	name: string,
	startFn: () -> (),
	stopFn: () -> ()
): RuntimeComponent.RuntimeComponent
	return {
		name = name,
		start = startFn,
		stop = stopFn,
	}
end

local function stopDevCombinedGameplay(): ()
	-- Compatibility shutdown order from the accepted dev0.3 RC1 bootstrap.
	-- Gate A deliberately preserves this ordering instead of assuming that
	-- reverse startup order is safe across the legacy service graph.
	StudioDebugService.stop()
	RespawnService.stop()
	PlayerRegenerationService.stop()
	InventoryNetworkService.stop()
	WorldDropService.stop()
	NpcWorldService.stop()
	EconomyWorldService.stop()
	TravelService.stop()
	QuestService.stop()
	EconomyNetworkService.stop()
	EconomyService.stop()
	LootService.stop()
	MobAIService.stop()
	MobAbilityService.stop()
	MobService.stop()
	CombatService.stop()
	ProgressionService.stop()
	CharacterService.stop()
	PlayerDataService.stop()
end

function ExistingServerComponents.devCombinedGameplay(): RuntimeComponent.RuntimeComponent
	return component("DevCombinedGameplay", function()
		local ok, startError = pcall(function()
			-- Exact accepted dev0.3 RC1 startup order.
			EconomyService.start()
			PlayerDataService.start()
			CharacterService.start()
			ProgressionService.start()
			CombatService.start()
			PlayerRegenerationService.start()
			RespawnService.start()
			StudioDebugService.start()
			MobAbilityService.start()
			MobAIService.start(MobAbilityService.requestAttack)
			MobService.start()
			LootService.start()
			WorldDropService.start()
			InventoryNetworkService.start()
			EconomyNetworkService.start()
			EconomyWorldService.start()
			QuestService.start()
			TravelService.start()
			NpcWorldService.start()
		end)

		if not ok then
			stopDevCombinedGameplay()
			error(string.format("DevCombined gameplay bootstrap failed: %s", tostring(startError)), 2)
		end
	end, stopDevCombinedGameplay)
end

function ExistingServerComponents.worldBootstrap(): RuntimeComponent.RuntimeComponent
	return component("WorldBootstrap", WorldBootstrap.start, WorldBootstrap.stop)
end

function ExistingServerComponents.worldSpawnAnchor(): RuntimeComponent.RuntimeComponent
	return component("WorldSpawnAnchor", function()
		local worldRoot = workspace:WaitForChild("LunaWorldPlayableBlockout", 15)
		assert(worldRoot ~= nil, "Luna World blockout failed to initialize before gameplay services")

		local worldSpawn = worldRoot:FindFirstChild("LunaVillageSpawn", true)
		if worldSpawn ~= nil and worldSpawn:IsA("SpawnLocation") then
			worldSpawn:SetAttribute(RespawnConfig.SettlementIdAttribute, RespawnConfig.LunaVillageSettlementId)
			worldSpawn:SetAttribute(RespawnConfig.AnchorIdAttribute, "luna_village_spawn")
			CollectionService:AddTag(worldSpawn, RespawnConfig.AnchorTag)
		end
	end, function() end)
end

function ExistingServerComponents.economy(): RuntimeComponent.RuntimeComponent
	return component("EconomyService", EconomyService.start, EconomyService.stop)
end

function ExistingServerComponents.playerData(): RuntimeComponent.RuntimeComponent
	return component("PlayerDataService", PlayerDataService.start, PlayerDataService.stop)
end

function ExistingServerComponents.character(): RuntimeComponent.RuntimeComponent
	return component("CharacterService", CharacterService.start, CharacterService.stop)
end

function ExistingServerComponents.progression(): RuntimeComponent.RuntimeComponent
	return component("ProgressionService", ProgressionService.start, ProgressionService.stop)
end

function ExistingServerComponents.combat(): RuntimeComponent.RuntimeComponent
	return component("CombatService", CombatService.start, CombatService.stop)
end

function ExistingServerComponents.regeneration(): RuntimeComponent.RuntimeComponent
	return component("PlayerRegenerationService", PlayerRegenerationService.start, PlayerRegenerationService.stop)
end

function ExistingServerComponents.respawn(): RuntimeComponent.RuntimeComponent
	return component("RespawnService", RespawnService.start, RespawnService.stop)
end

function ExistingServerComponents.studioDebug(): RuntimeComponent.RuntimeComponent
	return component("StudioDebugService", StudioDebugService.start, StudioDebugService.stop)
end

function ExistingServerComponents.mobAbilities(): RuntimeComponent.RuntimeComponent
	return component("MobAbilityService", MobAbilityService.start, MobAbilityService.stop)
end

function ExistingServerComponents.mobAI(): RuntimeComponent.RuntimeComponent
	return component("MobAIService", function()
		MobAIService.start(MobAbilityService.requestAttack)
	end, MobAIService.stop)
end

function ExistingServerComponents.mobs(): RuntimeComponent.RuntimeComponent
	return component("MobService", MobService.start, MobService.stop)
end

function ExistingServerComponents.loot(): RuntimeComponent.RuntimeComponent
	return component("LootService", LootService.start, LootService.stop)
end

function ExistingServerComponents.worldDrops(): RuntimeComponent.RuntimeComponent
	return component("WorldDropService", WorldDropService.start, WorldDropService.stop)
end

function ExistingServerComponents.inventoryNetwork(): RuntimeComponent.RuntimeComponent
	return component("InventoryNetworkService", InventoryNetworkService.start, InventoryNetworkService.stop)
end

function ExistingServerComponents.economyNetwork(): RuntimeComponent.RuntimeComponent
	return component("EconomyNetworkService", EconomyNetworkService.start, EconomyNetworkService.stop)
end

function ExistingServerComponents.economyWorld(): RuntimeComponent.RuntimeComponent
	return component("EconomyWorldService", EconomyWorldService.start, EconomyWorldService.stop)
end

function ExistingServerComponents.quests(): RuntimeComponent.RuntimeComponent
	return component("QuestService", QuestService.start, QuestService.stop)
end

function ExistingServerComponents.travel(): RuntimeComponent.RuntimeComponent
	return component("TravelService", TravelService.start, TravelService.stop)
end

function ExistingServerComponents.npcWorld(): RuntimeComponent.RuntimeComponent
	return component("NpcWorldService", NpcWorldService.start, NpcWorldService.stop)
end

return table.freeze(ExistingServerComponents)
