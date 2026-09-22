--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Contract = require(ReplicatedStorage.Shared.world.MoonfallAuthoringContract)
local Builder = require(script.Parent.Moonfall.PlayableWorldBlockout)

local MoonfallBake = {}

function MoonfallBake.run(confirmation: string): (Model, SpawnLocation)
	assert(RunService:IsStudio(), "Moonfall bake is Studio-only")
	assert(
		confirmation == Contract.BakeConfirmation,
		string.format("Explicit confirmation required: %s", Contract.BakeConfirmation)
	)
	assert(
		Workspace:FindFirstChild(Contract.RootName) == nil,
		string.format(
			"Workspace.%s already exists. Back up the Place and remove the previous authored/generated root before rebaking.",
			Contract.RootName
		)
	)

	local root, spawn = Builder.rebuild()
	root:SetAttribute("ManagedBy", Contract.AuthoredManagedBy)
	root:SetAttribute("AuthoringRevision", Contract.TerrainRevision)
	root:SetAttribute("Purpose", "AuthoredMoonfallWorld")

	assert(spawn.Name == Contract.RequiredSpawnName, "Moonfall bake produced an unexpected spawn anchor")
	return root, spawn
end

return table.freeze(MoonfallBake)
