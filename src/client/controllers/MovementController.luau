--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")

local MovementController = {}

local ACTION_NAME = "LunaDisableFreeJump"
local ACTION_PRIORITY = Enum.ContextActionPriority.High.Value + 1

local characterConnection: RBXScriptConnection? = nil
local playerGuiConnection: RBXScriptConnection? = nil
local humanoidStateConnection: RBXScriptConnection? = nil
local activeHumanoid: Humanoid? = nil
local controllerGeneration = 0
local characterToken = 0
local activeJumpButton: GuiObject? = nil
local jumpButtonWasVisible: boolean? = nil
local jumpButtonVisibleConnection: RBXScriptConnection? = nil
local swimming = false

local function desiredJumpButtonVisible(): boolean
	return swimming
end

local function syncJumpButtonVisibility(): ()
	if activeJumpButton == nil or activeJumpButton.Parent == nil then return end
	local desired = desiredJumpButtonVisible()
	if activeJumpButton.Visible ~= desired then
		activeJumpButton.Visible = desired
	end
end

local function consumeJump(
	_actionName: string,
	_inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	-- Luna disables free jumping on land, but Roblox's stock swimming controls
	-- use the same CharacterJump action for vertical movement / leaving water.
	if activeHumanoid ~= nil
		and activeHumanoid.Parent ~= nil
		and activeHumanoid:GetState() == Enum.HumanoidStateType.Swimming
	then
		return Enum.ContextActionResult.Pass
	end
	return Enum.ContextActionResult.Sink
end

local function clearHumanoid(): ()
	if humanoidStateConnection ~= nil then
		humanoidStateConnection:Disconnect()
		humanoidStateConnection = nil
	end
	activeHumanoid = nil
	swimming = false
	syncJumpButtonVisibility()
end

local function applySwimmingState(humanoid: Humanoid, nextState: Enum.HumanoidStateType): ()
	if activeHumanoid ~= humanoid then return end
	swimming = nextState == Enum.HumanoidStateType.Swimming
	if not swimming then
		-- Prevent a held swim-up input from turning into a free land jump after
		-- the humanoid leaves Terrain water.
		humanoid.Jump = false
	end
	syncJumpButtonVisibility()
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

	clearHumanoid()
	activeHumanoid = humanoid
	swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	humanoid.Jump = false
	humanoidStateConnection = humanoid.StateChanged:Connect(function(
		_oldState: Enum.HumanoidStateType,
		newState: Enum.HumanoidStateType
	)
		applySwimmingState(humanoid :: Humanoid, newState)
	end)
	syncJumpButtonVisibility()
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

local function manageJumpButton(descendant: Instance): ()
	if descendant.Name ~= "JumpButton" or not descendant:IsA("GuiObject") then return end
	if activeJumpButton == descendant then
		syncJumpButtonVisibility()
		return
	end
	clearJumpButton(true)
	activeJumpButton = descendant
	jumpButtonWasVisible = descendant.Visible
	syncJumpButtonVisibility()
	jumpButtonVisibleConnection = descendant:GetPropertyChangedSignal("Visible"):Connect(function()
		if activeJumpButton == descendant then
			syncJumpButtonVisibility()
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
		manageJumpButton(descendant)
	end
	playerGuiConnection = playerGui.DescendantAdded:Connect(manageJumpButton)
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
	clearHumanoid()
	clearJumpButton(true)
end

return MovementController
