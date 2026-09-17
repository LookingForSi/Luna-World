--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatInputController = {}

local ACTION_NAME = "LunaBasicAttack"
local localPlayer = Players.LocalPlayer
local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CombatRules = require(ReplicatedStorage.Shared.combat.CombatRules)
local ATTACKING_ATTRIBUTE = CombatConfig.BasicAttackingAttribute
local attackRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttackRequest") :: RemoteEvent

local function onAttackAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	-- The replicated attribute is server-owned, so local input cannot retain a stale toggle.
	local attackActive = localPlayer:GetAttribute(ATTACKING_ATTRIBUTE) == true
	attackRequest:FireServer(CombatRules.nextAttackIntent(attackActive))
	return Enum.ContextActionResult.Sink
end

function CombatInputController.start(): ()
	CombatInputController.stop()
	ContextActionService:BindAction(
		ACTION_NAME,
		onAttackAction,
		true,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle(ACTION_NAME, "Attack")
end

function CombatInputController.stop(): ()
	ContextActionService:UnbindAction(ACTION_NAME)
end

return CombatInputController
