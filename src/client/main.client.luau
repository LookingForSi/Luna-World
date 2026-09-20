--!strict

local clientRoot = script.Parent
local CombatInputController = require(clientRoot.controllers.CombatInputController)
local TargetController = require(clientRoot.controllers.TargetController)
local CombatHud = require(clientRoot.ui.CombatHud)
local CombatLog = require(clientRoot.ui.CombatLog)
local RespawnPrompt = require(clientRoot.ui.RespawnPrompt)
local ActionBar = require(clientRoot.ui.ActionBar)
local StudioTestPanel = require(clientRoot.ui.StudioTestPanel)
local MovementController = require(clientRoot.controllers.MovementController)
local InventoryController = require(clientRoot.controllers.InventoryController)
local InventoryUi = require(clientRoot.ui.InventoryUi)
local EconomyController = require(clientRoot.controllers.EconomyController)
local EconomyUi = require(clientRoot.ui.EconomyUi)
local CombatPresentationController = require(clientRoot.controllers.CombatPresentationController)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local ClientCombatUiRules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)

local function disableStockHealthGui(): ()
	for _ = 1, 5 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		end)
		if ok then return end
		task.wait(0.1)
	end
end

disableStockHealthGui()

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
})
InventoryController.start(InventoryUi.toggle, InventoryUi.setSnapshot, InventoryUi.showResult)
EconomyUi.start({ buy = EconomyController.buy, sell = EconomyController.sell, craft = EconomyController.craft })
EconomyController.start(EconomyUi.open, EconomyUi.setSnapshot, EconomyUi.showResult)
TargetController.start(function(target: Model?)
	CombatHud.setTarget(target)
end)
local function syncActionBar(): ()
	local skillIds = ClientCombatUiRules.getSkills(Players.LocalPlayer:GetAttribute(CombatConfig.ArchetypeAttribute))
	CombatInputController.start(skillIds)
	ActionBar.start(
		skillIds,
		CombatInputController.requestAttack,
		CombatInputController.requestAutoToggle,
		CombatInputController.requestSkill,
		TargetController.clearTarget,
		InventoryUi.toggle
	)
end

syncActionBar()
local archetypeConnection = Players.LocalPlayer:GetAttributeChangedSignal(CombatConfig.ArchetypeAttribute):Connect(syncActionBar)

script.Destroying:Connect(function()
	archetypeConnection:Disconnect()
	InventoryController.stop()
	EconomyController.stop()
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
end)
