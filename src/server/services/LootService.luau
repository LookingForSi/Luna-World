--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTableDefinitions = require(ReplicatedStorage.Shared.definitions.LootTableDefinitions)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local LootRules = require(ReplicatedStorage.Shared.loot.LootRules)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local InventoryService = require(script.Parent.InventoryService)
local MobService = require(script.Parent.MobService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)

local LootService = {}

local started = false
local mobDiedConnection: RBXScriptConnection? = nil
local rewardedEntityIds: { [string]: boolean } = {}
local rewardedOrder: { string } = {}
local MAX_REWARD_LEDGER = 4096
local random = Random.new()

local function findMobDefinitionById(mobId: string)
	for _, definition in MobDefinitions do
		if definition.id == mobId then return definition end
	end
	return nil
end

local function markRewarded(entityId: string): boolean
	if rewardedEntityIds[entityId] then return false end
	rewardedEntityIds[entityId] = true
	table.insert(rewardedOrder, entityId)
	if #rewardedOrder > MAX_REWARD_LEDGER then
		local oldest = table.remove(rewardedOrder, 1)
		rewardedEntityIds[oldest] = nil
	end
	return true
end

local function publishReward(
	player: Player,
	presentationKey: string,
	amount: number,
	definitionId: string?,
	outcome: string
): ()
	CombatPresentationService.publishToPlayer(player, CombatPresentationRules.create(
		"Reward",
		HttpService:GenerateGUID(false),
		"player:" .. tostring(player.UserId),
		workspace:GetServerTimeNow(),
		{
			presentationKey = presentationKey,
			outcome = outcome,
			amount = amount,
			definitionId = definitionId,
		}
	))
end

local function grantLuna(player: Player, amount: number): boolean
	if amount <= 0 then return true end
	local ok = PlayerDataService.mutate(player, function(profile)
		profile.Luna += amount
	end)
	if ok then publishReward(player, "luna", amount, nil, "Granted") end
	return ok
end

local function onMobDied(killer: Player?, mobId: string, entityId: string): ()
	if killer == nil or not PlayerDataService.isReady(killer) then return end
	local definition = findMobDefinitionById(mobId)
	if definition == nil then return end
	local lootTable = LootTableDefinitions[definition.lootTableId]
	if lootTable == nil then return end
	if not markRewarded(entityId) then return end

	ProgressionService.awardMobXP(killer, definition.rewardXP, definition.level)

	local result = LootRules.roll(lootTable, function()
		return random:NextNumber()
	end)
	if not grantLuna(killer, result.luna) then
		warn(string.format("Failed to grant Luna reward to %s", killer.Name))
	end

	for _, reward in result.items do
		local granted, reason = InventoryService.grantItem(killer, reward.itemId, reward.quantity)
		if granted then
			publishReward(killer, "loot_item", reward.quantity, reward.itemId, "Granted")
		elseif reason == "InventoryFull" then
			publishReward(killer, "loot_item_full", reward.quantity, reward.itemId, "Rejected")
		else
			warn(string.format("Failed to grant item %s to %s: %s", reward.itemId, killer.Name, tostring(reason)))
		end
	end
end

function LootService.start(): ()
	if started then return end
	started = true
	mobDiedConnection = MobService.MobDied:Connect(onMobDied)
end

function LootService.stop(): ()
	if not started then return end
	started = false
	if mobDiedConnection ~= nil then mobDiedConnection:Disconnect(); mobDiedConnection = nil end
	table.clear(rewardedEntityIds)
	table.clear(rewardedOrder)
end

return LootService
