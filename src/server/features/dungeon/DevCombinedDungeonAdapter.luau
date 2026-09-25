--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DungeonTransfer = require(script.Parent.DungeonTransferService)
local DungeonWorld = require(script.Parent.DungeonWorldService)
local DungeonRun = require(script.Parent.DungeonRunService)
local Encounters = require(script.Parent.DungeonEncounterService)
local Diagnostics = require(script.Parent.DungeonDiagnostics)

local Service = {}
local active = false
local participantIds: { [number]: boolean } = {}
local exitConnection: RBXScriptConnection? = nil
local rootConnection: RBXScriptConnection? = nil

local function disconnectRuntimeSignals(): ()
	if exitConnection ~= nil then exitConnection:Disconnect(); exitConnection = nil end
	if rootConnection ~= nil then rootConnection:Disconnect(); rootConnection = nil end
end

local function close(): ()
	if not active then return end
	active = false
	disconnectRuntimeSignals()
	Encounters.stop()
	DungeonRun.stop()
	DungeonWorld.stop()

	local destination = workspace:FindFirstChild("LunaVillageSpawn", true)
	if destination ~= nil and destination:IsA("BasePart") then
		for _, player in Players:GetPlayers() do
			if participantIds[player.UserId] and player.Character ~= nil then
				player.Character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0))
			end
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
			if participantIds[player.UserId] then DungeonRun.admit(player, contract) end
		end
		Encounters.start()

		local dungeonRoot = DungeonWorld.getRoot()
		assert(dungeonRoot ~= nil, "DevCombined dungeon root was not created")
		rootConnection = dungeonRoot.AncestryChanged:Connect(function(_, parent)
			if active and parent == nil then task.defer(close) end
		end)
		local exit = dungeonRoot:FindFirstChild("RuinsOfSeleneExit")
		local prompt = if exit ~= nil then exit:FindFirstChildOfClass("ProximityPrompt") else nil
		assert(prompt ~= nil, "DevCombined dungeon exit prompt is missing")
		exitConnection = prompt.Triggered:Connect(function(player)
			local snapshot = DungeonRun.getSnapshot()
			if DungeonRun.isParticipant(player) and snapshot ~= nil and snapshot.state == "COMPLETED" then close() end
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
