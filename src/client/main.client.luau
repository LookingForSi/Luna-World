--!strict

local clientRoot = script.Parent
local CombatInputController = require(clientRoot.controllers.CombatInputController)
local TargetController = require(clientRoot.controllers.TargetController)
local CombatHud = require(clientRoot.ui.CombatHud)
local ActionBar = require(clientRoot.ui.ActionBar)
local MovementController = require(clientRoot.controllers.MovementController)
local CombatPresentationController = require(clientRoot.controllers.CombatPresentationController)

MovementController.start()
CombatPresentationController.start()
CombatHud.start()
TargetController.start(function(target: Model?)
	CombatHud.setTarget(target)
end)
CombatInputController.start()
ActionBar.start(CombatInputController.requestAttack, CombatInputController.requestAutoToggle)

script.Destroying:Connect(function()
	MovementController.stop()
	CombatPresentationController.stop()
	CombatInputController.stop()
	ActionBar.stop()
	TargetController.stop()
	CombatHud.stop()
end)
