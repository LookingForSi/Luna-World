--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)

local ServerBootstrap = {}
local activeStop: (() -> ())? = nil

local function publishState(value: string): ()
	local marker = ReplicatedStorage:FindFirstChild("ServerBootstrapState")
	if marker == nil then
		marker = Instance.new("StringValue")
		marker.Name = "ServerBootstrapState"
		marker.Parent = ReplicatedStorage
	end
	assert(marker:IsA("StringValue"), "ServerBootstrapState must be a StringValue")
	marker.Value = value
end

function ServerBootstrap.start(manifest: RuntimeManifest.RuntimeManifest): () -> ()
	assert(activeStop == nil, "ServerBootstrap is already running")
	publishState("Starting")

	local ok, result = pcall(function()
		return RuntimeManifest.start(manifest)
	end)
	if not ok then
		publishState("Failed: " .. tostring(result))
		error(result, 0)
	end
	local stopManifest = result :: () -> ()
	publishState("Ready")
	local stopped = false

	local function stop(): ()
		if stopped then
			return
		end
		stopped = true
		stopManifest()
		publishState("Stopped")
		if activeStop == stop then
			activeStop = nil
		end
	end

	activeStop = stop
	game:BindToClose(stop)
	return stop
end

return table.freeze(ServerBootstrap)
