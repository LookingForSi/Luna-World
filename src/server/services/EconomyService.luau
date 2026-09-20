--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CraftingDefinitions = require(ReplicatedStorage.Shared.definitions.CraftingDefinitions)
local EconomyRules = require(ReplicatedStorage.Shared.economy.EconomyRules)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local MerchantDefinitions = require(ReplicatedStorage.Shared.definitions.MerchantDefinitions)
local StarterGearRules = require(ReplicatedStorage.Shared.economy.StarterGearRules)
local PlayerDataService = require(script.Parent.PlayerDataService)

local EconomyService = {}
local started = false
local readyConnection: RBXScriptConnection? = nil

local function applyProfile(target: any, source: any): ()
	target.Luna = source.Luna
	target.ArchetypeId = source.ArchetypeId
	target.Items = source.Items
	target.Inventory = source.Inventory
	target.Equipment = source.Equipment
end
local function guid(): string return HttpService:GenerateGUID(false) end

local function transform(player: Player, callback: (any) -> (any?, string?)): (boolean, string?)
	local failure: string? = nil
	local ok, reason = PlayerDataService.mutate(player, function(profile)
		local nextProfile, ruleReason = callback(profile)
		if nextProfile == nil then failure = ruleReason or "Rejected"; error(failure) end
		applyProfile(profile, nextProfile)
	end)
	if not ok then return false, failure or reason end
	return true, nil
end

function EconomyService.buy(player: Player, itemId: string, quantity: number): (boolean, string?)
	return transform(player, function(profile) return EconomyRules.buy(profile, itemId, quantity, guid) end)
end
function EconomyService.sell(player: Player, instanceId: string, quantity: number): (boolean, string?)
	return transform(player, function(profile) return EconomyRules.sell(profile, instanceId, quantity) end)
end
function EconomyService.sellBatch(player: Player, selections: { any }): (boolean, string?, number?)
	local earned = 0
	local ok, reason = transform(player, function(profile)
		local nextProfile, ruleReason, total = EconomyRules.sellBatch(profile, selections)
		earned = total or 0
		return nextProfile, ruleReason
	end)
	return ok, reason, if ok then earned else nil
end
function EconomyService.craft(player: Player, craftId: string): (boolean, string?)
	return transform(player, function(profile) return EconomyRules.craft(profile, craftId, guid) end)
end

function EconomyService._switchArchetypeForStudio(player: Player, archetypeId: string): (boolean, string?)
	assert(RunService:IsStudio(), "Studio starter-gear transition is unavailable outside Studio")
	return transform(player, function(profile)
		return StarterGearRules.switchArchetype(profile, archetypeId, guid)
	end)
end

function EconomyService.createSnapshot(player: Player): any?
	local profile = PlayerDataService.getProfileCopy(player); if profile == nil then return nil end
	local inventory = {}
	for _, instanceId in profile.Inventory do
		local record = profile.Items[instanceId]
		if record ~= nil then table.insert(inventory, { instanceId = instanceId, itemId = record.ItemId, quantity = record.Quantity }) end
	end
	local stock = {}
	for _, itemId in MerchantDefinitions.Stock do
		local item = ItemDefinitions[itemId]
		table.insert(stock, { itemId = itemId, price = item.merchantRetail })
	end
	local crafts = {}
	for craftId, recipe in CraftingDefinitions do
		table.insert(crafts, { craftId = craftId, outputItemId = recipe.outputItemId, fee = recipe.fee, ingredients = recipe.ingredients })
	end
	table.sort(crafts, function(a, b) return a.craftId < b.craftId end)
	return { luna = profile.Luna, level = profile.Level, inventory = inventory, stock = stock, crafts = crafts }
end

local function grantStarter(player: Player): ()
	local ok, reason = transform(player, function(profile) return StarterGearRules.grantAndEquip(profile, guid) end)
	if not ok then warn(string.format("Starter weapon grant failed for %s: %s", player.Name, reason or "unknown")) end
end
function EconomyService.start(): ()
	if started then return end; started = true
	readyConnection = PlayerDataService.ProfileReady:Connect(grantStarter)
end
function EconomyService.stop(): ()
	if not started then return end; started = false
	if readyConnection ~= nil then readyConnection:Disconnect(); readyConnection = nil end
end
return EconomyService
