--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatInputController = {}

local ACTION_NAME = "LunaBasicAttack"
local attackRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttackRequest") :: RemoteEvent
local attackActive = false

local function onAttackAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	attackActive = not attackActive
	-- The client sends intent only; cadence, damage, and eligibility remain server-owned.
	attackRequest:FireServer(attackActive)
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
	if attackActive then
		attackActive = false
		attackRequest:FireServer(false)
	end
end

return CombatInputController
