--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Contract = require(ReplicatedStorage.Shared.world.MoonfallAuthoringContract)
local OwnershipRules = require(ReplicatedStorage.Shared.world.DevCombinedWorldRules)
local GeneratedBootstrap = require(script.Parent.WorldBootstrap)

local DevCombinedWorldBootstrap = {}
local started = false
local mode: "Generated" | "Authored"? = nil

local function traversalRecovery(): any
	local server = ServerScriptService:WaitForChild("Server")
	return require(server:WaitForChild("world"):WaitForChild("TraversalRecovery"))
end

local function roots(): { Instance }
	local found = {}
	for _, child in Workspace:GetChildren() do
		if child.Name == Contract.RootName then table.insert(found, child) end
	end
	return found
end

local function startAuthored(root: Instance): ()
	assert(root:IsA("Model"), string.format("Workspace.%s authored root must be a Model", Contract.RootName))
	local spawn = root:FindFirstChild(Contract.RequiredSpawnName, true)
	assert(spawn ~= nil and spawn:IsA("SpawnLocation"), string.format("Workspace.%s is missing %s", Contract.RootName, Contract.RequiredSpawnName))
	traversalRecovery().start(root, spawn)
	mode = "Authored"
end

function DevCombinedWorldBootstrap.start(): ()
	if started then return end
	local found = roots()
	local existing = found[1]
	local managedBy = if existing ~= nil then existing:GetAttribute("ManagedBy") else nil
	local decision, reason = OwnershipRules.resolve(#found, managedBy)
	if decision == "Generate" then
		GeneratedBootstrap.start()
		mode = "Generated"
	elseif decision == "ReuseAuthored" then
		startAuthored(existing :: Instance)
	else
		error(string.format(
			"DevCombined refuses Workspace.%s state (%s, count=%d, ManagedBy=%s)",
			Contract.RootName,
			tostring(reason),
			#found,
			tostring(managedBy)
		))
	end
	started = true
end

function DevCombinedWorldBootstrap.stop(): ()
	if not started then return end
	started = false
	if mode == "Generated" then GeneratedBootstrap.stop() else traversalRecovery().stop() end
	mode = nil
end

return DevCombinedWorldBootstrap
