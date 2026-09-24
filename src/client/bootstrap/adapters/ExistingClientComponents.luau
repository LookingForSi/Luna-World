--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local RuntimeComponent = require(ReplicatedStorage.Shared.core.runtime.RuntimeComponent)
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ClientCombatUiRules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)

local clientRoot = script.Parent.Parent.Parent
local CombatInputController = require(clientRoot.controllers.CombatInputController)
local TargetController = require(clientRoot.controllers.TargetController)
local MovementController = require(clientRoot.controllers.MovementController)
local InventoryController = require(clientRoot.features.inventory.InventoryController)
local EconomyController = require(clientRoot.features.economy.EconomyController)
local QuestController = require(clientRoot.features.quests.QuestController)
local PartyController = require(clientRoot.features.party.PartyController)
local PartyUi = require(clientRoot.features.party.PartyUi)
local CombatPresentationController = require(clientRoot.controllers.CombatPresentationController)
local ResponsiveUiController = require(clientRoot.controllers.ResponsiveUiController)
local CharacterLobbyController = require(clientRoot.features.lobby.CharacterLobbyController)

local CombatHud = require(clientRoot.ui.CombatHud)
local CombatLog = require(clientRoot.ui.CombatLog)
local RespawnPrompt = require(clientRoot.ui.RespawnPrompt)
local ActionBar = require(clientRoot.ui.ActionBar)
local StudioTestPanel = require(clientRoot.ui.StudioTestPanel)
local InventoryUi = require(clientRoot.features.inventory.InventoryUi)
local EconomyUi = require(clientRoot.features.economy.EconomyUi)

local ExistingClientComponents = {}

function ExistingClientComponents.requestCharacterSelection(characterId: string): ()
	CharacterLobbyController.requestSelect(characterId)
end

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

local function disableStockHealthGui(): ()
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then
			return
		end
		task.wait(0.1)
	end
end

function ExistingClientComponents.stockHealthGui(): RuntimeComponent.RuntimeComponent
	return component("StockHealthGui", disableStockHealthGui, function() end)
end

function ExistingClientComponents.characterLobby(onEnterWorld: ((string) -> ())?): RuntimeComponent.RuntimeComponent
	return component("CharacterLobby", function()
		CharacterLobbyController.start({ onEnterWorld = onEnterWorld })
	end, CharacterLobbyController.stop)
end

function ExistingClientComponents.gameplay(): RuntimeComponent.RuntimeComponent
	local gameplayStarted = false
	local archetypeConnection: RBXScriptConnection? = nil

	local function stopGameplay(): ()
		if not gameplayStarted then
			return
		end
		gameplayStarted = false

		if archetypeConnection ~= nil then
			archetypeConnection:Disconnect()
			archetypeConnection = nil
		end

		InventoryController.stop()
		CombatHud.setPartyInviteHandler(nil)
		PartyController.stop()
		PartyUi.stop()
		EconomyController.stop()
		QuestController.stop()
		ResponsiveUiController.stop()
		EconomyUi.stop()
		InventoryUi.stop()
		StudioTestPanel.stop()
		MovementController.stop()
		CombatPresentationController.stop()
		CombatInputController.stop()
		ActionBar.stop()
		TargetController.stop()
		RespawnPrompt.stop()
		CombatLog.stop()
		CombatHud.stop()
	end

	local function startGameplay(): ()
		if gameplayStarted then
			return
		end
		gameplayStarted = true

		local function startComponent(name: string, callback: () -> ()): ()
			local ok, reason = pcall(callback)
			if not ok then
				error(string.format("component %s failed: %s", name, tostring(reason)), 0)
			end
		end
		startComponent("CharacterLobby.stop", function() CharacterLobbyController.stop() end)
		startComponent("MovementController", function() MovementController.start() end)
		startComponent("CombatPresentationController", function() CombatPresentationController.start() end)
		startComponent("CombatHud", function() CombatHud.start() end)
		startComponent("CombatLog", function() CombatLog.start() end)
		startComponent("RespawnPrompt", function() RespawnPrompt.start() end)
		startComponent("StudioTestPanel", function() StudioTestPanel.start() end)
		startComponent("InventoryUi", function() InventoryUi.start({
			equip = InventoryController.requestEquip,
			unequip = InventoryController.requestUnequip,
			consume = InventoryController.requestConsume,
			discard = InventoryController.requestDiscard,
			assignQuickSlot = InventoryController.assignQuickSlot,
		}) end)
		startComponent("InventoryController", function() InventoryController.start(InventoryUi.toggle, InventoryUi.setSnapshot, InventoryUi.showResult) end)
		startComponent("PartyUi", function() PartyUi.start({
			invite = PartyController.invite,
			accept = PartyController.accept,
			decline = PartyController.decline,
			leave = PartyController.leave,
			kick = PartyController.kick,
		}) end)
		startComponent("PartyController", function() PartyController.start(PartyUi) end)
		CombatHud.setPartyInviteHandler(PartyController.invite)

		-- Preserve the accepted order: core combat input becomes operational before
		-- optional economy/quest/responsive presentation.
		TargetController.start(function(target: Model?)
			CombatHud.setTarget(target)
		end)

		local function syncActionBar(): ()
			local skillIds =
				ClientCombatUiRules.getSkills(Players.LocalPlayer:GetAttribute(CombatConfig.ArchetypeAttribute))
			CombatInputController.start(skillIds)
			ActionBar.start(
				skillIds,
				CombatInputController.requestAttack,
				CombatInputController.requestAutoToggle,
				CombatInputController.requestSkill,
				TargetController.clearTarget,
				InventoryUi.toggle,
				QuestController.toggleMap,
				QuestController.toggleJournal,
				InventoryController.requestQuickUse,
				InventoryController.getQuickSlotState
			)
		end

		startComponent("CombatInputController+ActionBar", syncActionBar)
		archetypeConnection =
			Players.LocalPlayer:GetAttributeChangedSignal(CombatConfig.ArchetypeAttribute):Connect(syncActionBar)

		startComponent("EconomyUi", function() EconomyUi.start({
			buy = EconomyController.buy,
			sell = EconomyController.sell,
			sellBatch = EconomyController.sellBatch,
			craft = EconomyController.craft,
		}) end)
		startComponent("EconomyController", function() EconomyController.start(EconomyUi.open, EconomyUi.setSnapshot, EconomyUi.showResult) end)
		startComponent("QuestController", function() QuestController.start() end)
		startComponent("ResponsiveUiController", function() ResponsiveUiController.start() end)
	end

	return component("Gameplay", startGameplay, stopGameplay)
end

return table.freeze(ExistingClientComponents)
