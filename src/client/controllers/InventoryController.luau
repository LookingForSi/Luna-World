--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemDefinitions = require(ReplicatedStorage.Shared.definitions.ItemDefinitions)

local InventoryController = {}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRequest = remotes:WaitForChild("InventoryActionRequest") :: RemoteEvent
local snapshotRequest = remotes:WaitForChild("InventorySnapshotRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("InventorySnapshot") :: RemoteEvent
local actionResult = remotes:WaitForChild("InventoryActionResult") :: RemoteEvent

local TOGGLE_ACTION = "LunaInventoryToggle"
local snapshotConnection: RBXScriptConnection? = nil
local resultConnection: RBXScriptConnection? = nil
local keyboardConnection: RBXScriptConnection? = nil
local onToggle: (() -> ())? = nil
local onSnapshot: ((any) -> ())? = nil
local onResult: ((any) -> ())? = nil
local latestSnapshot: any = nil
local quickSlotItemId: string? = "consumable_minor_healing_draught"

local function toggleAction(
	_actionName: string,
	inputState: Enum.UserInputState,
	_inputObject: InputObject
): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin and onToggle ~= nil then
		onToggle()
	end
	return Enum.ContextActionResult.Sink
end

function InventoryController.requestEquip(instanceId: string): ()
	actionRequest:FireServer("Equip", instanceId)
end

function InventoryController.requestUnequip(slot: string): ()
	actionRequest:FireServer("Unequip", slot)
end

function InventoryController.requestConsume(instanceId: string): ()
	actionRequest:FireServer("Consume", instanceId)
end

function InventoryController.requestDiscard(instanceId: string): ()
	actionRequest:FireServer("Discard", instanceId)
end

function InventoryController.assignQuickSlot(itemId: string): boolean
	local definition = ItemDefinitions[itemId]
	if definition == nil or definition.category ~= "Consumable" then return false end
	quickSlotItemId = itemId
	return true
end

function InventoryController.getQuickSlotState(): any
	local itemId = quickSlotItemId
	local quantity = 0
	if itemId ~= nil and latestSnapshot ~= nil and typeof(latestSnapshot.inventory) == "table" then
		for _, entry in latestSnapshot.inventory do
			if typeof(entry) == "table" and entry.itemId == itemId and typeof(entry.quantity) == "number" then
				quantity += entry.quantity
			end
		end
	end
	return { itemId = itemId, quantity = quantity }
end

function InventoryController.requestQuickUse(): ()
	local itemId = quickSlotItemId
	if itemId == nil or latestSnapshot == nil or typeof(latestSnapshot.inventory) ~= "table" then return end
	for _, entry in latestSnapshot.inventory do
		if typeof(entry) == "table" and entry.itemId == itemId and typeof(entry.instanceId) == "string" then
			InventoryController.requestConsume(entry.instanceId)
			return
		end
	end
end

function InventoryController.requestSnapshot(): ()
	snapshotRequest:FireServer()
end

function InventoryController.start(
	toggleCallback: () -> (),
	snapshotCallback: (any) -> (),
	resultCallback: (any) -> ()
): ()
	InventoryController.stop()
	onToggle = toggleCallback
	onSnapshot = snapshotCallback
	onResult = resultCallback

	snapshotConnection = snapshotEvent.OnClientEvent:Connect(function(snapshot: unknown)
		if typeof(snapshot) == "table" then
			latestSnapshot = snapshot
			if onSnapshot ~= nil then onSnapshot(snapshot) end
		end
	end)
	resultConnection = actionResult.OnClientEvent:Connect(function(result: unknown)
		if typeof(result) == "table" and onResult ~= nil then
			onResult(result)
		end
	end)

	ContextActionService:BindActionAtPriority(
		TOGGLE_ACTION,
		toggleAction,
		false,
		Enum.ContextActionPriority.High.Value + 500,
		Enum.KeyCode.ButtonSelect
	)

	-- T is intentionally used instead of I: I/O are consumed by Roblox camera
	-- CoreScripts in some Studio/client contexts. Zero is the dedicated quick-item slot.
	keyboardConnection = UserInputService.InputBegan:Connect(function(input: InputObject, _gameProcessed: boolean)
		if UserInputService:GetFocusedTextBox() ~= nil then return end
		if input.KeyCode == Enum.KeyCode.T and onToggle ~= nil then
			onToggle()
			return
		end
		if input.KeyCode == Enum.KeyCode.Zero then
			InventoryController.requestQuickUse()
		end
	end)

	task.defer(InventoryController.requestSnapshot)
end

function InventoryController.stop(): ()
	ContextActionService:UnbindAction(TOGGLE_ACTION)
	if snapshotConnection ~= nil then snapshotConnection:Disconnect(); snapshotConnection = nil end
	if resultConnection ~= nil then resultConnection:Disconnect(); resultConnection = nil end
	if keyboardConnection ~= nil then keyboardConnection:Disconnect(); keyboardConnection = nil end
	onToggle = nil
	onSnapshot = nil
	onResult = nil
	latestSnapshot = nil
end

return InventoryController
