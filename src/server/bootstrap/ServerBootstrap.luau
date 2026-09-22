--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)

local ServerBootstrap = {}
local activeStop: (() -> ())? = nil

function ServerBootstrap.start(manifest: RuntimeManifest.RuntimeManifest): () -> ()
	assert(activeStop == nil, "ServerBootstrap is already running")

	local stopManifest = RuntimeManifest.start(manifest)
	local stopped = false

	local function stop(): ()
		if stopped then
			return
		end
		stopped = true
		stopManifest()
		if activeStop == stop then
			activeStop = nil
		end
	end

	activeStop = stop
	game:BindToClose(stop)
	return stop
end

return table.freeze(ServerBootstrap)
