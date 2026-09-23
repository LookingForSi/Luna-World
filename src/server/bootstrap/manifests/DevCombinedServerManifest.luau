--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)
local Components = require(script.Parent.Parent.adapters.ExistingServerComponents)

-- DevCombined intentionally groups the gameplay service graph behind one
-- component so its accepted dependency-sensitive start/stop order remains
-- deterministic while world ownership stays explicit.
return RuntimeManifest.new("DevCombinedServer", {
	Components.worldBootstrap(),
	Components.worldSpawnAnchor(),
	Components.devCombinedGameplay(),
})
