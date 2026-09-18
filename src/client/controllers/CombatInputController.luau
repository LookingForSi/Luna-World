--!strict

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local AutoAttackToggleRules = require(ReplicatedStorage.Shared.combat.AutoAttackToggleRules)
local ClientCombatUiRules = require(ReplicatedStorage.Shared.combat.ClientCombatUiRules)

local CombatInputController = {}

local ACTION_NAME = "LunaBasicAttack"
local AUTO_ACTION_NAME = "LunaAutoAttack"
local SKILL_ACTION_NAMES = { "LunaSkill1", "LunaSkill2", "LunaSkill3" }
local attackRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttackRequest") :: RemoteEvent
local autoAttackModeRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AutoAttackModeRequest") :: RemoteEvent
local skillRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SkillRequest") :: RemoteEvent
local attackHeld = false
local autoToggleState = AutoAttackToggleRules.create(false)
local autoAttributeConnection: RBXScriptConnection? = nil
local controllerGeneration = 0
local skillIds: { string } = {}

local function navigatingGui(inputObject: InputObject): boolean
	return ClientCombatUiRules.shouldIgnoreForGuiNavigation(inputObject.UserInputType.Name, GuiService.SelectedObject ~= nil)
end

local function onAttackAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		attackHeld = false
		return Enum.ContextActionResult.Sink
	end
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if navigatingGui(inputObject) then return Enum.ContextActionResult.Pass end
	if attackHeld then return Enum.ContextActionResult.Sink end

	-- Each Begin is a one-shot intent. The server owns cooldown and buffering.
	attackHeld = true
	attackRequest:FireServer()
	return Enum.ContextActionResult.Sink
end

local function onAutoAction(_actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if navigatingGui(inputObject) then return Enum.ContextActionResult.Pass end
	CombatInputController.requestAutoToggle()
	return Enum.ContextActionResult.Sink
end

function CombatInputController.requestAttack(): ()
	attackRequest:FireServer()
end

function CombatInputController.requestSkill(skillId: string): ()
	-- The identifier is only an intent; archetype, target, resource, and cooldown are server validated.
	skillRequest:FireServer(skillId)
end

local function onSkillAction(actionName: string, inputState: Enum.UserInputState, inputObject: InputObject): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	-- Do not turn gamepad UI navigation/selection into a combat intent.
	if navigatingGui(inputObject) then return Enum.ContextActionResult.Pass end
	for index, name in SKILL_ACTION_NAMES do
		if actionName == name then
			local skillId = skillIds[index]
			if skillId ~= nil then CombatInputController.requestSkill(skillId) end
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end

function CombatInputController.requestAutoToggle(): ()
	local desired, generation = AutoAttackToggleRules.requestToggle(autoToggleState)
	if desired == nil or generation == nil then return end
	autoAttackModeRequest:FireServer(desired)
	local expectedControllerGeneration = controllerGeneration
	task.delay(CombatConfig.ClientAutoToggleTimeoutSeconds, function()
		if controllerGeneration ~= expectedControllerGeneration then return end
		AutoAttackToggleRules.expire(autoToggleState, generation)
	end)
end

function CombatInputController.start(activeSkillIds: { string }?): ()
	CombatInputController.stop()
	autoToggleState = AutoAttackToggleRules.create(
		Players.LocalPlayer:GetAttribute(CombatConfig.AutoAttackEnabledAttribute) == true
	)
	autoAttributeConnection = Players.LocalPlayer:GetAttributeChangedSignal(CombatConfig.AutoAttackEnabledAttribute):Connect(function()
		AutoAttackToggleRules.reconcile(
			autoToggleState,
			Players.LocalPlayer:GetAttribute(CombatConfig.AutoAttackEnabledAttribute) == true
		)
	end)
	ContextActionService:BindAction(
		ACTION_NAME,
		onAttackAction,
		false,
		Enum.KeyCode.F,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:BindAction(AUTO_ACTION_NAME, onAutoAction, false, Enum.KeyCode.G, Enum.KeyCode.ButtonL2)
	skillIds = if activeSkillIds ~= nil then table.clone(activeSkillIds) else {}
	local keyBindings = {
		{ Enum.KeyCode.One, Enum.KeyCode.ButtonX },
		{ Enum.KeyCode.Two, Enum.KeyCode.ButtonY },
		{ Enum.KeyCode.Three, Enum.KeyCode.ButtonB },
	}
	for index, actionName in SKILL_ACTION_NAMES do
		ContextActionService:BindAction(actionName, onSkillAction, false, table.unpack(keyBindings[index]))
	end
end

function CombatInputController.stop(): ()
	controllerGeneration += 1
	attackHeld = false
	ContextActionService:UnbindAction(ACTION_NAME)
	ContextActionService:UnbindAction(AUTO_ACTION_NAME)
	for _, actionName in SKILL_ACTION_NAMES do ContextActionService:UnbindAction(actionName) end
	table.clear(skillIds)
	if autoAttributeConnection ~= nil then
		autoAttributeConnection:Disconnect()
		autoAttributeConnection = nil
	end
end

return CombatInputController
