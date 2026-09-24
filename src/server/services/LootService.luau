--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LootTableDefinitions = require(ReplicatedStorage.Shared.definitions.LootTableDefinitions)
local MobDefinitions = require(ReplicatedStorage.Shared.definitions.MobDefinitions)
local LootRules = require(ReplicatedStorage.Shared.loot.LootRules)
local CombatPresentationRules = require(ReplicatedStorage.Shared.combat.CombatPresentationRules)
local CombatPresentationService = require(script.Parent.CombatPresentationService)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local PartyRules = require(ReplicatedStorage.Shared.party.PartyRules)
local KillCreditService = require(script.Parent.Parent.features.party.KillCreditService)
local RewardLedger = require(script.Parent.Parent.features.party.RewardLedger)

local LootService = {}

local started = false
local killResolvedConnection: RBXScriptConnection? = nil
local MAX_REWARD_LEDGER = 4096
local rewardLedger = RewardLedger.new(MAX_REWARD_LEDGER)
local random = Random.new()

local function findMobDefinitionById(mobId: string)
	for _, definition in MobDefinitions do
		if definition.id == mobId then return definition end
	end
	return nil
end

local function markRewarded(entityId: string): boolean
	return rewardLedger:mark(entityId)
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

local function onKillResolved(context: any): ()
	local definition = findMobDefinitionById(context.mobId)
	if definition == nil then return end
	local lootTable = LootTableDefinitions[definition.lootTableId]
	if lootTable == nil then return end
	if not markRewarded(context.entityId) then return end
	if #context.eligiblePlayers == 0 then return end

	local userIds = {}; for _, player in context.eligiblePlayers do table.insert(userIds, player.UserId) end
	local xpShares = PartyRules.splitXP(definition.rewardXP, userIds)
	for _, player in context.eligiblePlayers do
		ProgressionService.awardMobXP(player, xpShares[player.UserId], definition.level)
	end

	local recipient = context.lootRecipient
	if recipient == nil or not PlayerDataService.isReady(recipient) then return end
	local result = LootRules.roll(lootTable, function()
		return random:NextNumber()
	end)
	if not grantLuna(recipient, result.luna) then
		warn(string.format("Failed to grant Luna reward to %s", recipient.Name))
	end

	for _, reward in result.items do
		local granted, reason = InventoryService.grantItem(recipient, reward.itemId, reward.quantity)
		if granted then
			publishReward(recipient, "loot_item", reward.quantity, reward.itemId, "Granted")
		elseif reason == "InventoryFull" then
			publishReward(recipient, "loot_item_full", reward.quantity, reward.itemId, "Rejected")
		else
			warn(string.format("Failed to grant item %s to %s: %s", reward.itemId, recipient.Name, tostring(reason)))
		end
	end
end

function LootService.start(): ()
	if started then return end
	started = true
	killResolvedConnection = KillCreditService.KillResolved:Connect(onKillResolved)
end

function LootService.stop(): ()
	if not started then return end
	started = false
	if killResolvedConnection ~= nil then killResolvedConnection:Disconnect(); killResolvedConnection = nil end
	rewardLedger:clear()
end

return LootService
