--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArchetypeDefinitions = require(ReplicatedStorage.Shared.definitions.ArchetypeDefinitions)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local InventoryConfig = require(ReplicatedStorage.Shared.config.InventoryConfig)
local EquipmentRules = require(ReplicatedStorage.Shared.inventory.EquipmentRules)
local InventoryRules = require(ReplicatedStorage.Shared.inventory.InventoryRules)
local ItemTypes = require(ReplicatedStorage.Shared.types.ItemTypes)
local PersistenceTypes = require(ReplicatedStorage.Shared.types.PersistenceTypes)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InventoryService = {}

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

return InventoryService
