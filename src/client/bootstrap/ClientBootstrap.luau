--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)

local ClientBootstrap = {}

function ClientBootstrap.start(manifest: RuntimeManifest.RuntimeManifest): () -> ()
	return RuntimeManifest.start(manifest)
end

return table.freeze(ClientBootstrap)
