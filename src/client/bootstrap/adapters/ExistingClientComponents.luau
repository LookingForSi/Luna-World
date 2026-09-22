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
local InventoryController = require(clientRoot.controllers.InventoryController)
local EconomyController = require(clientRoot.controllers.EconomyController)
local QuestController = require(clientRoot.controllers.QuestController)
local CombatPresentationController = require(clientRoot.controllers.CombatPresentationController)
local ResponsiveUiController = require(clientRoot.controllers.ResponsiveUiController)
local CharacterLobbyController = require(clientRoot.controllers.CharacterLobbyController)

local CombatHud = require(clientRoot.ui.CombatHud)
local CombatLog = require(clientRoot.ui.CombatLog)
local RespawnPrompt = require(clientRoot.ui.RespawnPrompt)
local ActionBar = require(clientRoot.ui.ActionBar)
local StudioTestPanel = require(clientRoot.ui.StudioTestPanel)
local InventoryUi = require(clientRoot.ui.InventoryUi)
local EconomyUi = require(clientRoot.ui.EconomyUi)

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

		CharacterLobbyController.stop()
		MovementController.start()
		CombatPresentationController.start()
		CombatHud.start()
		CombatLog.start()
		RespawnPrompt.start()
		StudioTestPanel.start()
		InventoryUi.start({
			equip = InventoryController.requestEquip,
			unequip = InventoryController.requestUnequip,
			consume = InventoryController.requestConsume,
			discard = InventoryController.requestDiscard,
			assignQuickSlot = InventoryController.assignQuickSlot,
		})
		InventoryController.start(InventoryUi.toggle, InventoryUi.setSnapshot, InventoryUi.showResult)

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

		syncActionBar()
		archetypeConnection =
			Players.LocalPlayer:GetAttributeChangedSignal(CombatConfig.ArchetypeAttribute):Connect(syncActionBar)

		EconomyUi.start({
			buy = EconomyController.buy,
			sell = EconomyController.sell,
			sellBatch = EconomyController.sellBatch,
			craft = EconomyController.craft,
		})
		EconomyController.start(EconomyUi.open, EconomyUi.setSnapshot, EconomyUi.showResult)
		QuestController.start()
		ResponsiveUiController.start()
	end

	return component("Gameplay", startGameplay, stopGameplay)
end

return table.freeze(ExistingClientComponents)
