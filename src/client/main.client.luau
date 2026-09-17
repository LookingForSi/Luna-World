--!strict

local clientRoot = script.Parent
local CombatInputController = require(clientRoot.controllers.CombatInputController)
local TargetController = require(clientRoot.controllers.TargetController)
local CombatHud = require(clientRoot.ui.CombatHud)

CombatHud.start()
TargetController.start(function(target: Model?)
	CombatHud.setTarget(target)
end)
CombatInputController.start()

script.Destroying:Connect(function()
	CombatInputController.stop()
	TargetController.stop()
	CombatHud.stop()
end)
