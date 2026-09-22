--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Contract = require(ReplicatedStorage.Shared.world.MoonfallAuthoringContract)
local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)
local Validator = require(ReplicatedStorage.Shared.world.WorldLayoutValidator)
local Manifest = require(ReplicatedStorage.Shared.world.MoonfallRegionManifest)
local TraversalRecovery = require(script.Parent.Parent.Parent.world.TraversalRecovery)

local Runtime = {}
local activeRoot: Model? = nil

function Runtime.start(): ()
	if activeRoot ~= nil then
		return
	end

	local valid, errors = Validator.validate(WorldLayout)
	assert(valid, "Invalid Moonfall WorldLayout: " .. table.concat(errors, "; "))

	local root = Workspace:WaitForChild(Contract.RootName, 15)
	assert(root ~= nil and root:IsA("Model"), string.format(
		"Authored Moonfall root Workspace.%s is missing",
		Contract.RootName
	))
	assert(
		root:GetAttribute("ManagedBy") == Contract.AuthoredManagedBy,
		string.format(
			"Workspace.%s is not an accepted authored Moonfall root (ManagedBy=%s)",
			Contract.RootName,
			tostring(root:GetAttribute("ManagedBy"))
		)
	)
	assert(
		root:GetAttribute("TerrainRevision") == Contract.TerrainRevision,
		string.format(
			"Authored Moonfall terrain revision mismatch: expected %s, got %s",
			Contract.TerrainRevision,
			tostring(root:GetAttribute("TerrainRevision"))
		)
	)

	local spawn = root:FindFirstChild(Contract.RequiredSpawnName, true)
	assert(
		spawn ~= nil and spawn:IsA("SpawnLocation"),
		string.format("Authored Moonfall is missing SpawnLocation %s", Contract.RequiredSpawnName)
	)

	TraversalRecovery.start(root, spawn)
	activeRoot = root
end

function Runtime.stop(): ()
	if activeRoot == nil then
		return
	end
	activeRoot = nil
	TraversalRecovery.stop()
end

function Runtime.getManifest(): any
	return Manifest
end

return table.freeze(Runtime)
