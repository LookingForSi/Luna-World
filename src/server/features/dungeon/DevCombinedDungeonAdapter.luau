--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DungeonTransfer = require(script.Parent.DungeonTransferService)
local DungeonWorld = require(script.Parent.DungeonWorldService)
local DungeonRun = require(script.Parent.DungeonRunService)
local Encounters = require(script.Parent.DungeonEncounterService)
local Diagnostics = require(script.Parent.DungeonDiagnostics)
local TraversalRecovery = require(script.Parent.Parent.Parent.world.TraversalRecovery)

local Service = {}
local active = false
local participantIds: { [number]: boolean } = {}
local exitConnection: RBXScriptConnection? = nil
local rootConnection: RBXScriptConnection? = nil

local function disconnectRuntimeSignals(): ()
	if exitConnection ~= nil then exitConnection:Disconnect(); exitConnection = nil end
	if rootConnection ~= nil then rootConnection:Disconnect(); rootConnection = nil end
end

local function close(returnToMoonfallSpawn: boolean?): ()
	if not active then return end
	active = false
	disconnectRuntimeSignals()
	Encounters.stop()
	DungeonRun.stop()
	DungeonWorld.stop()

	local destination = if returnToMoonfallSpawn then workspace:FindFirstChild("LunaVillageSpawn", true) else nil
	for _, player in Players:GetPlayers() do
		if participantIds[player.UserId] then
			if destination ~= nil and destination:IsA("BasePart") and player.Character ~= nil then
				player.Character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0))
			end
			TraversalRecovery.setPlayerExcluded(player, false)
		end
	end
	table.clear(participantIds)
	Diagnostics.event("RETURN_COMPLETED", { mode="DevCombined" })
end

local function enter(_leader: Player, contract: any): ()
	if active and DungeonWorld.getRoot() == nil then close() end
	if active then return end
	active = true
	for _, userId in contract.memberUserIds do participantIds[userId] = true end

	local ok, reason = pcall(function()
		DungeonWorld.start(true)
		DungeonRun.start()
		for _, player in Players:GetPlayers() do
			if participantIds[player.UserId] then
				-- Moonfall recovery would otherwise see the isolated dungeon offset as OOB
				-- and undo the authoritative checkpoint PivotTo on its next 0.2s tick.
				TraversalRecovery.setPlayerExcluded(player, true)
				local admitted, admitReason = DungeonRun.admit(player, contract)
				assert(admitted, "DevCombined dungeon admission failed: " .. tostring(admitReason))
			end
		end
		Encounters.start()

		local dungeonRoot = DungeonWorld.getRoot()
		assert(dungeonRoot ~= nil, "DevCombined dungeon root was not created")
		rootConnection = dungeonRoot.AncestryChanged:Connect(function(_, parent)
			if active and parent == nil then task.defer(close, false) end
		end)
		local exit = dungeonRoot:FindFirstChild("RuinsOfSeleneExit")
		local prompt = if exit ~= nil then exit:FindFirstChildOfClass("ProximityPrompt") else nil
		assert(prompt ~= nil, "DevCombined dungeon exit prompt is missing")
		exitConnection = prompt.Triggered:Connect(function(player)
			local snapshot = DungeonRun.getSnapshot()
			if DungeonRun.isParticipant(player) and snapshot ~= nil and snapshot.state == "COMPLETED" then close(true) end
		end)
	end)
	if not ok then
		warn("DevCombined dungeon entry failed: " .. tostring(reason))
		close()
	end
end

function Service.start(): ()
	assert(RunService:IsStudio(), "DevCombined dungeon adapter is Studio-only")
	DungeonTransfer.setStudioHandler(enter)
end

function Service.stop(): ()
	DungeonTransfer.setStudioHandler(nil)
	close()
	disconnectRuntimeSignals()
	table.clear(participantIds)
end

return Service
