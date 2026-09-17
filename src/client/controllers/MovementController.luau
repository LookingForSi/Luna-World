--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local MovementController = {}

local ACTION_NAME = "LunaDisableFreeJump"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 1

local characterConnection: RBXScriptConnection? = nil
local playerGuiConnection: RBXScriptConnection? = nil
local activeHumanoid: Humanoid? = nil
local previousJumpState: boolean? = nil
local controllerGeneration = 0
local characterToken = 0
local activeJumpButton: GuiObject? = nil
local jumpButtonWasVisible: boolean? = nil
local jumpButtonVisibleConnection: RBXScriptConnection? = nil

local function consumeJump(
	_actionName: string,
	_inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function restoreHumanoid(): ()
	if activeHumanoid ~= nil and activeHumanoid.Parent ~= nil and previousJumpState ~= nil then
		activeHumanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, previousJumpState)
	end
	activeHumanoid = nil
	previousJumpState = nil
end

local function applyToCharacter(character: Model, expectedGeneration: number, expectedCharacterToken: number): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		local child = character:WaitForChild("Humanoid", 5)
		if child == nil or not child:IsA("Humanoid") then return end
		humanoid = child
	end
	if controllerGeneration ~= expectedGeneration
		or characterToken ~= expectedCharacterToken
		or Players.LocalPlayer.Character ~= character
	then
		return
	end
	restoreHumanoid()
	activeHumanoid = humanoid
	previousJumpState = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid.Jump = false
end

local function clearJumpButton(restoreVisibility: boolean): ()
	if jumpButtonVisibleConnection ~= nil then
		jumpButtonVisibleConnection:Disconnect()
		jumpButtonVisibleConnection = nil
	end
	if restoreVisibility and activeJumpButton ~= nil and activeJumpButton.Parent ~= nil and jumpButtonWasVisible ~= nil then
		activeJumpButton.Visible = jumpButtonWasVisible
	end
	activeJumpButton = nil
	jumpButtonWasVisible = nil
end

local function hideJumpButton(descendant: Instance): ()
	if descendant.Name ~= "JumpButton" or not descendant:IsA("GuiObject") then return end
	if activeJumpButton == descendant then return end
	clearJumpButton(true)
	activeJumpButton = descendant
	jumpButtonWasVisible = descendant.Visible
	descendant.Visible = false
	jumpButtonVisibleConnection = descendant:GetPropertyChangedSignal("Visible"):Connect(function()
		if activeJumpButton == descendant and descendant.Visible then
			descendant.Visible = false
		end
	end)
end

function MovementController.start(): ()
	MovementController.stop()

	ContextActionService:BindActionAtPriority(
		ACTION_NAME,
		consumeJump,
		false,
		ACTION_PRIORITY,
		Enum.PlayerActions.CharacterJump
	)

	local player = Players.LocalPlayer
	local expectedGeneration = controllerGeneration
	characterConnection = player.CharacterAdded:Connect(function(character: Model)
		characterToken += 1
		applyToCharacter(character, expectedGeneration, characterToken)
	end)
	if player.Character ~= nil then
		characterToken += 1
		applyToCharacter(player.Character, expectedGeneration, characterToken)
	end

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	for _, descendant in playerGui:GetDescendants() do
		hideJumpButton(descendant)
	end
	playerGuiConnection = playerGui.DescendantAdded:Connect(hideJumpButton)
end

function MovementController.stop(): ()
	controllerGeneration += 1
	characterToken += 1
	ContextActionService:UnbindAction(ACTION_NAME)
	if characterConnection ~= nil then
		characterConnection:Disconnect()
		characterConnection = nil
	end
	if playerGuiConnection ~= nil then
		playerGuiConnection:Disconnect()
		playerGuiConnection = nil
	end
	restoreHumanoid()
	clearJumpButton(true)
end

return MovementController
