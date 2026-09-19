--!strict

local CollectionService = game:GetService("CollectionService")

local CombatService = require(script.Parent.services.CombatService)
local MobService = require(script.Parent.services.MobService)
local MobAIService = require(script.Parent.services.MobAIService)
local LootService = require(script.Parent.services.LootService)
local InventoryNetworkService = require(script.Parent.services.InventoryNetworkService)
local PlayerDataService = require(script.Parent.services.PlayerDataService)
local ProgressionService = require(script.Parent.services.ProgressionService)
local RespawnService = require(script.Parent.services.RespawnService)
local StudioDebugService = require(script.Parent.services.StudioDebugService)
local RespawnConfig = require(game:GetService("ReplicatedStorage").Shared.config.RespawnConfig)

local worldRoot = workspace:WaitForChild("LunaWorldPlayableBlockout", 15)
assert(worldRoot ~= nil, "Luna World blockout failed to initialize before gameplay services")

local worldSpawn = worldRoot:FindFirstChild("LunaVillageSpawn", true)
if worldSpawn ~= nil and worldSpawn:IsA("SpawnLocation") then
	worldSpawn:SetAttribute(RespawnConfig.SettlementIdAttribute, RespawnConfig.LunaVillageSettlementId)
	worldSpawn:SetAttribute(RespawnConfig.AnchorIdAttribute, "luna_village_spawn")
	CollectionService:AddTag(worldSpawn, RespawnConfig.AnchorTag)
end

PlayerDataService.start()
ProgressionService.start()
CombatService.start()
RespawnService.start()
StudioDebugService.start()
MobAIService.start(CombatService.requestMobBasicAttack)
MobService.start()
LootService.start()
InventoryNetworkService.start()

game:BindToClose(function()
	StudioDebugService.stop()
	RespawnService.stop()
	InventoryNetworkService.stop()
	LootService.stop()
	MobAIService.stop()
	MobService.stop()
	CombatService.stop()
	ProgressionService.stop()
	PlayerDataService.stop()
end)
