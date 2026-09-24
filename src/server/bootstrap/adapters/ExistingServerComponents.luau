--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RuntimeComponent = require(ReplicatedStorage.Shared.core.runtime.RuntimeComponent)
local RespawnConfig = require(ReplicatedStorage.Shared.config.RespawnConfig)
local MoonfallAuthoringContract = require(ReplicatedStorage.Shared.world.MoonfallAuthoringContract)

local serverRoot = script.Parent.Parent.Parent
local MoonfallWorldRuntime = require(serverRoot.features.world.MoonfallWorldRuntime)
local CombatService = require(serverRoot.features.combat.CombatCoordinator)
local PartyService = require(serverRoot.features.party.PartyService)
local PartyNetworkService = require(serverRoot.features.party.PartyNetworkService)
local KillCreditService = require(serverRoot.features.party.KillCreditService)
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
local PlaceTransferService = require(serverRoot.core.transfer.PlaceTransferService)
local PlaceArrivalService = require(serverRoot.core.transfer.PlaceArrivalService)
local MemoryStoreTransferIntentStore = require(serverRoot.core.transfer.MemoryStoreTransferIntentStore)
local TeleportGateway = require(serverRoot.core.transfer.TeleportGateway)
local PlaceConfig = require(ReplicatedStorage.Shared.config.PlaceConfig)
local PlaceRole = require(ReplicatedStorage.Shared.core.runtime.PlaceRole)

local ExistingServerComponents = {}
local transferRuntime = nil
local arrivalRuntime = nil

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

local function loadDevWorldBootstrap(): any
	local worldgen = ServerScriptService:FindFirstChild("Worldgen")
	assert(worldgen ~= nil, "DevCombined Worldgen mapping is missing")
	local bootstrap = worldgen:FindFirstChild("WorldBootstrap")
	assert(bootstrap ~= nil and bootstrap:IsA("ModuleScript"), "DevCombined WorldBootstrap module is missing")
	return require(bootstrap)
end

local function stopDevCombinedGameplay(): ()
	-- Preserve the accepted deterministic shutdown order for the DevCombined
	-- gameplay service graph. Do not assume generic reverse-start order is safe
	-- until these services expose explicit dependency ordering.
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
	KillCreditService.stop()
	PartyNetworkService.stop()
	PartyService.stop()
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
			-- Accepted deterministic DevCombined gameplay startup order.
			EconomyService.start()
			PlayerDataService.start()
			PartyService.start()
			PartyNetworkService.start()
			CharacterService.start()
			ProgressionService.start()
			CombatService.start()
			PlayerRegenerationService.start()
			RespawnService.start()
			StudioDebugService.start()
			MobAbilityService.start()
			MobAIService.start(MobAbilityService.requestAttack)
			MobService.start()
			KillCreditService.start()
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
	local runtime = nil
	return component("WorldBootstrap", function()
		runtime = loadDevWorldBootstrap()
		runtime.start()
	end, function()
		if runtime ~= nil then
			runtime.stop()
			runtime = nil
		end
	end)
end

function ExistingServerComponents.moonfallWorldRuntime(): RuntimeComponent.RuntimeComponent
	return component("MoonfallWorldRuntime", MoonfallWorldRuntime.start, MoonfallWorldRuntime.stop)
end

function ExistingServerComponents.worldSpawnAnchor(): RuntimeComponent.RuntimeComponent
	return component("WorldSpawnAnchor", function()
		local worldRoot = workspace:WaitForChild(MoonfallAuthoringContract.RootName, 15)
		assert(worldRoot ~= nil, "Moonfall world root is missing before gameplay services")

		local worldSpawn = worldRoot:FindFirstChild(MoonfallAuthoringContract.RequiredSpawnName, true)
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

function ExistingServerComponents.placeTransfer(): RuntimeComponent.RuntimeComponent
	return component("PlaceTransferService", function()
		local destinationPlaceId = PlaceConfig.getPlaceId(game.GameId, PlaceRole.World)
		assert(destinationPlaceId ~= nil, "Moonfall destination is not configured for this universe")
		transferRuntime = PlaceTransferService.new({
			playerData = PlayerDataService,
			intentStore = MemoryStoreTransferIntentStore.new(),
			gateway = TeleportGateway.new(),
			sourceRole = PlaceRole.Lobby,
			onRecovery = function(player, reason)
			ReplicatedStorage.Remotes.CharacterResult:FireClient(player, {
				requestId = "transfer-recovery",
				action = "Select",
				ok = false,
				reason = reason,
			})
		end,
		})
		transferRuntime:start()
		CharacterService.setTransferHandler(function(player, characterId)
			return transferRuntime:begin(player, characterId, {
				placeId = destinationPlaceId,
				role = PlaceRole.World,
				entryPointId = "luna_village",
			})
		end)
	end, function()
		CharacterService.setTransferHandler(nil)
		if transferRuntime ~= nil then transferRuntime:stop() end
		transferRuntime = nil
	end)
end

function ExistingServerComponents.placeArrival(role: string): RuntimeComponent.RuntimeComponent
	return component("PlaceArrivalService", function()
		arrivalRuntime = PlaceArrivalService.new({
			playerData = PlayerDataService,
			intentStore = MemoryStoreTransferIntentStore.new(),
			destinationRole = role,
		})
		PlayerDataService.setPreClaimValidator(function(player)
			return arrivalRuntime:admit(player)
		end)
		arrivalRuntime:start()
	end, function()
		PlayerDataService.setPreClaimValidator(nil)
		if arrivalRuntime ~= nil then arrivalRuntime:stop() end
		arrivalRuntime = nil
	end)
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

function ExistingServerComponents.party(): RuntimeComponent.RuntimeComponent
	return component("PartyService", PartyService.start, PartyService.stop)
end

function ExistingServerComponents.partyNetwork(): RuntimeComponent.RuntimeComponent
	return component("PartyNetworkService", PartyNetworkService.start, PartyNetworkService.stop)
end

function ExistingServerComponents.killCredit(): RuntimeComponent.RuntimeComponent
	return component("KillCreditService", KillCreditService.start, KillCreditService.stop)
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
