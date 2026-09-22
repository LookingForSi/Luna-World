--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

-- Gate A compatibility manifest:
-- world ownership is explicit, while the accepted dev0.3 gameplay service graph
-- keeps its historical start/stop ordering inside one adapter until later gates
-- prove safer independent component ordering.
return RuntimeManifest.new("DevCombinedServer", {
	Components.worldBootstrap(),
	Components.worldSpawnAnchor(),
	Components.devCombinedGameplay(),
})
