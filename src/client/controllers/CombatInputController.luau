--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatInputController = {}

local ACTION_NAME = "LunaBasicAttack"
local attackRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttackRequest") :: RemoteEvent
local attackHeld = false

local function onAttackAction(_actionName: string, inputState: Enum.UserInputState, _inputObject: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		attackHeld = false
		return Enum.ContextActionResult.Sink
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if attackHeld then return Enum.ContextActionResult.Sink end

	-- Each Begin is a one-shot intent. The server owns cooldown and buffering.
	attackHeld = true
	attackRequest:FireServer()
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
	attackHeld = false
	ContextActionService:UnbindAction(ACTION_NAME)
end

return CombatInputController
