--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)
local EquipmentRules = require(ReplicatedStorage.Shared.inventory.EquipmentRules)
local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local ItemTypes = require(ReplicatedStorage.Shared.types.ItemTypes)
local PersistenceTypes = require(ReplicatedStorage.Shared.types.PersistenceTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CombatService = require(script.Parent.CombatService)

local InventoryService = {}

local consumableReadyAt: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local inventoryChangedEvent = Instance.new("BindableEvent")
InventoryService.InventoryChanged = inventoryChangedEvent.Event

local function applyInventoryState(target: PersistenceTypes.Profile, source: PersistenceTypes.Profile): ()
	target.Items = source.Items
	target.Inventory = source.Inventory
	target.Equipment = source.Equipment
end

local function activeArchetype(player: Player, profile: PersistenceTypes.Profile): string
	local attribute = player:GetAttribute(CombatConfig.ArchetypeAttribute)
	if typeof(attribute) == "string" and ArchetypeDefinitions[attribute] ~= nil then
		return attribute
	end
	return profile.ArchetypeId
end

local function commit(player: Player, nextProfile: PersistenceTypes.Profile): (boolean, string?)
	local ok, reason = PlayerDataService.mutate(player, function(profile)
		applyInventoryState(profile, nextProfile)
	end)
	if ok then inventoryChangedEvent:Fire(player) end
	return ok, reason
end

function InventoryService.getSnapshot(player: Player): PersistenceTypes.Profile?
	return PlayerDataService.getProfileCopy(player)
end

function InventoryService.grantItem(player: Player, itemId: string, quantity: number): (boolean, string?)
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return false, "ProfileNotReady" end

	local nextProfile, reason = InventoryRules.add(profile, itemId, quantity, function()
		return HttpService:GenerateGUID(false)
	end)
	if nextProfile == nil then return false, reason end
	return commit(player, nextProfile)
end

function InventoryService.discard(player: Player, instanceId: string, quantity: number?): (boolean, string?)
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return false, "ProfileNotReady" end
	local nextProfile, reason = InventoryRules.discard(profile, instanceId, quantity)
	if nextProfile == nil then return false, reason end
	return commit(player, nextProfile)
end

function InventoryService.equip(player: Player, instanceId: string): (boolean, string?)
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return false, "ProfileNotReady" end
	local nextProfile, reason = EquipmentRules.equip(profile, instanceId, activeArchetype(player, profile), profile.Level)
	if nextProfile == nil then return false, reason end
	return commit(player, nextProfile)
end

function InventoryService.unequip(player: Player, slot: string): (boolean, string?)
	if InventoryConfig.EquipmentSlotSet[slot] ~= true then return false, "InvalidSlot" end
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return false, "ProfileNotReady" end
	local nextProfile, reason = EquipmentRules.unequip(profile, slot :: ItemTypes.EquipmentSlot)
	if nextProfile == nil then return false, reason end
	return commit(player, nextProfile)
end

function InventoryService.consume(player: Player, instanceId: string): (boolean, string?)
	local profile = PlayerDataService.getProfileCopy(player)
	if profile == nil then return false, "ProfileNotReady" end
	local now = workspace:GetServerTimeNow()
	if now < (consumableReadyAt[player] or 0) then return false, "Cooldown" end

	local record = profile.Items[instanceId]
	local owned = false
	for _, candidate in profile.Inventory do
		if candidate == instanceId then owned = true; break end
	end
	if not owned or record == nil then return false, "NotOwned" end

	local definition = ItemDefinitions[record.ItemId]
	if definition == nil or definition.category ~= "Consumable" or definition.consumableEffect == nil then
		return false, "NotConsumable"
	end

	local character = player.Character
	local humanoid = if character ~= nil then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid == nil or humanoid.Health <= 0 then return false, "Dead" end

	local effect = definition.consumableEffect
	if effect.kind == "HealHP" and humanoid.Health >= humanoid.MaxHealth then return false, "NoEffect" end
	if effect.kind == "RestoreResource" then
		local current = player:GetAttribute(CombatConfig.ResourceCurrentAttribute)
		local maximum = player:GetAttribute(CombatConfig.ResourceMaximumAttribute)
		if typeof(current) ~= "number" or typeof(maximum) ~= "number" or current >= maximum then
			return false, "NoEffect"
		end
	end

	local nextProfile, discardReason = InventoryRules.discard(profile, instanceId, 1)
	if nextProfile == nil then return false, discardReason end
	local committed, commitReason = commit(player, nextProfile)
	if not committed then return false, commitReason end

	local restored = 0
	if effect.kind == "HealHP" then
		local before = humanoid.Health
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + effect.amount)
		restored = humanoid.Health - before
	elseif effect.kind == "RestoreResource" then
		restored = CombatService.restorePlayerResource(player, effect.amount)
	end

	if restored <= 0 then
		-- The action was valid when accepted but the target state changed before
		-- resolution. Compensate the consumed item instead of granting a free loss.
		InventoryService.grantItem(player, record.ItemId, 1)
		return false, "NoEffect"
	end

	consumableReadyAt[player] = now + InventoryConfig.ConsumableCooldownSeconds
	return true, nil
end

return InventoryService
